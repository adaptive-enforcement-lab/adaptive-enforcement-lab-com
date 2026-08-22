---
title: Audit Logging
tags:
  - governance
  - audit
  - compliance
  - security
description: >-
  Vendor-neutral audit logging pattern: record structure, control-plane
  and data-plane collection, append-only sinks, retention, and
  compliance evidence generation.
---
# Audit Logging

An audit log is only useful in an incident if it can answer four questions without ambiguity: who did it, when, what did they do, and what did they do it to. Miss any one of those fields and the record becomes a lead instead of evidence.

## What a Record Must Contain

Every audit record needs, at minimum:

- **Actor**: the identity that performed the action. A user, a service account, a workload identity, a CI job. Not a shared credential that maps to a dozen humans.
- **Timestamp**: in UTC, with enough precision to sequence events against other systems.
- **Action**: the specific operation. `role.grant`, `secret.read`, `firewall.rule.delete`. Generic verbs like "modified" are not enough; log the exact API call or command that ran.
- **Target resource**: the fully qualified identifier of what was acted on. A project ID, a namespace, a secret name, a resource path.

```json
{
  "timestamp": "2026-08-23T14:02:11Z",
  "actor": "serviceAccount:deploy-pipeline@example-project",
  "action": "iam.roles.grant",
  "target": "projects/example-project/roles/editor",
  "source_ip": "10.0.4.12",
  "request_id": "8f3a2c1e"
}
```

That schema answers the four questions. It does not, on its own, make the record trustworthy.

### Immutability Is the Point, Not a Bonus

"The actor performed the action" is a claim. It only becomes evidence if the actor who performed it has no ability to edit or delete the record afterward.

An attacker who compromises a credential and can also reach the log store simply deletes the trail behind them. A privileged insider who makes an unauthorized change can do the same thing.

!!! danger "Write access to the log is a privileged permission"
    Treat write access to the audit trail as a permission with a blast radius that exceeds most of the actions the trail is meant to record. Nobody who can be the subject of an audit record should be able to alter it.

## Collection: Control Plane and Data Plane

Two categories of events matter, and teams routinely wire up only one of them.

**Control-plane events** capture changes to configuration, permissions, and infrastructure: a role granted, a firewall rule changed, a secret rotated, a cluster's RBAC policy updated. These answer "who changed what the system is allowed to do."

**Data-plane events** capture interaction with the data itself: a record read, a file downloaded, a query executed against a production database. These answer "who touched what the system actually holds."

A team that only logs control-plane events can prove who has access to a resource, but not who used that access. A team that only logs data-plane events can prove data was read, but not who granted the reader permission to read it in the first place.

An incident almost always needs both records: the credential-rotation event that granted access, and the data-access event that followed it.

Wire up both collection paths from day one. Retrofitting data-plane logging after an incident means the incident itself has no record.

## Sink Requirements

The destination for audit events has to satisfy one non-negotiable property: append-only or write-once. A mutable log is not an audit log. It is a log that happens to be accurate until someone with write access decides it shouldn't be.

Common patterns that satisfy this:

- **Write-once object storage** with object-lock or retention-lock enabled, so objects cannot be overwritten or deleted before a configured retention period expires, even by an account with delete permissions.
- **Dedicated log aggregation** (a SIEM or centralized logging platform) with delete and modify permissions restricted to a small, separately audited administrative group, ideally requiring a second approver for any retention-policy change.
- **Separate trust boundary for the sink**: the identity that writes application logs should not be the identity that can administer the audit log store. If a workload's credentials are compromised, the attacker should not inherit the ability to tamper with the record of that compromise.

The specific backend, whether it's a managed logging service, a self-hosted aggregator, or object storage with a retention lock, is an implementation detail. The requirement, write-once storage with restricted administrative access, is not.

## Retention

Retention should match the compliance obligation that applies to the workload, not a default the logging platform shipped with. Frameworks vary widely. Some require months of retention, others require multiple years, and the right number depends on which framework governs the data and jurisdiction involved.

Two practical rules apply regardless of the specific number:

- Set retention at the sink, not in application code. A retention policy enforced by the storage layer survives application redeployments; one enforced by a script does not.
- Tier, don't delete early. Moving older logs to cheaper storage classes keeps long retention affordable without shortening the window auditors can query.

Look up the specific retention period your compliance framework requires before configuring the sink. Don't guess, and don't copy a number from an unrelated project.

## Compliance Evidence Generation

Raw audit logs are not what an auditor wants to see. An auditor wants a structured artifact that proves a specific control operated correctly over a specific period: every privileged role grant reviewed, every access change tied to an approved change request, every log line accounted for.

Turning raw events into that artifact means:

- **Structured export** on a schedule, filtered to the control being evidenced, rather than a raw log dump the auditor has to interpret.
- **Periodic compliance reports** generated automatically from the audit trail, not compiled by hand the week before an audit.
- **Chain of custody** from raw event to report, so the report itself can be verified against the underlying log rather than trusted on its face.

The [Audit Evidence Collection](../../../enforce/audit-compliance/audit-evidence.md) pattern covers this in more depth: what to collect, how to automate the collection, and how to make the resulting evidence retrievable when an auditor asks for it.

## Security Event Correlation

Audit logs are not just a compliance artifact. They feed detection.

A single audit event is rarely suspicious on its own. A credential rotation happens routinely. A privilege grant happens routinely. What matters is correlation.

An unexpected credential rotation followed within minutes by an unexpected privilege escalation, on an account that doesn't normally perform either action, is a pattern worth alerting on even though each individual event would pass unnoticed.

This is a pointer, not a SIEM tutorial. Feed control-plane and data-plane audit events into whatever detection or correlation system your security team already runs, and make sure the actor, action, and target fields above are structured consistently enough for that system to join events across sources.

## Related

- [Governance Patterns](../index.md): the governance pattern family this article belongs to
- [Audit Logging](../../../secure/cloud-native/gke-hardening/iam-configuration/audit-logging.md): see this pattern applied to a managed Kubernetes control plane
- [Audit Evidence Collection](../../../enforce/audit-compliance/audit-evidence.md): turning collected evidence into auditor-consumable artifacts
- [The Last Service Account Key](../../../blog/posts/2026-01-05-last-service-account-key.md): the incident that motivated this pattern
