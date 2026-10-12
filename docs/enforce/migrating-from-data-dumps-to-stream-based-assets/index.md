---
title: Migrating From Data Dumps to Stream-Based Assets
nav_title: Stream-Based Migration
description: >-
  A practice guide for migrating from raw data dumps to a stream-based asset
  production model, requiring careful consumer coordination and strict labeling
  policies for migration tracking.
---

Migrating from raw data dumps to a stream-based asset production model requires
careful coordination of consumers and adherence to strict labeling policies
for migration tracking. This transition is not merely a technical change but a
shift in how data is produced, consumed, and managed, demanding a clear strategy
for phasing out legacy systems while maintaining service continuity for all
dependent clients.

!!! warning "Labeling Must Reflect Reality, Not Intent"
    A migration-tracking label is only effective if it is applied *after* a
    component has been fully migrated to the new system, not when the intention
    to migrate is announced. Applying labels prematurely creates a dishonest
    tracking system, leading to a false sense of completion and making it
    impossible to determine which systems have genuinely completed the
    transition.

## Establish a Strict Labeling Policy for Migration Tracking

A fundamental requirement for a successful migration is a clear and verifiable
tracking mechanism. A labeling system applied to service and workflow manifests
serves this purpose, but its integrity is paramount. The chosen label, such as
`neon-free.ch/asset-producer`, must be governed by a strict, automated policy.
In a key migration project, this policy was enforced by an admission controller
that would reject any manifest attempting to apply the label to a component
that did not declare its outputs as asset streams.

This "show, don't tell" approach ensures the label represents a ground-truth
state, not an aspirational one. It prevents teams from marking their components
as "migrated" before the work is complete, providing an honest and reliable
dataset for tracking the overall progress of the migration initiative. Such a
policy makes the labeled set a trustworthy source for dashboards and reports,
accurately reflecting which parts of the ecosystem are producing the new
stream-based assets versus those still reliant on legacy data dumps.

## Coordinate with Consumers for a Staged Migration

Large-scale data migrations cannot be executed in a single, atomic change. They
require careful coordination with all consumers of the data. A staged approach,
where consumers are migrated one by one or in groups, is often the most
practical path. During a recent transition from a legacy directory information
system, the primary internal command-line tool was the first and only consumer
to be migrated. Once this tool was confirmed to be reading from the new asset
streams, the old raw data dumps it previously consumed
(`legacy-system/groups.json` and `legacy-system/users.json`) could be safely
removed.

However, other services, such as an identity resolution service, may have their
own dependencies and migration timelines. Forcing all consumers to migrate
simultaneously creates unnecessary risk and pressure. The migration plan must
account for these differences, allowing some services to continue consuming
older data formats for a limited time while others move to the new model. This
requires clear communication channels and a shared understanding of the
timeline and dependencies across all affected teams.

## Implement a Dual-Publishing Strategy

To support a staged consumer migration, a dual-publishing strategy is often
necessary. This involves the data producer publishing data in both the old and
new formats simultaneously. For example, while the new asset streams were being
published for the newly migrated CLI tool, a critical transitional data file
(`memberships.json`) was still being written to a shared volume. This file was
not published as a formal data bus artifact but existed solely for the benefit
of the legacy identity resolution service.

This transitional file remains a stable, unchanging contract until the last
consumer depending on it can be migrated. Its structure is frozen, and its
existence is a known, managed part of the migration plan. While it may seem
like a duplication of effort, this dual-publishing model is a crucial bridge
that allows downstream teams to migrate at their own pace without disrupting
their services. It decouples the producer's evolution from the consumers'
release cycles.

| Component                  | Status         | Data Source         | Notes                                             |
| -------------------------- | -------------- | ------------------- | ------------------------------------------------- |
| Internal CLI Tool          | Migrated       | Asset Streams       | No longer consumes legacy data dumps.             |
| Identity Resolution Service| In Progress    | Transitional File   | Continues to read the `memberships.json` file.     |
| Legacy Data Dumps          | Partially Deprecated | N/A           | `groups.json` and `users.json` have been removed. |
| New Asset Streams          | Live           | Stream Producer     | The primary source of truth for new consumers.    |

## Validate and Verify Before Deprecating Old Systems

Before any part of a legacy system is turned off, the changes must be rigorously
validated. Simply hoping for the best is not a strategy. In the directory system
migration, the removal of the old data dumps and the application of the
`neon-free.ch/asset-producer` label were verified against a live operations admission
controller using a server-side dry-run. This allowed the development team to
confirm that the proposed changes would be accepted by the production
environment's policy enforcement engine without actually deploying them.

This step is critical for preventing configuration-related outages. A dry-run
can catch policy violations, incorrect schema declarations, or other issues
that would otherwise only surface during a live deployment. It provides a high
degree of confidence that the change is both safe and compliant with the
established rules of the ecosystem.

## Deprecate Legacy Dumps Incrementally

With consumers migrated and changes validated, the final step is to begin
deprecating the legacy data dumps. This should be done incrementally, removing
only those artifacts that are no longer in use. After the internal CLI tool was
migrated, the `groups.json` and `users.json` files were promptly removed. This
act of cleaning up immediately after a dependency is cut reduces the surface
area of the legacy system and prevents new, unauthorized consumers from taking a
dependency on data that is marked for deletion.

A test was added to the codebase to assert that these specific files were
absent, while also asserting that the transitional `memberships.json` file
remained. This automated check ensures that the system's state does not regress
and that the legacy artifacts do not reappear by accident. This incremental
cleanup, backed by tests, makes the migration process a series of small,
manageable, and safe steps rather than a single, high-risk event.
