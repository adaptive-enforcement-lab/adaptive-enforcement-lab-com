---
title: Automating Kubernetes RBAC from Source Code Annotations
nav_title: Automated RBAC
description: >-
  Use source code annotations to automatically generate Kubernetes RBAC policies.
  Synchronize these policies with deployment manifests to prevent configuration
  drift.
---
Automating Kubernetes RBAC generation from source code annotations ensures that
a controller's permissions are the ground truth. This prevents drift between
what developers request and what is actually deployed. This practice codifies
permissions alongside the controller logic that requires them, creating a
single, verifiable source for the operator's ClusterRole.

!!! warning "Manual RBAC Drift Causes Incidents"
    Manually maintaining RBAC policies in deployment charts separate from the
    controller's code is a common source of configuration drift. A controller's
    permission requirements, declared in source code via annotations, can easily
    diverge from the hand-edited YAML, leading to failed deployments or service
    outages when a permission is missing. A past incident involving a
    dependency-management controller was traced directly to this gap: a code
    change requiring new permissions was not manually mirrored in the deployment
    chart.

## Defining Roles in Source

The source of truth for all RBAC permissions should be `+kubebuilder:rbac`
markers directly in the controller's source code. These annotations live next
to the code that needs the permissions, making them easy to review and maintain.
The `controller-gen` tool from the Kubebuilder framework parses these markers
to generate RBAC manifests.

Each marker specifies the API group, resource, and verbs required. The reconciler
for the `StateRun` custom resource, for example, requires permissions to interact
with multiple custom resources and core Kubernetes types.

A typical set of markers might look like this:

```go
//+kubebuilder:rbac:groups=testing.acme.org,resources=testruns,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=testing.acme.org,resources=testruns/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=testing.acme.org,resources=testdefinitions,verbs=get;list;watch
//+kubebuilder:rbac:groups="",resources=secrets,verbs=get;list;watch
```

## The Generation Process

The process of turning annotations into a concrete RBAC manifest is handled
by a build-system target. By adding `controller-gen` to the standard
`make manifests` command, the RBAC `role.yaml` file is generated in the same
step as Custom Resource Definitions (CRDs).

The command `controller-gen rbac:roleName=manager-role` is configured to output
the generated rules into a temporary file, such as `config/rbac/role.yaml`. This
file serves as the canonical, machine-generated definition of the controller's
required permissions. It should not be edited by hand; instead, any changes must
be made to the `+kubebuilder:rbac` markers in the source code.

This generated file is an intermediate artifact, not the final deployment
manifest. It is typically excluded from Git tracking in the `.gitignore` file,
similar to other generated CRD bases.

## Synchronizing with Deployment Manifests

To prevent drift, the generated RBAC rules must be synchronized with the
`ClusterRole` manifest used for deployment, which is often a Helm chart
template. A custom shell script handles this synchronization by replacing a
designated section within the chart's `clusterrole.yaml` template.

The script uses markers to identify the auto-managed block of rules:

```yaml
# clusterrole.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ .Release.Name }}-manager-role
rules:
# BEGIN GENERATED RBAC
# The content in this block is automatically generated. Do not edit manually.
- apiGroups:
  - testing.acme.org
  resources:
  - testruns
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
# END GENERATED RBAC
```

The sync script reads the rules from the intermediate `config/rbac/role.yaml`
and injects them between the `BEGIN` and `END` markers. This approach allows
the `ClusterRole` to contain both generated rules and a small number of manually
managed rules that may exist outside the marked block for special-casing or
conditional logic.

## Integrating into Pre-Commit Hooks

The entire process of generation and synchronization is automated and enforced
through a pre-commit hook. The same hook that checks for stale auto-generated Go
code (`zz_generated.deepcopy.go`) is configured to run `make manifests`.

If a developer adds or changes an RBAC annotation but forgets to run
`make manifests`, the pre-commit hook will detect that the `clusterrole.yaml`
in the Helm chart is out of sync with the generated `role.yaml`. The commit is
blocked until the developer runs the make target and stages the updated chart,
ensuring that RBAC changes are always atomically committed with the code that
requires them.

## Handling Complex and Manual Rules

Initially, some rules may exist in the `ClusterRole` that are not backed by a
`+kubebuilder:rbac` marker. The synchronization script's marker-based approach
allows these to be preserved outside the generated block. However, the best
practice is to resolve these discrepancies by adding the corresponding
annotations to the source code, making the generated block the complete and
exclusive source of rules.

In some cases, rules may be conditional based on Helm values. For example, a
rule granting access to `secrets` and `services` was initially gated on a
`targetNamespaces` value. During an early "prove usage" phase, this conditional
logic was removed in favor of an unconditional cluster-wide grant to simplify
testing and validation. The annotation was made unconditional, and the sync
script absorbed the rule into the main generated block, demonstrating a
deliberate choice to trade least-privilege for implementation velocity, with the
intent to revisit later.

## Verification and Testing

Automated RBAC generation impacts testing. `controller-gen` outputs resources
and verbs in alphabetical order. Any integration tests that assert on the exact
YAML content or rule order within the `ClusterRole` may need to be updated to
match the machine-generated format. Tests for RBAC should verify the *presence*
of required permissions rather than the exact textual representation of the rule
block. For example, a test that previously checked for `get;list;watch` might
fail if the generator outputs `get;list;watch`, but would pass if it correctly
checks for each verb individually.
