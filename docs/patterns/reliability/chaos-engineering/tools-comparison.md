---
title: Chaos Engineering Tools Comparison
description: >-
  Chaos Mesh vs LitmusChaos comparison. Tool capabilities, use cases, and selection guidance for Kubernetes chaos engineering.
tags:
  - chaos-mesh
  - litmuschaos
  - kubernetes
  - tools
---
# Chaos Engineering Tools Comparison

!!! note "Tool Selection Depends on Maturity"
    Start with Chaos Mesh for simplicity. Add LitmusChaos when you need workflow orchestration. Most teams don't need both on day one.

## Chaos Mesh vs LitmusChaos Comparison

**Chaos Mesh** excels at infrastructure-level chaos:

- Pod deletion, network delays, I/O faults
- CPU throttling, memory pressure
- Clock skew and DNS hijacking
- Clean CRD-based configuration

**LitmusChaos** adds workflow orchestration:

- Experiment chaining (setup → chaos → validation → cleanup)
- Native Argo Workflows integration
- Community experiment library (GameDays, pod deletion suites)
- Chaos hub for experiment discovery

**Recommendation**: Use Chaos Mesh for steady-state injection (detection testing), LitmusChaos for orchestrated experiments (chaos games, rollback validation).

## Feature Matrix

| Feature | Chaos Mesh | LitmusChaos |
|---------|-----------|-------------|
| **Pod Chaos** | ✅ Excellent | ✅ Excellent |
| **Network Chaos** | ✅ Comprehensive | ✅ Basic |
| **I/O Chaos** | ✅ Native | ⚠️ Via custom experiments |
| **Workflow Orchestration** | ⚠️ Manual | ✅ Built-in with Argo |
| **Experiment Library** | ⚠️ Limited | ✅ Extensive |
| **Cloud Provider Integration** | ⚠️ Basic | ✅ AWS, GCP, Azure |
| **Observability** | ⚠️ Prometheus metrics | ✅ Integrated dashboards |
| **Installation Complexity** | Simple (Helm) | Moderate (Helm + Argo) |

## Selection Guidance

### Choose Chaos Mesh if

- You need fine-grained control over infrastructure-level faults
- Network chaos (latency, partition, bandwidth) is your primary use case
- You want minimal dependencies and simple installation
- You're building your own orchestration layer

### Choose LitmusChaos if

- You need pre-built experiment workflows
- You want community-contributed scenarios
- Argo Workflows is already in your stack
- You need cloud provider-specific chaos (EC2 termination, GKE node failure)

### Use Both if

- You want Chaos Mesh's infrastructure chaos with LitmusChaos's orchestration
- You're running complex GameDays with multiple failure types
- You have different teams with different preferences

## Integration with Argo Workflows

LitmusChaos integrates natively with Argo Workflows for complex chaos journeys:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: chaos-game-day
spec:
  entrypoint: game-day-scenario
  templates:
    - name: game-day-scenario
      steps:
        - - name: baseline
            template: collect-metrics
            arguments:
              parameters:
                - name: duration
                  value: "3m"

        - - name: pod-deletion
            template: inject-pod-chaos

        - - name: measure-pod-impact
            template: collect-metrics
            arguments:
              parameters:
                - name: duration
                  value: "3m"

        - - name: network-latency
            template: inject-network-chaos

        - - name: measure-combined-impact
            template: collect-metrics
            arguments:
              parameters:
                - name: duration
                  value: "5m"

        - - name: cleanup
            template: remove-all-chaos

        - - name: analyze
            template: generate-report

    - name: inject-pod-chaos
      resource:
        action: create
        manifest: |
          apiVersion: chaos-mesh.org/v1alpha1
          kind: PodChaos
          metadata:
            namespace: chaos-testing
            name: pod-kill-{{workflow.parameters.target}}
          spec:
            action: pod-kill
            mode: fixed
            value: 1
            selector:
              labelSelectors:
                app: "{{workflow.parameters.target}}"
            duration: 2m

    - name: inject-network-chaos
      resource:
        action: create
        manifest: |
          apiVersion: chaos-mesh.org/v1alpha1
          kind: NetworkChaos
          metadata:
            namespace: chaos-testing
            name: latency-{{workflow.parameters.target}}
          spec:
            action: delay
            delay:
              latency: "250ms"
            selector:
              labelSelectors:
                app: "{{workflow.parameters.target}}"
            duration: 3m

    - name: collect-metrics
      inputs:
        parameters:
          - name: duration
      script:
        image: curlimages/curl:latest
        command: [sh]
        source: |
          #!/bin/sh
          echo "Collecting metrics for {{inputs.parameters.duration}}"
          # Query Prometheus or observability platform
          sleep {{inputs.parameters.duration}}

    - name: remove-all-chaos
      shell:
        image: bitnami/kubectl:latest
        source: |
          kubectl delete podchaos,networkchaos \
            -n chaos-testing \
            --all

    - name: generate-report
      script:
        image: python:3.11
        source: |
          import json
          report = {
              "workflow": "game-day-scenario",
              "status": "completed",
              "findings": []
          }
          with open("/tmp/report.json", "w") as f:
              json.dump(report, f)
```

## Related Documentation

- **[Back to Overview](index.md)** - Chaos engineering introduction
- **[Blast Radius Control](blast-radius.md)** - Targeting and safety controls
- **[Experiment Catalog](experiments.md)** - Ready-to-use experiments
