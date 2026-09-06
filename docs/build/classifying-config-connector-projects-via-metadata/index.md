---
title: Classifying Config Connector Projects via Metadata
nav_title: Config Connector Labels
description: >-
  Use Kubernetes metadata to apply classification labels like ownership and criticality to cloud provider projects managed by Config Connector when direct labeling is unavailable.
---
When managing cloud provider projects declaratively with Config Connector, it is
essential to classify those projects with metadata, such as ownership and
criticality, without fighting the reconciliation controller. This guide
outlines a strategy for propagating labels to projects by leveraging the
Kubernetes resource metadata when the resource's own `spec` does not directly
support labeling.

!!! warning "Reconciliation Loop Pitfall"
    Applying labels directly to a cloud project using the provider's CLI or
    console will fail in a GitOps environment. Config Connector will treat this
    out-of-band change as configuration drift and revert it during its next
    reconciliation loop, removing the manually applied labels. All
    configuration must be declared in the Kubernetes resource definition.

## The Challenge: Declarative Management vs. Direct Labeling

A common requirement for at-scale cloud governance is a complete and accurate
inventory of all resources, including their owners and their operational
importance. For cloud projects managed by tools like Config Connector, this
means the project itself must bear labels that identify the owning team and
its criticality tier.

The standard declarative model, however, presents a challenge. Config Connector
maintains the state of the cloud resource based on the desired state defined in
a Kubernetes manifest. Any changes made directly to the resource on the cloud
provider side are considered unauthorized drift and are automatically undone.
This prevents engineers from simply using a command like `gcloud projects
update` to apply the necessary labels, as those labels would disappear moments
later. The classification must be part of the declarative definition itself.

## The Root Cause: An Unavailable Spec Field

One might expect to solve this by adding a `labels` field directly to the
`Project` resource's `spec` in the Kubernetes manifest. However, inspection of
the `Project` Custom Resource Definition (CRD) for Config Connector reveals
that no such field exists. The available fields in the `spec` are limited to
structural references like `billingAccountRef`, `folderRef`, `name`, and
`organizationRef`.

Without a dedicated `spec.labels` field, there is no direct path for declaring
project labels within the resource's primary configuration block. This
limitation necessitates finding an alternative mechanism to transmit the
desired metadata to the final cloud resource.

## The Solution: Label Propagation from Metadata

Config Connector provides an indirect but effective mechanism for this purpose:
it propagates a subset of labels from the Kubernetes resource's top-level
`metadata.labels` field to the managed cloud resource.

This propagation is not a simple one-to-one copy. Config Connector specifically
filters the labels it sends to the cloud provider's API. The key behavior is
that most labels with a reserved domain prefix (e.g., `app.kubernetes.io/` or
custom internal prefixes like `internal-tooling.io/`) are dropped during this
process and do not appear on the final cloud resource. However, simple,
unprefixed labels are passed through.

This behavior was confirmed by observing other resource types, such as a
`StorageBucket`, where unprefixed Kubernetes labels like `app` and `component`
were successfully applied to the corresponding bucket in the cloud environment,
while all prefixed labels were absent. This same principle applies to
`Project` resources.

## Defining Classification Labels

To implement this strategy, first define a standard set of unprefixed labels
for classification. These labels become the vocabulary for tracking ownership
and criticality across the entire resource inventory. The keys should be
simple, clear, and unlikely to conflict with system-level labels.

| Label Key      | Purpose                                            | Example Values                               |
|----------------|----------------------------------------------------|----------------------------------------------|
| `owner-team`   | Identifies the team responsible for the project.   | `platform-engineering`, `data-science-ai`    |

| `criticality`  | Defines the operational importance of the project. | `tier-1` (mission-critical) to `tier-3` (dev) |

Using a consistent schema like this allows reporting and automation tools to
reliably query for projects based on these classifications.

## Implementation: Per-Resource Labeling

Because different projects have different owners and criticality levels, these
labels cannot be applied globally via a Helm chart's `commonLabels`. Instead,
they must be defined in the `metadata.labels` block of each individual
`Project` resource manifest.

This approach allows for the precise, per-resource classification required for
an accurate inventory. For example, a portfolio of three related projects might
each have a different criticality even if they share the same owner. The
solution is to add the unprefixed `owner-team` and `criticality` labels
directly to each resource's metadata block.

A `Project` resource before this change might look like this:

```yaml
# templates/projects/project.yaml
apiVersion: resourcemanager.cnrm.cloud.google.com/v1beta1
kind: Project
metadata:
  name: "ai-research-project"
  # Note: no classification labels
```

After implementing the strategy, the definition is updated to include the
classification labels:

```yaml
# templates/projects/project.yaml
apiVersion: resourcemanager.cnrm.cloud.google.com/v1beta1
kind: Project
metadata:
  name: "ai-research-project"
  labels:
    # Unprefixed labels for propagation
    owner-team: "data-science-ai"
    criticality: "tier-2"
```

This ensures that as long as the resource exists in Kubernetes, it will be
correctly labeled in the cloud provider's environment.

## Verification

After applying the updated Kubernetes manifests, you can verify the outcome in
two ways:

1.  **In Kubernetes**: Use `kubectl describe project ai-research-project` to
    confirm the labels are present in the resource's metadata.
2.  **In the Cloud Environment**: Use the cloud provider's console or CLI to
    inspect the project's labels. You should see `owner-team: data-science-ai`
    and `criticality: tier-2` alongside the default `managed-by-cnrm: true`
    label.

This confirms that the propagation mechanism is working as expected and that
the project is now correctly classified for inventory and reporting purposes.
