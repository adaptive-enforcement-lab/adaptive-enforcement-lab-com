---
title: Credential Rotation at Scale
tags:
  - credential-management
  - secrets
  - rotation
  - security
description: >-
  Vendor-neutral patterns for automated credential rotation: safe cutover sequencing, zero-downtime rollout, rollback, and when to eliminate the credential instead.
---
# Credential Rotation at Scale

A credential with no expiry is a standing liability. It does not matter how well it is stored, how narrowly it is scoped, or how carefully it is masked in logs.

A leaked key with no rotation policy grants an attacker indefinite access, bounded only by the time it takes someone to notice. A key that rotates on a fixed schedule bounds that same leak to a known window: the time between the leak and the next scheduled rotation.

Storage discipline reduces the odds of a leak. Rotation bounds the damage when a leak happens anyway. Both matter. This page covers the second one: how to rotate credentials automatically, at scale, without downtime, and how to know when rotation is the wrong tool entirely.

## Why Rotation Is Not Optional

Every credential that can be copied, printed, cached, or logged eventually will be. Git history, CI logs, crash dumps, forgotten forks, shell history files: all of them outlive the intent to keep a secret temporary. A credential with no expiry treats every one of those leak paths as a permanent compromise.

Rotation converts an unbounded risk into a bounded one. It does not prevent leaks. It caps how long a leaked credential stays useful to whoever has it.

!!! note "Rotation is damage control, not prevention"
    Rotation limits the blast radius of a credential that already exists. It does not stop the credential from leaking in the first place. See the "When to Eliminate Instead of Rotate" section below for the pattern that removes the leak path entirely.

## Automated Rotation Strategy

Rotation is not a task on someone's calendar. A human-scheduled reminder to "rotate the key this quarter" fails the same way every manual security control fails: it gets skipped when the person is on leave, deprioritized during an incident, or simply forgotten.

Rotation only counts as a control if a machine enforces the cadence. Two triggers make that concrete:

- **Cron-driven**: a scheduled workflow (`cron` in GitHub Actions, a Kubernetes `CronJob`, a rotation policy on a secrets engine) fires on a fixed interval. 30, 60, or 90 days, depending on the credential's sensitivity.
- **Event-driven**: a workflow triggers on a signal outside the calendar. A leaked-secret alert from a scanner, an offboarded team member, a compromised build.

Both feed the same three-step sequence:

```mermaid
sequenceDiagram
    participant Scheduler
    participant IssuingSystem as Issuing System
    participant Consumer
    participant OldCredential as Old Credential

    Scheduler->>IssuingSystem: 1. Issue new credential
    IssuingSystem->>Consumer: Deliver new credential
    Consumer->>Consumer: 2. Validate new credential works
    Consumer->>OldCredential: 3. Revoke old credential

    %% Ghostty Hardcore Theme
    style Scheduler fill:#9e6ffe
    style IssuingSystem fill:#fd971e
    style Consumer fill:#65d9ef
    style OldCredential fill:#515354
```

1. **Issue** a new credential alongside the existing one. Do not touch the old credential yet.
2. **Validate** the new credential end-to-end, against the real consuming system, not just a syntax or format check.
3. **Revoke** the old credential only after validation passes.

!!! warning "Never revoke before you validate"
    Revoking the old credential before confirming the new one works turns a routine rotation into a self-inflicted outage.

    If the new credential is malformed, scoped wrong, or not yet propagated to every consumer, you have zero working credentials and no fast way back. Validate first. Revoke last. Every time.

## Zero-Downtime Rotation

The three-step sequence only avoids downtime if the old and new credentials are both valid at the same time. That overlap window is what makes cutover safe.

**Overlapping validity.** Issue the new credential with the old one still active. Most credential types support this natively: a second API key on the same account, a second signing certificate before the first expires, an additional service account key.

If the issuing system does not support two live credentials at once, treat that as a gap to close, not a rotation to skip.

**Consumer cutover.** Once the new credential is valid, consumers need to pick it up. Three common mechanisms, in order of operational cost:

| Mechanism | How it works | Trade-off |
| ---------- | -------------- | ----------- |
| Hot-reload | Application watches the secret mount or config source and reloads in-process | No restart, no dropped connections, requires the app to support it |
| Secret-mount refresh | Orchestrator (e.g. an external-secrets controller) updates the mounted file; app re-reads on next access | Simple to implement, still depends on app polling behavior |
| Restart | Rolling restart picks up the new credential on process start | Always works, costs a deploy cycle and brief per-instance downtime unless the rollout is rolling |

Prefer hot-reload or secret-mount refresh where the consumer supports it. Fall back to a rolling restart, never an all-at-once restart, when it doesn't.

**Confirm before revoking.** Validation is not "the new credential exists." It is "every consumer that needs it has it, and has proven it works": a real call against the real system, not a dry run.

## Rollback Path

If the new credential fails validation, the fix is simple only if you followed the sequence: the old credential is still active, so consumers keep working on it while you investigate the new one. There is no rollback to perform because nothing was revoked yet.

This is the entire argument for validate-then-revoke over revoke-then-validate. A rollback path that depends on "un-revoking" a credential does not exist for most systems. A rollback path that depends on "the old thing was never touched" always exists, because you designed it that way.

Rotation automation should treat revocation as a separate, gated step: something that only runs after a validation step reports success, and something that can be paused indefinitely without leaving the system in a half-rotated state.

## One Discipline, Many Credential Types

The pattern above applies to API keys, service account keys, signing certificates, and app-specific private keys alike.

The mechanics of issuing and revoking differ by type and platform: a certificate authority issues and revokes certificates, a cloud IAM service issues and disables service account keys, a source-control platform's App API issues and expires private keys.

What does not change is the discipline: issue new, validate, then revoke old, with an overlap window and an automated trigger.

Don't build a bespoke rotation process per credential type. Build one rotation workflow shape and parameterize the issuing and revoking calls.

## When to Eliminate Instead of Rotate

Rotation is a mitigation. It exists because a credential has to exist, and existing credentials leak. The stronger pattern is removing the credential from the equation entirely.

Short-lived, workload-bound identity uses federated tokens issued per-request and scoped to the calling workload's own identity. There is nothing to rotate because there is nothing long-lived to leak.

The token expires in minutes, not months, and is reissued automatically every time the workload authenticates. See [Workload Identity Federation](../../cloud-native/workload-identity/index.md) for the implementation pattern.

Rotation and elimination are not competing strategies. They are sequential:

1. **Eliminate** the credential wherever workload-bound identity is available. This is the default target state.
2. **Rotate** what's left: legacy systems that can't consume federated identity yet, third-party integrations that require a static key, or credential types with no federation equivalent.

Treat every credential still under rotation as a migration candidate, not a permanent fixture. The rotation schedule buys time. It is not the destination.

## Related

- [Governance Patterns](../../../patterns/governance/index.md): Credential rotation framed alongside audit logging and least privilege
- [Workload Identity Federation Implementation](../../cloud-native/workload-identity/index.md): The elimination pattern this page points to
- [Credential Rotation and Security](../../github-apps/storing-credentials/rotation-security.md): This pattern applied to GitHub App private keys
- [The Last Service Account Key](../../../blog/posts/2026-01-05-last-service-account-key.md): The incident that motivated this page
