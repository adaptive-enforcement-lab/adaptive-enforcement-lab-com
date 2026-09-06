---
title: Using Composite Keys for Reliable Application Identification
nav_title: Composite Application Keys
description: >-
  A composite key, combining application name and packaging chart, prevents
  incorrect merges during automated promotions and ensures accurate selection
  of promotion candidates across environments.
---
Employing a composite key made of an application's name and its packaging chart
identifier is the most reliable method for uniquely identifying a deployable
service within the platform's GitOps-based promotion process.

This practice ensures that automated tooling correctly compares and selects
software versions for promotion between environments, particularly during
complex migrations or when multiple application variants exist under a common name.

## The Risk of Ambiguous Identity

Identifying an application solely by its name is fragile and can lead to serious
deployment errors. The name, while convenient, is often not unique enough for
automation to act upon safely. A common failure mode occurs when an application
is being migrated from one packaging format to another. For example, this could
be from a large, multi-service "shared-services-chart" to a new, dedicated
"standalone-service-chart".

A real-world incident demonstrated this risk. An application named `legacy-service`
was being migrated. In the production environment, it still used the old shared
chart, while development and staging environments had already adopted the new
standalone chart. The automated promotion system, keyed only on the name
`legacy-service`, saw the two different versions in different environments as
comparable instances of the same entity. It incorrectly identified the older
version from the production environment's shared chart as a valid promotion
candidate for the staging environment, which was already on a newer, completely
different chart. This created an invalid promotion pull request that, if merged,
would have caused a significant service regression.

## The Solution: A Composite Key

The fundamental fix was to change the application data model to enforce
uniqueness at a structural level. Instead of a simple string, the primary
identifier for an application in the central `Application Inventory Map` became
a composite key combining both the application's `name` and its `package chart
identifier`.

This `AppKey{Name, Chart}` structure makes it impossible for the system to
confuse two applications that happen to share a name but are based on different
underlying packages. At data-collection time, a same-named application deployed
from two different charts is correctly bucketed into two separate, distinct
entries in the inventory. Any subsequent comparison or analysis inherits this
fundamental separation.

## How the Composite Key Works in Practice

The implementation resides within the platform's `deployment automation toolkit`.
The logic that builds the `Application Inventory Map` was updated to key its
central map object on the new composite `AppKey` struct.

When the toolkit scans environments, it now extracts both the application
controller's resource name and the name of the packaging chart it depends on.
For example, `legacy-service` from the `shared-services-chart` and
`legacy-service` from the `standalone-service-chart` are treated as two
entirely different objects from the very beginning.

This means that logic downstream, like the promotion candidate selector, no longer
needs to perform complex, after-the-fact checks to detect and reject cross-chart
comparisons. The data model itself prevents this class of error from ever being
constructed. The risk is eliminated at the source.

!!!warning
A composite key strategy is only effective if both components of the key are
consistently and accurately populated. Ensure that all deployment manifests
and configuration files reliably declare both the application name and the
correct packaging chart. An empty or incorrect chart value will revert the system
to ambiguous, name-only identification for that component.

## Benefits for Automated Promotions

Adopting the composite key had immediate and significant benefits for the
reliability of the automated promotion process.

1.  **Eliminated False Positives:** The primary benefit was the complete
    elimination of incorrect promotion proposals caused by chart migrations
    or name collisions. The system no-longer proposes "promoting" a version
    from an old chart onto a new one.
2.  **Simplified Promotion Logic:** The initial, emergency fix for the
    `legacy-service` incident involved adding defensive code to the promotion
    tool to explicitly check if the source and target applications had
    matching chart identifiers. Once the underlying data model was fixed, this
    comparison-site guard became redundant and was removed. A simpler data model
    leads to simpler, more maintainable application code.
3.  **Improved Observability:** When mismatches were detected by the old
    guard-rail logic, it was difficult to distinguish a genuine "at parity"
    state from a "mismatched chart" state. By keying on the composite identity,
    the system now has a clear and unambiguous view of each unique application
    instance, making status reporting and dashboards more accurate.

## Handling Legacy Consumers

Not every tool that consumes the application inventory needs chart-level
specificity. For use cases like simple reporting or generating a list of all
deployed services by name, forcing consumers to handle the new composite key
would create unnecessary friction.

!!!tip
To maintain backward compatibility and ease adoption, the `Application Inventory
Map` provides a helper method, `ByAppName()`. This function flattens the detailed,
composite-keyed map into a simpler view keyed only by application name. This
provides a stable interface for legacy tools while allowing new, context-aware
tools to benefit from the more precise data model.

## A Comparison of Identification Models

The shift to a composite key represents a move from an ambiguous to a specific
model of application identity. The practical difference is most clear when
shown side-by-side.

| Aspect | Single Key Model (`appName`) | Composite Key Model (`appName`, `chart`) |
| --- | --- | --- |
| **Data Structure** | `map[string]ApplicationState` | `map[AppKey]ApplicationState` |
| **Handling Migrations** | Ambiguous. Sees `app-A` (v1 chart) and `app-A` (v2 chart) as the same entity, leading to incorrect version comparisons. | Unambiguous. Sees two distinct entities, `(app-A, v1-chart)` and `(app-A, v2-chart)`. No comparison is possible. |
| **Risk Profile** | High risk of invalid promotion proposals during any chart refactoring or migration. Requires complex, brittle guard rails. | Low risk. The data model structurally prevents invalid cross-chart comparisons. |
| **Code Complexity** | Pushes complexity to consumers, which must perform their own validation checks before acting on the data. | Centralizes complexity in the data model, providing a safe and simple view to consumers. |
