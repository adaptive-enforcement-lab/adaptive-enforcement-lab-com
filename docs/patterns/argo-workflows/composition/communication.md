# Cross-Workflow Communication

Sometimes workflows need to share data or trigger other workflows without direct parent-child relationships. This decoupled communication uses message brokers, shared storage, or Kubernetes resources to bridge the gap.

---

## Why Decouple Workflows?

Parent-child relationships create tight coupling. The parent must know about the child. The child can only be triggered by parents that spawn it. Changes to the child's interface require updating all parents.

Decoupled communication inverts this. Workflows publish events without knowing who consumes them. Workflows subscribe to events without knowing who produces them. The broker mediates, enabling loose coupling.

Use decoupled communication when:

- Multiple independent workflows should react to the same event
- Producers and consumers evolve independently
- Workflows span different clusters or namespaces
- You need retry isolation (consumer failures don't affect producers)

---

## Pub/Sub Communication

The most common pattern uses Google Cloud Pub/Sub (or similar message brokers) to send notifications that Argo Events sensors receive.

**Producer workflow:**

```yaml
templates:
  - name: notify-downstream
    container:
      image: google/cloud-sdk:alpine
      command: ["/bin/bash", "-c"]
      args:
        - |
          gcloud pubsub topics publish pipeline-events \
            --message='{"source":"build-workflow","action":"completed","artifact":"{{workflow.parameters.output}}"}'
```

When this template runs, it publishes a message to Pub/Sub. The workflow continues without waiting for consumers.

**Consumer (Argo Events Sensor):**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
spec:
  dependencies:
    - name: build-completed
      eventSourceName: pubsub-source
      eventName: pipeline-events
      filters:
        data:
          - path: body.action
            type: string
            value: [completed]
  triggers:
    - template:
        name: deploy-trigger
        argoWorkflow:
          operation: submit
          source:
            resource:
              # ... workflow spec
```

The sensor listens for messages with `action: completed` and triggers deployments.

---

## Communication Flow

```mermaid
flowchart LR
    A[Build Workflow] -->|publish| B[Pub/Sub Topic]
    B -->|subscribe| C[EventSource]
    C -->|event| D[EventBus]
    D -->|event| E[Sensor]
    E -->|trigger| F[Deploy Workflow]

    style A fill:#65d9ef,color:#1b1d1e
    style B fill:#9e6ffe,color:#1b1d1e
    style C fill:#fd971e,color:#1b1d1e
    style D fill:#fd971e,color:#1b1d1e
    style E fill:#fd971e,color:#1b1d1e
    style F fill:#a7e22e,color:#1b1d1e
```

The build workflow publishes without knowing about deployment. The deploy workflow triggers without knowing about the build. Pub/Sub and Argo Events bridge the gap.

**Benefits:**

- **Fire-and-forget** - Producer does not wait for consumer
- **Multiple subscribers** - One message can trigger multiple workflows
- **Cross-cluster** - Pub/Sub works across Kubernetes clusters
- **Retry isolation** - Consumer failures do not affect producer

**Tradeoffs:**

- **Invisible connections** - The UI does not show producer-consumer relationships
- **Debugging complexity** - Tracing requires correlating logs across systems
- **Message loss risk** - Without proper persistence, messages can be lost

---

## Shared Storage Communication

For large data, use shared storage instead of messages:

**Writer workflow:**

```yaml
templates:
  - name: write-output
    container:
      image: google/cloud-sdk:alpine
      command: [gsutil, cp, /output/result.json, "gs://bucket/{{workflow.name}}/result.json"]
```

**Reader workflow:**

```yaml
templates:
  - name: read-output
    container:
      image: google/cloud-sdk:alpine
      command: [gsutil, cp, "gs://bucket/{{workflow.parameters.source-workflow}}/result.json", /input/]
```

The reader needs to know the source workflow's name (passed as a parameter or discovered through Pub/Sub metadata).

---

## ConfigMap Communication

For small metadata that needs to be visible to Kubernetes resources:

**Writer:**

```yaml
templates:
  - name: write-status
    resource:
      action: apply
      manifest: |
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: pipeline-status-{{workflow.parameters.run-id}}
        data:
          result: "success"
          artifact-url: "gs://bucket/output.tar.gz"
          completed-at: "{{workflow.creationTimestamp}}"
```

**Reader:**

```yaml
templates:
  - name: read-status
    container:
      image: alpine
      command: [cat, /status/result]
      volumeMounts:
        - name: status
          mountPath: /status
  volumes:
    - name: status
      configMap:
        name: pipeline-status-{{workflow.parameters.run-id}}
```

ConfigMaps work well for coordination metadata like status flags, URLs, and timestamps. They're visible in the Kubernetes API and can be read by any resource with appropriate RBAC.

---

## PVC for Large Data

When workflows share large datasets within a cluster:

```yaml
# Parent creates PVC
spec:
  volumeClaimTemplates:
    - metadata:
        name: shared-data
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 10Gi

# Child mounts the same PVC (passed by name)
templates:
  - name: process
    container:
      image: processor:latest
      volumeMounts:
        - name: data
          mountPath: /data
    volumes:
      - name: data
        persistentVolumeClaim:
          claimName: "{{workflow.parameters.pvc-name}}"
```

PVCs provide filesystem semantics that work naturally with most tools. However, `ReadWriteOnce` access mode means only one pod can mount the volume at a time. Coordinate access carefully to avoid conflicts.

---

## Correlation and Tracing

Decoupled workflows need correlation IDs to trace requests across systems:

```yaml
# Producer includes correlation ID in message
templates:
  - name: notify
    container:
      command: ["/bin/bash", "-c"]
      args:
        - |
          gcloud pubsub topics publish events \
            --message='{"correlation_id":"{{workflow.name}}","action":"completed"}'
```

```yaml
# Consumer extracts and propagates correlation ID
spec:
  triggers:
    - template:
        argoWorkflow:
          parameters:
            - src:
                dependencyName: event
                dataKey: body.correlation_id
              dest: spec.arguments.parameters.0.value
```

With correlation IDs, you can:

- Search logs for all workflows related to a single request
- Build end-to-end timelines across decoupled systems
- Debug failures by following the correlation chain

---

!!! warning "Always Use Correlation IDs"
    Without correlation IDs, debugging decoupled workflows becomes guesswork. Include a correlation ID in every cross-workflow message.

---

## Related

- [Spawning Child Workflows](spawning-children.md) - Coupled alternative to message-based communication
- [Argo Events Setup](../../../patterns/argo-events/setup/index.md) - Configuring EventSource and Sensors
- [Sensor Configuration](../../../patterns/argo-events/setup/sensors.md) - Event filtering and routing
