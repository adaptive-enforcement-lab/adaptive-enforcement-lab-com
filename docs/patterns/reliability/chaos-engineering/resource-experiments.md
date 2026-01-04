---
title: Resource Chaos Experiments
description: >-
  Resource chaos experiments. Memory pressure and CPU stress testing with OOM kill validation and recovery procedures.
tags:
  - chaos-engineering
  - resource-chaos
  - kubernetes
  - experiments
---
# Resource Chaos Experiments

Memory pressure and CPU stress testing to validate resource limit enforcement and graceful degradation.

!!! danger "OOMKill Is Not Graceful Shutdown"
    When Kubernetes kills a pod for exceeding memory limits, it uses SIGKILL, not SIGTERM. Your application has zero time to clean up. Test memory limits under realistic load.

---

## Experiment 3: Memory Pressure (Resource Exhaustion Testing)

**Purpose**: Verify that the application gracefully handles memory pressure and that Kubernetes properly evicts or restarts memory-intensive containers.

**Setup**: Service with memory limits and OOM kill guards configured.

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  namespace: chaos-testing
  name: memory-pressure-worker
spec:
  action: stress
  stressors:
    memory:
      workers: 1
      size: "256MB"
  duration: 3m
  selector:
    namespaces:
      - production
    labelSelectors:
      app: background-worker
      memory-stress-target: "true"
  mode: fixed
  value: 1
```

### Expected behavior

1. **0-10s**: Memory consumption increases gradually
2. **10-30s**: Application detects memory pressure, triggers cleanup
3. **30-60s**: If memory exceeds soft limits, shed non-critical operations
4. **60-120s**: Container memory usage approaches cgroup limit
5. **120-180s**: If memory exceeds hard limit, OOMKill triggers pod restart
6. **180s+**: Replacement pod schedules and recovers

### Success criteria

- Memory pressure doesn't cause thread exhaustion
- Garbage collection frequency increases appropriately
- Non-critical background tasks are deferred or cancelled
- Pod remains responsive (health checks pass) until hard limit
- If OOMKilled, replacement pod starts within 30 seconds
- No hung processes or deadlocks during recovery
- Persistent state is not corrupted (database checks pass)

### Validation queries

```promql
# Memory consumption stays below limit
container_memory_usage_bytes{pod=~"worker.*"} < 256e6

# GC pause time increases during stress
rate(jvm_gc_duration_seconds_sum[1m]) > 0.01

# Task queue backlog indicates load shedding
background_task_queue_length < previous_value

# Pod restart count increases only if memory exhausted
increase(kube_pod_container_status_restarts_total{pod=~"worker.*"}[5m]) <= 1

# Recovery is fast after memory stress removed
max(container_memory_usage_bytes{pod=~"worker.*"}) - avg(container_memory_usage_bytes{pod=~"worker.*"}) < 50e6
```

### Rollback procedure

```bash
# Remove memory stress chaos
kubectl delete stresschaos -n chaos-testing memory-pressure-worker

# Verify pod stability
kubectl get pods -n production -l app=background-worker
kubectl describe pod -n production -l app=background-worker | grep -A 5 "Last State"

# Check memory normalizes
kubectl top pods -n production -l app=background-worker

# If pod is stuck, force restart
kubectl rollout restart deployment/background-worker -n production

# Validate data integrity
kubectl exec -n production deployment/background-worker -- \
  sql-validate-schema.sh
```

---

## Related Documentation

- **[Pod Experiments →](pod-experiments.md)** - Pod deletion and crash loop testing
- **[Network Experiments →](network-experiments.md)** - Network latency and partition testing
- **[Dependency Experiments →](dependency-experiments.md)** - Multi-service resilience testing
- **[Back to Overview](index.md)** - Chaos engineering introduction
