---
description: >-
  Run pod-level chaos experiments using Chaos Mesh to validate Kubernetes orchestration recovery, replica scaling, readiness probes, and graceful pod shutdown.
tags:
  - chaos-engineering
  - pod-chaos
  - kubernetes
  - experiments
---

# Pod-Level Chaos Experiments

Pod deletion and crash loop testing experiments to validate application recovery and orchestration behavior.

!!! tip "Pod Deletion Should Be Invisible"
    If deleting a single pod causes user-visible errors, your application is not production-ready. Fix replica counts, readiness probes, and graceful shutdown first.

---

## Experiment 1: Pod Deletion (Crash Loop Testing)

**Purpose**: Validate that applications recover from unexpected crashes and that orchestration properly replaces failed pods.

**Setup**: Deploy a multi-replica service with readiness/liveness probes configured.

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  namespace: chaos-testing
  name: pod-deletion-api-gateway
spec:
  action: pod-kill
  mode: fixed
  value: 1
  duration: 2m
  selector:
    namespaces:
      - production
    labelSelectors:
      app: api-gateway
      tier: web
  scheduling:
    cron: "0 2 * * 1-4"
```

### Expected behavior

1. **0-5s**: Single pod receives SIGTERM, graceful shutdown begins
2. **5-10s**: Pod removed from service endpoints, requests redirect to replicas
3. **10-15s**: Kubernetes detects missing replica, schedules replacement
4. **15-30s**: New pod starts, readiness probe succeeds, rejoins load balancing
5. **30-120s**: System operates at full capacity with replacement pod active

### Success criteria

- P99 latency increases < 50ms during pod deletion
- Error rate never exceeds 0.5% (brief spike acceptable)
- Pod is replaced within 20 seconds
- All traffic successfully redirects to healthy replicas
- Readiness probe on replacement pod succeeds on first check (< 10 seconds)

### Validation queries

```promql
# Check error rate stays below threshold
rate(http_requests_total{status=~"5.."}[1m]) < 0.005

# Verify pod replacement timing
min(time() - pod_created_timestamp_seconds) by (pod)

# Validate latency impact
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[1m])) < 1.5

# Confirm replicas back to desired count
kube_deployment_status_replicas_available{deployment="api-gateway"} == 3
```

### Rollback procedure

If error rate exceeds 2% or latency > 5s:

```bash
# Option 1: Delete the chaos resource
kubectl delete podchaos -n chaos-testing pod-deletion-api-gateway

# Option 2: Manual pod recovery (if needed)
kubectl scale deployment api-gateway -n production --replicas=3

# Verification
kubectl get pods -n production -l app=api-gateway
kubectl logs -n production -l app=api-gateway --tail=20
```

---

## Related Documentation

- **[Network Experiments →](network-experiments.md)** - Network latency and partition testing
- **[Resource Experiments →](resource-experiments.md)** - Memory and CPU pressure testing
- **[Dependency Experiments →](dependency-experiments.md)** - Multi-service resilience testing
- **[Back to Overview](index.md)** - Chaos engineering introduction
