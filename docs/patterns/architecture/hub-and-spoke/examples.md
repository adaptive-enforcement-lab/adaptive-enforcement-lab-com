---
title: Hub and Spoke Implementation Examples
description: >-
  GitHub Actions file distribution, event-driven Argo workflows, and hub-spoke communication patterns for parallel execution across multiple repositories.
---

# Hub and Spoke Implementation Examples

## GitHub Actions Example

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

Hub distributes file changes across repositories:

```yaml
# .github/workflows/distribute.yml
name: Hub File Distribution

on:
  workflow_dispatch:
    inputs:
      file_path:
        description: "File to distribute"
        required: true

jobs:
  discover:
    runs-on: ubuntu-latest
    outputs:
      repositories: ${{ steps.find.outputs.repos }}
    steps:
      - name: Find target repositories
        id: find
        run: |
          REPOS=$(gh api orgs/myorg/repos --jq '[.[] | .name]')
          echo "repos=$REPOS" >> $GITHUB_OUTPUT

  distribute:
    needs: discover
    runs-on: ubuntu-latest
    strategy:
      matrix:
        repo: ${{ fromJson(needs.discover.outputs.repositories) }}
    steps:
      - name: Trigger spoke workflow
        run: |
          gh workflow run spoke-update.yml \
            --repo myorg/${{ matrix.repo }} \
            --field file="${{ github.event.inputs.file_path }}"

  summarize:
    needs: distribute
    runs-on: ubuntu-latest
    steps:
      - name: Collect results
        run: |
          echo "Distribution complete across all repositories"
```

Hub finds repos, triggers spoke workflows via matrix, summarizes at the end.

---

## Event-Driven Hub

Argo Events hub reacts to events:

```yaml
# EventSource: listens for image pushes
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: image-push-source
spec:
  pubsub:
    artifact-registry:
      projectID: my-project
      topic: image-pushes

# Sensor: hub that spawns spokes
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: deployment-hub
spec:
  triggers:
    - template:
        name: spawn-deployment-spokes
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: hub-deploy-
              spec:
                workflowTemplateRef:
                  name: deployment-hub
                arguments:
                  parameters:
                    - name: image
                      value: "{{.Input.body.image}}"
```

Event arrives → Hub workflow spawns → Spokes execute → Results collected.

See [Event-Driven Deployments](../../../blog/posts/2025-12-14-event-driven-deployments-argo.md) for full implementation.

---

## Communication Patterns

### Pattern 1: Hub Passes Data to Spokes

```yaml
- name: spawn-spoke
  inputs:
    parameters:
      - name: data
  resource:
    manifest: |
      spec:
        arguments:
          parameters:
            - name: input-data
              value: "{{inputs.parameters.data}}"
```

Hub collects data, spokes process it.

### Pattern 2: Spokes Report Back via Artifacts

```yaml
# Spoke outputs artifact
- name: spoke-worker
  outputs:
    artifacts:
      - name: result
        path: /tmp/result.json

# Hub collects artifacts
- name: collect-results
  inputs:
    artifacts:
      - name: spoke-results
        from: "{{tasks.process-repo.outputs.artifacts.result}}"
```

### Pattern 3: Shared State via ConfigMap

```yaml
# Hub writes to ConfigMap
- name: hub-init
  resource:
    action: create
    manifest: |
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: job-state
      data:
        status: "in-progress"

# Spokes read from ConfigMap
- name: spoke-worker
  volumes:
    - name: state
      configMap:
        name: job-state
```

---
