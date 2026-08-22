---
title: Governance Patterns
tags:
  - governance
  - security
  - compliance
  - patterns
description: >-
  Vendor-neutral governance patterns for audit logging, credential rotation, ownership tagging, and least privilege, each linked to an implementation guide.
---
# Governance Patterns

Governance patterns enforce accountability over who can act, what they are allowed to do, and what record exists once they have acted.
They are vendor-neutral by design.
The underlying platform, whether a managed cloud, a self-hosted cluster, or a hybrid estate, changes which service produces the logs or issues the credentials.
The pattern itself does not change.

This page frames four governance patterns as a single family: audit logging, credential rotation, ownership and criticality tagging, and least privilege.
Each section below states the principle in vendor-neutral terms, then links to a concrete page on this site that shows the principle implemented against a specific platform.

!!! note "Why this page links out instead of duplicating"
    The implementation detail for each pattern already exists elsewhere on this site, written against a specific platform.
    This page does not repeat that detail. It names the shared principle once and points to the concrete page for the how-to.

## Audit Logging

Every privileged action must produce an immutable, attributable record, whether it changes infrastructure, reads a secret, or modifies access control.
The record needs an actor, a timestamp, and the action taken.
It also needs to live somewhere the actor who performed the action cannot alter or delete it.
Without that record, an incident response team reconstructs events from memory instead of evidence.

The pattern holds regardless of which logging backend collects the events.
What matters is that the sink is append-only or write-once, that it captures both control-plane and data-plane operations, and that retention covers the compliance window that applies to the workload.

See it applied to a managed Kubernetes control plane: [Audit Logging](../../secure/cloud-native/gke-hardening/iam-configuration/audit-logging.md).

## Ownership and Criticality Tagging

A resource without an owner is a resource nobody fixes at 3am. Every resource needs two independent labels: which team is responsible for its lifecycle, and how much damage its failure causes.
Ownership routes the page to the right team instead of starting a scavenger hunt.
Criticality sets the response urgency and gives planning discussions an objective basis for prioritizing investment.

The pattern holds regardless of where the labels physically live.
Kubernetes labels, repository metadata, and a CMDB all carry the same two-axis taxonomy; only the storage mechanism changes.
What matters is that the tags are enforced at admission, not applied once and left to drift as ownership changes.

See it applied as a taxonomy: [Resource Ownership and Criticality Tagging](ownership-tagging/index.md).
See it enforced: [Kyverno Mandatory Labels Templates](../../enforce/policy-as-code/template-library/kyverno/labels.md).

## Credential Rotation

Credentials lose their trustworthiness the longer they remain unrotated.
A long-lived key that leaks grants an attacker indefinite access.
A key that rotates on a fixed schedule bounds the damage to a known window.
Rotation is not a one-time hygiene task.
It is a scheduled, automated process with a defined cadence, a validation step that confirms the new credential works before the old one is revoked, and a rollback path if it does not.

The pattern applies to any credential type: API keys, service account keys, signing certificates, or app-specific private keys.
The rotation mechanism differs by platform, but the requirement, automated rotation on a fixed schedule with verified cutover, does not.

See it applied to GitHub App private keys: [Credential Rotation and Security](../../secure/github-apps/storing-credentials/rotation-security.md).

## Least Privilege

Access should be scoped to exactly what a task requires, nothing more.
Every permission granted beyond that scope is unmeasured risk sitting idle until it is either misused or exploited.
Least privilege is enforced by granting fine-grained roles instead of broad administrative ones, by scoping permissions to the smallest resource boundary available, and by treating any wildcard or catch-all grant as a finding, not a convenience.

The pattern is identical across identity systems.
Define the minimal role for each actor class, bind it narrowly, and review the bindings on a schedule rather than assuming they stay correct forever.

See it applied to IAM roles on a managed Kubernetes cluster: [Least Privilege Roles](../../secure/cloud-native/gke-hardening/iam-configuration/least-privilege-roles.md).

## Related Content

- [Secure-by-Design Pattern Library](../security/secure-by-design/index.md): Zero trust, defense in depth, least privilege, and fail secure at the architecture layer
- [The Last Service Account Key](../../blog/posts/2026-01-05-last-service-account-key.md): The incident that motivated the audit logging, credential rotation, and least privilege patterns
- [The Untagged Outage](../../blog/posts/2026-08-12-untagged-outage.md): The incident that motivated the ownership and criticality tagging pattern
