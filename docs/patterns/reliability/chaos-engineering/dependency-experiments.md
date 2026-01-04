---
title: Dependency Chaos Experiments
description: >-
  Test dependency failures with chaos experiments validating circuit breakers, fallback patterns, graceful degradation, and automatic recovery in microservices.
tags:
  - chaos-engineering
  - dependency-chaos
  - kubernetes
  - experiments
---
# Dependency Chaos Experiments

Multi-service resilience testing to validate circuit breakers, fallback patterns, and graceful degradation.

!!! tip "Circuit Breakers Only Work If Tested"
    Most circuit breaker implementations are untested until production failures expose configuration bugs. Chaos experiments validate your fallback logic actually works.

---

## Experiment 4: Dependency Failure (Multi-Service Resilience Testing)

**Purpose**: Validate that the application handles upstream service failures gracefully and that your circuit breaker and fallback patterns actually work.

**Setup**: Multi-service architecture with external API dependency.

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  namespace: chaos-testing
  name: external-api-failure
spec:
  action: partition
  direction: to
  target:
    selector:
      namespaces:
        - production
      podSelector:
        matchLabels:
          app: recommendation-engine
  source:
    selector:
      namespaces:
        - production
      podSelector:
        matchLabels:
          app: ml-service
  mode: all
  duration: 4m
  scheduling:
    cron: "0 4 * * 4"
```

### Expected behavior

1. **0-3s**: Network calls to external API start failing
2. **3-10s**: Application detects failures, opens circuit breaker
3. **10-30s**: Fallback logic activates (cached data, default responses)
4. **30-240s**: Graceful degradation with reduced functionality
5. **240s+**: Network restored, circuit closes, recovery to full operation

### Success criteria

- Circuit breaker opens within 5 failures (10-15 seconds)
- Fallback responses are valid and don't crash consumers
- User-facing error messages are clear (not HTTP 502)
- System continues operating with degraded functionality
- Critical features work even with dependency unavailable
- Recovery is automatic once network restored (no manual intervention)
- No resource leaks (connection pools drain, threads cleanup)

### Validation queries

```promql
# External API call failures increase
increase(external_api_calls_total{status="error"}[1m]) > 0

# Circuit breaker opens
circuit_breaker_state{dependency="ml_service"} == 1

# Fallback responses increase
increase(fallback_responses_total[1m]) > 0

# Critical user features still work
increase(critical_requests_total{status="success"}[1m]) > 0

# No resource exhaustion
go_goroutines{service="recommendation_engine"} < 500

# Recovery happens automatically
circuit_breaker_state{dependency="ml_service"} == 0 at 5m
```

### Rollback procedure

```bash
# Remove network partition
kubectl delete networkchaos -n chaos-testing external-api-failure

# Verify network connectivity restored
kubectl exec -n production deployment/recommendation-engine -- \
  curl -I https://external-ml-service.api

# Force circuit breaker reset (if needed)
kubectl exec -n production deployment/recommendation-engine -- \
  redis-cli SET circuit:ml_service:state CLOSED

# Monitor dependency recovery
kubectl logs -n production deployment/recommendation-engine | \
  grep -E "circuit|fallback|restored" | tail -20

# Validate full recovery
kubectl port-forward -n production svc/recommendation-engine 8080:8080
# Manual test: GET http://localhost:8080/health should return 200 OK
```

---

## Related Documentation

- **[Pod Experiments →](pod-experiments.md)** - Pod deletion and crash loop testing
- **[Network Experiments →](network-experiments.md)** - Network latency and partition testing
- **[Resource Experiments →](resource-experiments.md)** - Memory and CPU pressure testing
- **[Back to Overview](index.md)** - Chaos engineering introduction
