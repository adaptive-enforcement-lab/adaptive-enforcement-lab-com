---
title: Composite Map Keys and Decoupled Mismatch Observability
nav_title: Composite Map Keys
description: >-
  Promote secondary resource identity into a composite map key at construction
  time to remove comparison guards, reporting mismatches in an observability
  pass.
provenance: machine
authors:
  - content-machine
---

Keying cross-environment inventory maps by application name alone merges resources backed by different charts into a single bucket, forcing downstream logic into scattered comparison guards and non-deterministic map scans.
Promoting the secondary chart identity into a composite map key at construction time enforces separation structurally while isolating cross-chart reporting into a decoupled observability pass.

!!! warning "Tactical guards create silent fail-closed paths"
    Rejecting cross-chart pairings at comparison sites stops invalid promotions, but without dedicated reporting, zero promotable candidates looks identical whether an environment is genuinely at parity or silently skipped due to a diverged chart identity.

## Recognizing Name-Only Keying Failures

Inventory builders that group environment state solely by managed application name assume every environment runs the same underlying chart for that name.
During a chart migration, such as moving an application from a shared generic chart to a dedicated native chart, production often retains the legacy chart while lower environments run the new one.

Merging both streams into one environment map creates two linked defects:

- **Cross-variant promotion collisions**: Candidate selectors compare unrelated version histories from different charts across environments and propose invalid upgrades.
- **Non-deterministic identity scans**: Helpers such as version resolvers lack a reliable chart identity for the bucket and fall back to scanning the environment map for the first non-empty chart.
  Under randomized map iteration, the returned chart varies between runs, hiding the same collision class as a latent bug.

Patching every evaluation path, such as both standard environment promotion and manifest-based candidate selection, with comparison-site guards stops immediate bad matches, but every new consumer must remember to repeat the check.

## Choosing What Belongs in the Composite Key

A composite key should capture only the attributes that define true resource equivalence, excluding transient transport or registry metadata.

| Design Option | Cross-Chart Isolation | Chart Identity Lookup | Operational Trade-off |
| --- | --- | --- | --- |
| Name-only key with comparison guards | Enforced piecemeal at each call site | Non-deterministic scan across environments | New paths can miss guards; parity and skips conflate |
| Composite key (`Name`, `Chart`) | Enforced by construction per bucket | Deterministic direct read from loop key | Requires a flattening helper for name-only views |
| Over-specified key (`Name`, `Chart`, `RepoURL`) | Over-segmented during registry moves | Deterministic direct read from loop key | Same chart splits across buckets when repository URLs differ |

Deliberately exclude chart repository URLs from the key and from mismatch checks.
During migrations from a legacy chart repository to an OCI registry, the same chart legitimately carries different repository URLs across environments for an extended period; keying on repository URL treats valid promotions as mismatches.

## Enforcing Separation at Construction Time

Move invariant enforcement from downstream call sites into the inventory data model itself:

1. **Introduce a composite key struct**: Replace the plain string key on the inventory map with a structured key such as `AppKey{Name, Chart}`. Update every map builder, including live state builders and OCI bundle loaders, to index entries by both fields at construction time.
2. **Delete unreachable comparison guards**: Once a same-named application split across two charts lands in two separate buckets, every entry inside a single bucket shares one chart identity by construction.
   Remove the ad hoc chart-equality guards from all candidate evaluation paths rather than keeping dead defensive code.
3. **Eliminate fallback map scans**: Remove helpers that iterate over environment maps to infer a chart name. Read chart identity directly from the iteration key and pass it explicitly into version resolvers and downstream evaluators.

## Isolating Mismatch Reporting as an Observability Pass

When composite keys prevent candidate selection from ever comparing across buckets, any mismatch tracking previously attached to comparison-site guards disappears unless extracted deliberately.

Replace inline mismatch accumulation with a standalone, observability-only pass (for example, `detectChartMismatches`) that inspects the constructed inventory map for application names present under multiple chart keys across environments.
Candidate selection stays strictly within single-chart buckets, while the observability pass emits a warning log per divergence and surfaces mismatch state for run metrics.
Separating detection from selection guarantees that reporting changes cannot alter promotion decisions and selection refactors cannot silently blind monitoring.

## Fitting Mismatch Signals into Existing Metrics

Reporting mismatches through a brand-new metric series (such as a standalone `chart_mismatch_count`) leaves the signal invisible on existing monitoring dashboards until panels are wired manually.
Prefer extending the existing run-count metric with a dedicated outcome label value (`outcome="chart_mismatch"`), reusing the standard application, source-environment, and target-environment labels from the first detected mismatch.

Set `outcome="chart_mismatch"` only when the run finds no promotable candidate across any other application. A chart divergence on one application must not mask a legitimate promotion candidate on another, nor unconditionally overwrite an `at_parity` outcome when other evaluations succeeded.

!!! tip "Check dashboard filter semantics before adding outcome labels"
    Verify that error scorecards filter by exact match (`outcome="error"`) rather than excluding known success outcomes. With exact-match error tiles and an unfiltered outcome-distribution panel, adding `outcome="chart_mismatch"` surfaces immediately in the run mix without triggering false error alerts.

## Supporting Name-Only Consumers with Lossless Flattening

Not all consumers operate on chart-scoped buckets. Drift cross-referencing, tabular or JSON inventory output, and backward parent lookups naturally key by application name alone.

Expose a dedicated flattening helper (such as `ByAppName()`) on the composite-keyed map to project `(Name, Chart)` entries into a per-name environment map on demand.
This projection is lossless only when a specific domain invariant holds: a single named application exists in at most one chart per environment.
Document that invariant on the helper; if the system ever allows two charts under the same application name within the same environment, name-only consumers must disambiguate explicitly instead of flattening.
