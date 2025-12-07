# EventBus Configuration

The EventBus provides reliable message delivery between EventSource and Sensor.

---

## NATS with Persistence

For production, use NATS with persistence enabled:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  nats:
    native:
      replicas: 3
      auth: token
      persistence:
        storageClassName: standard-rwo
        accessMode: ReadWriteOnce
        volumeSize: 10Gi
      antiAffinity: true
      maxAge: 72h
```

**Why persistence matters:**

| Feature | Without Persistence | With Persistence |
|---------|---------------------|------------------|
| Pod restart | Events lost | Events buffered |
| Network partition | Silent drops | Retry on reconnect |
| Burst handling | Overflow drops | Queue to disk |

!!! danger "Default Configuration Risk"
    Default Jetstream configurations optimize for simplicity. Events missed during pod restarts are gone forever. Production deployments need persistence.

---

## Tuning Parameters

```yaml
spec:
  nats:
    native:
      maxPayload: 1048576  # 1MB max message size
      maxMsgs: 10000       # 10k message buffer
      maxAge: 72h          # Retain messages for 72 hours
```

---

## JetStream EventBus (Production)

For high-throughput production workloads, use JetStream with explicit resource limits:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  jetstream:
    version: 2.10.10
    replicas: 3
    maxPayload: "0"  # Unlimited payload size
    containerTemplate:
      resources:
        requests:
          cpu: 200m
          memory: 600Mi
        limits:
          cpu: 200m
          memory: 600Mi
```

**JetStream vs NATS Native:**

| Feature | NATS Native | JetStream |
|---------|-------------|-----------|
| Message persistence | Manual config | Built-in |
| Stream management | Basic | Advanced (retention, limits) |
| Consumer groups | Limited | Full support |
| Resource efficiency | Lower overhead | Higher throughput |

---

## Related

- [EventSource Configuration](event-sources.md) - Connect to external event sources
- [Sensor Configuration](sensors.md) - Event filtering and workflow triggers
