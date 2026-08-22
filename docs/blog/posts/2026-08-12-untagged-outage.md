---
title: The Untagged Outage
date: 2026-08-12
authors:
  - mark
categories:
  - Infrastructure
  - Governance
  - Operations
description: >-
  An outage turned into a scavenger hunt for who owned a dead data store. That's when ownership and criticality labels stopped being optional.
slug: untagged-outage
---

The day I pushed `PLAT-868` to our core infrastructure repository
felt small at the time. It was just another pull request merged,
another ticket closed. Looking back, however, it marked a massive
shift in how we managed our growing fleet of infrastructure components.
We finally started applying clear ownership and criticality labels to
everything we deployed, and the impact has been profound. Before this,
identifying who owned a particular microservice or database, or
understanding its true impact on our platform's overall health, was
often a frantic scramble during an incident. It could also be a
drawn-out debate during quarterly planning.

<!-- more -->

I remember one particularly rough incident where a critical data store
went offline. The initial hours were not spent on mitigation. Instead,
they were spent on a scavenger hunt: "Who owns this component?",
"How important is this really?", and "What other systems depend on it?".
We had tribal knowledge, sure, but it was siloed and often outdated.
This experience highlighted a gaping hole in our operational readiness.
We realized we couldn't effectively govern our systems, allocate
resources intelligently, or respond to incidents swiftly without first
understanding *what* we had, *who* was responsible, and *how critical*
it truly was.

This led to the `PLAT-868` initiative. It was a system for formalizing
project classification using two core concepts: **ownership groups**
and **impact level tags**. Now, every infrastructure component,
from a simple load balancer configuration to a complex data processing
pipeline, receives these labels. Ownership maps directly to the team
responsible for its lifecycle. Impact level categorizes its criticality
to our platform's core functionality.

Each component now carries an owning team and a criticality tier, from
mission-critical down to safe-to-degrade, so nobody has to guess twice.
This is not just metadata for metadata's sake; it is operational
intelligence.

When an alert fires, the ownership group becomes immediately clear.
This streamlines the on-call rotation and escalation path. Criticality
levels dictate the urgency of our response and the resources we are
willing to commit. There are no more guessing games in the heat of the
moment. Resource allocation discussions have also transformed. We can
now prioritize investments in our most critical systems. This ensures
they receive the necessary resilience and performance upgrades, while
still appropriately maintaining less critical components.

!!! tip "Start small, iterate often"
    Don't try to label every single component with every possible
    attribute from day one. Instead, focus on ownership and criticality
    first. These provide the most immediate operational benefits. You
    can always add more granular tags later as your needs evolve and
    your teams get comfortable with the process. Incremental adoption
    beats perfect paralysis.

Implementing this classification system has not been without its challenges.
Primarily, these included getting buy-in and establishing clear definitions
for criticality tiers across different engineering teams. It required
a concerted effort to standardize our approach and integrate these
labels into our existing tooling. This ranged from CI/CD pipelines
to monitoring dashboards. However, the upfront investment has paid
dividends in improved governance, more efficient resource planning,
and significantly faster, more targeted incident response. It changed
our infrastructure from a collection of anonymous services into a
well-cataloged, understood ecosystem.

## Related

- **[Kyverno Mandatory Labels Templates](../../enforce/policy-as-code/template-library/kyverno/labels.md)** - Enforce required ownership, cost, and compliance labels via policy
