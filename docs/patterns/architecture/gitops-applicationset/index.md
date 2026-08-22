---
title: GitOps Multi-Cluster Delivery with ArgoCD ApplicationSets
tags:
  - architecture
  - patterns
  - gitops
  - argocd
  - kubernetes
description: >-
  Generate and sync ArgoCD Applications across many clusters with ApplicationSets, safe sync policies, and least-privilege RBAC.
---

# GitOps Multi-Cluster Delivery with ArgoCD ApplicationSets

One `Application` manifest per cluster works until it doesn't. Past a handful of clusters, hand-written manifests turn into copy-paste sprawl.

Every new cluster means a new file. Every config drift means a manual diff. Every environment means another chance to miss one.

!!! tip "Implementation Guide"
    This guide is part of a modular documentation set. Refer to related guides for complete context.

ApplicationSets solve this by generating `Application` resources from a template plus a data source. Define the template once. Let a generator produce one Application per cluster, per environment, or per directory in a Git repository.

## The Problem

A single `Application` manifest targets a single cluster:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api-cluster-1
spec:
  project: default
  source:
    repoURL: https://github.com/example-org/manifests
    path: apps/api
    targetRevision: main
  destination:
    server: https://cluster-1.example.internal
    namespace: api
```

Ten clusters means ten of these, hand-maintained. A change to the sync policy, the source path, or the project means editing ten files and hoping none of them drift out of sync with each other.

App-of-apps (a parent `Application` that manages a tree of child `Application` manifests) organizes the sprawl into a directory structure. It still requires a manifest per cluster somewhere in that tree. It doesn't remove the sprawl, it just files it neatly.

ApplicationSets remove the manual step entirely. A generator produces the list of target clusters or paths at reconciliation time, and the controller renders one `Application` per entry from a shared template.

## ApplicationSet Generators

Three generators cover most multi-cluster delivery needs: an explicit list, cluster auto-discovery, and a Git-driven fan-out.

### List Generator

Use the list generator when the target set is small, static, and known up front. It's the most explicit option: every cluster is spelled out in the manifest.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: api-list
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: cluster-1
            url: https://cluster-1.example.internal
            env: dev
          - cluster: cluster-2
            url: https://cluster-2.example.internal
            env: staging
  template:
    metadata:
      name: "api-{{cluster}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/example-org/manifests
        path: "apps/api/overlays/{{env}}"
        targetRevision: main
      destination:
        server: "{{url}}"
        namespace: api
      syncPolicy:
        automated:
          selfHeal: true
```

Adding a cluster means adding an entry to `elements`. No new file, no copy-paste template.

### Cluster Generator

Use the cluster generator when clusters are already registered with ArgoCD (via `argocd cluster add` or a `Secret` labeled for cluster discovery) and the target set should track that registry automatically. A label selector narrows which registered clusters participate.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: api-cluster-discovery
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment-tier: workload
  template:
    metadata:
      name: "api-{{name}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/example-org/manifests
        path: "apps/api/overlays/{{metadata.labels.env}}"
        targetRevision: main
      destination:
        server: "{{server}}"
        namespace: api
      syncPolicy:
        automated:
          selfHeal: true
```

Register a new cluster with the `environment-tier: workload` label and it picks up the `api` application on the next reconciliation.

Deregister it and the ApplicationSet controller removes the corresponding Application. Depending on `syncPolicy.preserveResourcesOnDeletion`, it may remove the deployed resources too. See [Rollback and Pruning Safety Guardrails](#rollback_and_pruning_safety_guardrails) below.

### Git Generator

Use the Git generator to template one set of manifests across many target paths in a repository. It supports either directories or files, whichever matches how the repo is organized. This is the fan-out pattern behind most "one set of manifests, many clusters" setups.

Directory mode treats each matching directory as a generator entry:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: api-git-directories
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/example-org/fleet-config
        revision: main
        directories:
          - path: "clusters/*"
  template:
    metadata:
      name: "api-{{path.basename}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/example-org/manifests
        path: apps/api
        targetRevision: main
      destination:
        server: "https://{{path.basename}}.example.internal"
        namespace: api
      syncPolicy:
        automated:
          selfHeal: true
```

File mode reads structured data (JSON or YAML) out of matching files. Use it when each cluster needs more metadata than a directory name conveys:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: api-git-files
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/example-org/fleet-config
        revision: main
        files:
          - path: "clusters/*/config.yaml"
  template:
    metadata:
      name: "api-{{cluster}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/example-org/manifests
        path: "apps/api/overlays/{{env}}"
        targetRevision: main
      destination:
        server: "{{url}}"
        namespace: api
      syncPolicy:
        automated:
          selfHeal: true
```

Adding a cluster becomes a Git commit: drop a new `clusters/<name>/config.yaml`, merge it, and the ApplicationSet controller generates the Application on the next reconciliation. No direct interaction with the ArgoCD API required.

## Sync Policies: Automated, Self-Heal, Prune

Three independent flags control how aggressively ArgoCD reconciles the live cluster state toward Git:

| Setting | What it does | Risk if misused |
| --------- | --------------- | ------------------ |
| `automated` | Syncs automatically when Git changes, instead of waiting for a manual sync | Low. Just removes the manual trigger. |
| `selfHeal` | Reverts manual `kubectl` changes back to what's in Git on the next reconciliation loop | Low. It's the point of GitOps, but the cluster is not safe to hand-edit. |
| `prune` | Deletes live resources that no longer exist in Git | High. A bad merge, a moved directory, or a Git generator matching the wrong path deletes real resources. |

Safe defaults for anything that isn't a disposable environment:

```yaml
syncPolicy:
  automated:
    selfHeal: true
    prune: false   # require an explicit, reviewed step to delete resources
  syncOptions:
    - CreateNamespace=false
```

`selfHeal: true` is close to free. It enforces that Git is the only path to change, which is the entire point of adopting GitOps.

`prune: true` is where the actual risk lives. It turns "resource missing from Git" into "resource deleted from the cluster."
A Git generator with an overly broad path match, a rename that isn't reflected everywhere, or a bad rebase can make resources disappear from Git by accident.
Enable `prune` deliberately, per environment, once the team trusts the pipeline that produces the manifests. Don't enable it as a default.

## Promoting Through Environments Safely

The multi-cluster fan-out from a Git or cluster generator answers "how do I deploy the same thing everywhere." It doesn't answer "how do I trust a change enough to deploy it everywhere." Those are separate problems, and conflating them is how a bad change lands on every cluster simultaneously.

Environment promotion validates a change in one environment before it reaches the next.
It's a separate, complementary pattern, covered in full in [Environment Progression Testing](../environment-progression.md).
The short version: gate the `targetRevision` (or the overlay path) that each tier's Application points at, and advance it stage by stage rather than pointing every cluster at the same moving branch.

```yaml
# Dev cluster tracks the branch directly: fast feedback, low blast radius
targetRevision: main

# Staging tracks a tag that's promoted after dev validates
targetRevision: release-candidate

# Production tracks a tag that's promoted after staging validates
targetRevision: stable
```

An ApplicationSet's list or file generator is a natural place to encode this. Each entry names its own `targetRevision` alongside its cluster, so the generator itself becomes the promotion manifest.

If your organization has a defined environment order, longer than the simple dev-staging-production chain shown above, the ApplicationSet template should walk changes through that same order rather than syncing every tier from the same ref.
See [Environment Progression Testing](../environment-progression.md) for the validation gates that belong between each stage.

## Least-Privilege RBAC

ArgoCD's own RBAC (the `argocd-rbac-cm` ConfigMap, expressed as policy CSV lines) controls which humans and CI identities can act on which `AppProject`. Scope an `AppProject` per environment tier or per team, and restrict it to the source repositories and destination clusters it actually owns:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: fleet-workloads
  namespace: argocd
spec:
  sourceRepos:
    - https://github.com/example-org/manifests
    - https://github.com/example-org/fleet-config
  destinations:
    - server: "*"
      namespace: api
  clusterResourceWhitelist: []  # no cluster-scoped resources from this project
  namespaceResourceWhitelist:
    - group: apps
      kind: Deployment
    - group: ""
      kind: Service
    - group: ""
      kind: ConfigMap
```

`clusterResourceWhitelist: []` blocks the project from ever creating a `ClusterRole`, a `Namespace`, or any other cluster-scoped object.
An ApplicationSet targeting this project physically cannot escalate past namespace boundaries, no matter what a generator produces.
`namespaceResourceWhitelist` narrows further, to exactly the kinds this fleet of applications legitimately deploys.

This is the same least-privilege principle applied at the Kubernetes RBAC layer, for the ArgoCD controller's own ServiceAccount and for any CLI or CI identity acting against the cluster.
See [RBAC Configuration](../../argo-workflows/templates/rbac.md) for the ServiceAccount, Role, and RoleBinding pattern, and the `resourceNames` restriction technique.
It applies just as well to scoping what the ArgoCD application controller can touch on a target cluster.

## Drift Detection and Reconciliation Loop

ArgoCD's application controller runs a continuous reconciliation loop. It reads the desired state from Git, reads the live state from the target cluster, diffs them, and corrects the difference automatically when `automated.selfHeal` is set.
This runs on a timer (default three minutes) and on webhook-triggered Git changes, whichever comes first.

Drift shows up in the ArgoCD UI and CLI as one of three sync states:

- **Synced**: live state matches Git, nothing to do
- **OutOfSync**: live state differs from Git, either because Git changed or because something (a person, another controller) changed the cluster directly
- **Unknown**: the controller couldn't compute a diff, usually a CRD or plugin issue

`selfHeal: true` closes the loop automatically. Any OutOfSync state triggered by a direct cluster change reverts on the next reconciliation. Without it, drift accumulates silently until someone notices the UI showing OutOfSync and syncs manually, by which point nobody remembers what changed or why.

!!! warning "Treat sustained drift as an alert, not a curiosity"
    A cluster that's been OutOfSync for hours means either self-heal is off somewhere it shouldn't be, or something is actively fighting the reconciliation loop. Alert on it. Don't wait for someone to notice the UI.

## Rollback and Pruning Safety Guardrails

This is the section that keeps a bad promotion from turning into a cluster-wide incident.

**Never enable `prune: true` on a generator whose path match is broader than intended.**
A Git generator using `directories: [{path: "clusters/*"}]` matches every directory under `clusters/`, including one that got created by accident during a rebase.
If `prune` is on, ArgoCD deletes every resource belonging to Applications generated from paths that no longer exist, including paths that were only ever meant to be temporary.
Pin the glob as tightly as the actual cluster layout allows. Treat any generator path widening as a change that needs the same review a production deploy gets.

**Use `preserveResourcesOnDeletion` when an ApplicationSet's generator output can shrink.**
If a cluster generator's label selector stops matching a cluster (the label was removed, the cluster was deregistered), the ApplicationSet controller deletes the generated Application.
By default that cascades to deleting the resources that Application deployed.
Set `preserveResourcesOnDeletion: true` in `spec.syncPolicy` when losing a generator entry should orphan the resources instead of tearing them down. This is appropriate for anything where "stop managing this" and "delete this" are meaningfully different operations:

```yaml
spec:
  syncPolicy:
    applicationsSync: create-update  # never auto-delete generated Applications
    preserveResourcesOnDeletion: true
```

**Roll back through Git, not through the ArgoCD UI.**
ArgoCD supports rolling an Application back to a previous sync revision directly, but that's a one-off override.
The next automated sync undoes it immediately, or, if `selfHeal` catches it first, reverts it before the operator even confirms the rollback worked.
The durable rollback is a Git revert, or a `targetRevision` pointer moved back to the last known-good tag, the same mechanism that promoted the change forward.
Treat the UI-level rollback as a stopgap for the minutes it takes to push the real fix, not the fix itself.

**Stage `prune` rollout the same way you stage the applications themselves.**
Turn it on for dev first, watch it run clean for a review cycle, then promote it to staging, then production, the same environment progression the workloads themselves go through.
A `prune` setting that's never been exercised in a lower environment is a `prune` setting nobody has verified is safe.

## Related

- [The Cold Sweat Deploy](../../../blog/posts/2026-08-09-the-cold-sweat-deploy.md) - the incident that motivated writing this pattern down. A midnight `kubectl apply` failure across a growing cluster fleet, and the move to declarative, Git-driven delivery that followed.
- [Hub and Spoke](../hub-and-spoke/index.md) - the same centralize-coordination, distribute-execution shape, applied to workflow orchestration instead of cluster delivery.
- [Environment Progression Testing](../environment-progression.md) - promoting a single service through dev, staging, and production. The validation gate that should sit in front of any environment tier an ApplicationSet targets.
