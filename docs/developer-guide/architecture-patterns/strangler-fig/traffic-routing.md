---
title: Traffic Routing Strategies
description: >-
  Percentage-based, user-based, and canary deployment patterns for controlling
  traffic flow during incremental migration.
---

# Traffic Routing Strategies

Three routing strategies control traffic distribution: percentage-based for gradual rollout, user-based for consistent experience, and canary deployment for replica-level control.

---

## Strategy 1: Percentage-Based

Route random percentage of requests to new system:

```yaml
# Envoy HTTP filter
- name: envoy.filters.http.header_mutation
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.filters.http.header_mutation.v3.HeaderMutation
    mutations:
      - header:
          key: x-traffic-split
          value: "{{ random(0,100) }}"

# Route based on header
- match:
    headers:
      - name: x-traffic-split
        range_match:
          start: 0
          end: 10  # 10% to new system
  route:
    cluster: new-api

- match:
    prefix: "/"
  route:
    cluster: legacy-api
```

Random split at proxy layer. 10% header value routes to new API. Rest goes to legacy.

---

## Strategy 2: User-Based

Hash user ID for consistent routing:

```go
func routeTraffic(userID string) string {
    // Hash user ID to consistent routing
    hash := hashUserID(userID)

    if hash % 100 < rolloutPercentage {
        return "new-system"
    }
    return "legacy-system"
}
```

Same user always sees same system. No UI flip-flop.

User 12345 hashed to 73. If rollout is 80%, user gets new system. Tomorrow, same calculation, same result.

---

## Strategy 3: Canary Deployment

Control traffic via replica counts:

```yaml
# Kubernetes service with weighted routing
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: api

---
# Legacy deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-legacy
spec:
  replicas: 9  # 90% of traffic
  template:
    metadata:
      labels:
        app: api
        version: legacy

---
# New deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-v2
spec:
  replicas: 1  # 10% of traffic
  template:
    metadata:
      labels:
        app: api
        version: v2
```

Scale replicas to control traffic distribution.

9 legacy pods + 1 new pod = 10% traffic to new system. Load balancer distributes evenly across all pods with `app: api` label.

Increase v2 replicas, decrease legacy replicas. Traffic shifts proportionally.

---

## Choosing a Strategy

| Strategy | Pros | Cons | Use When |
| ---------- | ------ | ------ | ---------- |
| **Percentage-Based** | Simple, gradual rollout | Users might flip between systems | Testing at scale, low state |
| **User-Based** | Consistent experience | Harder to control exact percentage | User-facing features, high state |
| **Canary** | Infrastructure-level control | Coarse-grained (discrete replicas) | Kubernetes native, resource testing |

---

## Related Patterns

- **[Implementation Strategies](implementation.md)** - Feature flags and dual writes
- **[Monitoring and Rollback](monitoring.md)** - Track metrics, instant rollback
- **[Migration Guide](migration-guide.md)** - Step-by-step process

---

*Traffic routing controlled the rollout. Percentage-based for initial validation. User-based for consistent experience. Canary for infrastructure testing. The migration proceeded without user-facing incidents.*
