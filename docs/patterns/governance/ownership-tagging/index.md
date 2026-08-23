---
title: Resource Ownership and Criticality Tagging
tags:
  - governance
  - ownership
  - incident-response
  - patterns
description: >-
  A vendor-neutral taxonomy for tagging resources by owning team and criticality tier, wired into on-call routing, incident urgency, and planning.
---
# Resource Ownership and Criticality Tagging

## The problem

Unlabeled infrastructure turns an incident into a scavenger hunt. The first
question a responder asks is not "how do we fix this" but "who owns this."
Minutes burn on Slack searches and tribal memory before mitigation even
starts. The same gap shows up outside incidents: resource-allocation and
planning discussions have no objective signal for what deserves investment
first, because nothing on the resource says how much it matters.

Tags fix this only if they carry the right information and stay current.
A `team` label with no update path drifts the moment a reorg happens. A
severity field with no shared definition means every team invents its own
scale. The taxonomy below fixes both the shape of the data and how it gets
used.

## The taxonomy

Two independent axes cover the operational questions that matter. Keep them
separate: a resource's owner and its blast radius do not move together, and
conflating them produces a label that answers neither question well.

### Ownership group

Ownership maps a resource to the **team** responsible for its lifecycle, not
an individual. People rotate off projects, change roles, and leave
companies. A resource tagged to a person becomes orphaned the day that
person's access is revoked. A resource tagged to a team survives membership
churn because the team, not any one member, holds the pager.

Pick a group identifier that already exists in your org structure, an
on-call rotation name, a team topic in your identity provider, whatever your
paging tool routes on, and use it consistently as the tag value. Consistency
matters more than the specific naming scheme.

### Criticality tier

Criticality categorizes blast radius: what breaks, for whom, if this
resource fails. A concrete four-tier scale keeps the categorization
tractable without collapsing real differences in impact:

| Tier | Definition | On-call urgency | SLA implication |
| --- | --- | --- | --- |
| `mission-critical` | Direct, immediate revenue or safety impact if unavailable | Page immediately, any hour | Tightest recovery target the org defines |
| `business-critical` | Blocks a core workflow but has a manual fallback | Page during business hours, escalate after hours if sustained | Same-day recovery target |
| `supporting` | Degrades a secondary capability; core workflows keep running | Ticket, work next business day | Best-effort, tracked but not paged |
| `safe-to-degrade` | Internal tooling, sandboxes, or fully redundant instances | No page; fix on availability | No SLA |

Four tiers is a starting point, not a mandate. What matters is that every
team in the org uses the same scale with the same definitions, so a
`business-critical` tag means the same thing in every namespace and every
repository.

## Where the labels live

The taxonomy is vendor-neutral. The mechanism that carries it is not, and it
varies by what you're tagging:

- **Kubernetes workloads** — labels and annotations on the resource itself
  (`ownership-group`, `criticality-tier`), queryable with `kubectl` and
  usable as selectors in policy and dashboards.
- **Repositories** — `CODEOWNERS` for ownership, and repository topics or a
  metadata file for criticality, since git hosting platforms don't have a
  native criticality field.
- **A CMDB or service catalog**, if one exists — often the source of truth
  that the other two mechanisms sync from or validate against.

Don't force one mechanism to do all three jobs. A Kubernetes label answers
"who owns this workload" at runtime; a service catalog answers "what depends
on this" for planning. Use the mechanism the question actually needs.

## Enforcement

A taxonomy with no enforcement rots. Labels get set once at resource
creation, and the next migration, fork, or copy-paste drops them silently.
By the time an incident needs the label, it's gone.

Enforce ownership and criticality tags the same way you'd enforce any other
required metadata: reject the resource at admission time if the tags are
missing or don't match an allowed value set.

See it enforced: [Kyverno Mandatory Labels Templates](../../../enforce/policy-as-code/template-library/kyverno/labels.md).

## Operational payoff

The taxonomy only earns its keep if it drives real decisions, not just
dashboards nobody reads.

- **On-call escalation routing** — the ownership group tag is the input to
  the paging system's routing table. An alert on a resource resolves
  directly to the responsible team's rotation, no manual lookup required.
- **Incident response urgency** — the criticality tier tag sets response
  posture the moment an alert fires. A `mission-critical` page gets an
  incident commander; a `supporting` alert gets a ticket. Responders stop
  guessing how hard to push.
- **Resource and investment prioritization** — during planning, criticality
  tier gives a defensible ranking for where resilience and performance work
  goes first. `mission-critical` systems get the redundancy budget before
  `safe-to-degrade` ones do, and that ordering is auditable instead of
  political.

## Start small

!!! tip "Enforce a narrow taxonomy before widening it"
    Don't try to tag every resource with every attribute in the first pass.
    Ship ownership and criticality tags on the systems that page someone
    when they break, verify the routing and escalation logic actually
    reads the tags correctly, then widen coverage. A partial taxonomy
    that's enforced beats a complete one that's aspirational.

## Related

- [Governance Patterns](../index.md): The framing page for this pattern family
- [Kyverno Mandatory Labels Templates](../../../enforce/policy-as-code/template-library/kyverno/labels.md): The enforcement mechanism for this taxonomy
- [The Untagged Outage](../../../blog/posts/2026-08-12-untagged-outage.md): The incident that motivated this pattern
