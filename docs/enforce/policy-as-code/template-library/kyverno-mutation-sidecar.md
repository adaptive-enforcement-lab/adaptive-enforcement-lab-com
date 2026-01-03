---
description: >-
  Automatically inject monitoring, logging, and security sidecar containers into Kubernetes pods with Kyverno mutation policies.
tags:
  - kyverno
  - mutation
  - sidecar
  - observability
  - kubernetes
  - templates
---

# Kyverno Mutation Templates: Sidecar Injection

Automatically injects sidecar containers for logging, monitoring, and security. Enforces observability standards without modifying application manifests.

!!! tip "Sidecars vs Service Mesh"
    Sidecar injection provides observability without mesh complexity. Use mutations for logging/monitoring; use Istio/Linkerd for traffic management.

---

## Template 1: Logging Sidecar Injection

Injects log forwarding sidecar (Fluent Bit) into pods. Centralizes log collection without application changes.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: inject-logging-sidecar
  namespace: kyverno
spec:
  background: false
  rules:
    - name: inject-fluentbit-sidecar
      match:
        resources:
          kinds:
            - Pod
      exclude:
        resources:
          namespaces:
            - kube-system
            - kube-public
            - logging
          selector:
            matchExpressions:
              - key: logging-sidecar
                operator: In
                value: ["false", "disabled"]
      preconditions:
        all:
          - key: "{{ request.object.metadata.labels.\"inject-logging\" || 'true' }}"
            operator: NotEquals
            value: "false"
      mutate:
        patchStrategicMerge:
          spec:
            containers:
              - name: fluent-bit
                image: fluent/fluent-bit:2.1.8
                env:
                  - name: FLUENT_ELASTICSEARCH_HOST
                    value: "elasticsearch.logging.svc.cluster.local"
                  - name: FLUENT_ELASTICSEARCH_PORT
                    value: "9200"
                  - name: POD_NAME
                    valueFrom:
                      fieldRef:
                        fieldPath: metadata.name
                  - name: POD_NAMESPACE
                    valueFrom:
                      fieldRef:
                        fieldPath: metadata.namespace
                  - name: POD_IP
                    valueFrom:
                      fieldRef:
                        fieldPath: status.podIP
                volumeMounts:
                  - name: varlog
                    mountPath: /var/log
                    readOnly: true
                  - name: fluent-bit-config
                    mountPath: /fluent-bit/etc/
                resources:
                  limits:
                    memory: "128Mi"
                    cpu: "100m"
                  requests:
                    memory: "64Mi"
                    cpu: "50m"
            volumes:
              - (name): varlog
                emptyDir: {}
              - (name): fluent-bit-config
                configMap:
                  name: fluent-bit-config
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `logging-backend` | `elasticsearch` | Log destination (Loki, Splunk, etc.) |
| `fluent-bit-version` | `2.1.8` | Fluent Bit container version |
| `sidecar-cpu-limit` | `100m` | CPU limit for logging sidecar |
| `sidecar-memory-limit` | `128Mi` | Memory limit for logging sidecar |
| `opt-out-label` | `inject-logging: "false"` | Disable injection for specific pods |
| `exclude-namespaces` | System namespaces | Skip injection for infrastructure |

### Validation Commands

```bash
# Apply policy
kubectl apply -f inject-logging-sidecar-policy.yaml

# Create ConfigMap for Fluent Bit configuration
kubectl create configmap fluent-bit-config -n default --from-file=fluent-bit.conf

# Create deployment (triggers sidecar injection)
kubectl create deployment app --image=nginx -n default

# Verify sidecar injected
kubectl get pods -n default -o jsonpath='{.items[0].spec.containers[*].name}'

# Expected output: nginx fluent-bit

# View pod YAML to confirm sidecar configuration
kubectl get pod -n default -l app=app -o yaml | grep -A 20 "name: fluent-bit"

# Check sidecar logs
kubectl logs -n default -l app=app -c fluent-bit

# Opt-out of logging injection
kubectl create deployment opt-out --image=nginx -n default
kubectl label deployment opt-out inject-logging=false

# Verify no sidecar injected
kubectl get pod -n default -l app=opt-out -o jsonpath='{.spec.containers[*].name}'

# Expected output: nginx (no fluent-bit)

# Audit pods with logging sidecars
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].name == "fluent-bit") | "\(.metadata.namespace)/\(.metadata.name)"'

# Monitor sidecar resource usage
kubectl top pods -n default --containers | grep fluent-bit
```

### Use Cases

1. **Centralized Logging**: Automatic log forwarding to Elasticsearch/Loki without app changes
2. **Compliance Logging**: Ensure all production workloads forward logs to SIEM
3. **Multi-tenant Observability**: Inject tenant-specific log configurations
4. **Debug Sidecar**: Temporary injection of debug/tracing tools
5. **Zero-Config Logging**: Developers deploy apps without log configuration
6. **Log Enrichment**: Automatically add pod/namespace metadata to logs

---

## Template 2: Monitoring Sidecar Injection

Injects Prometheus metrics exporter sidecar. Enables automatic metrics collection for legacy applications.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: inject-prometheus-exporter
  namespace: kyverno
spec:
  background: false
  rules:
    - name: inject-nginx-exporter
      match:
        resources:
          kinds:
            - Pod
          selector:
            matchLabels:
              app-type: "nginx"
      exclude:
        resources:
          namespaces:
            - kube-system
      mutate:
        patchStrategicMerge:
          metadata:
            annotations:
              +(prometheus.io/scrape): "true"
              +(prometheus.io/port): "9113"
              +(prometheus.io/path): "/metrics"
          spec:
            containers:
              - name: nginx-prometheus-exporter
                image: nginx/nginx-prometheus-exporter:0.11.0
                args:
                  - "-nginx.scrape-uri=http://localhost:80/stub_status"
                ports:
                  - name: metrics
                    containerPort: 9113
                resources:
                  limits:
                    memory: "64Mi"
                    cpu: "50m"
                  requests:
                    memory: "32Mi"
                    cpu: "25m"
    - name: inject-jmx-exporter
      match:
        resources:
          kinds:
            - Pod
          selector:
            matchLabels:
              runtime: "java"
      exclude:
        resources:
          namespaces:
            - kube-system
          selector:
            matchLabels:
              metrics-exporter: "false"
      mutate:
        patchStrategicMerge:
          metadata:
            annotations:
              +(prometheus.io/scrape): "true"
              +(prometheus.io/port): "9404"
              +(prometheus.io/path): "/metrics"
          spec:
            containers:
              - name: jmx-exporter
                image: bitnami/jmx-exporter:0.19.0
                ports:
                  - name: metrics
                    containerPort: 9404
                env:
                  - name: JMX_PORT
                    value: "9999"
                volumeMounts:
                  - name: jmx-config
                    mountPath: /opt/jmx_exporter/config
                resources:
                  limits:
                    memory: "128Mi"
                    cpu: "100m"
                  requests:
                    memory: "64Mi"
                    cpu: "50m"
            volumes:
              - (name): jmx-config
                configMap:
                  name: jmx-exporter-config
    - name: inject-generic-metrics-annotations
      match:
        resources:
          kinds:
            - Pod
          selector:
            matchLabels:
              expose-metrics: "true"
      exclude:
        resources:
          namespaces:
            - kube-system
      preconditions:
        all:
          - key: "{{ request.object.metadata.annotations.\"prometheus.io/scrape\" || '' }}"
            operator: Equals
            value: ""
      mutate:
        patchStrategicMerge:
          metadata:
            annotations:
              +(prometheus.io/scrape): "true"
              +(prometheus.io/port): "{{ request.object.metadata.annotations.\"metrics-port\" || '9090' }}"
              +(prometheus.io/path): "{{ request.object.metadata.annotations.\"metrics-path\" || '/metrics' }}"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `nginx-exporter-version` | `0.11.0` | Nginx exporter container version |
| `jmx-exporter-version` | `0.19.0` | JMX exporter container version |
| `default-metrics-port` | `9090` | Default Prometheus scrape port |
| `default-metrics-path` | `/metrics` | Default Prometheus scrape path |
| `opt-out-label` | `metrics-exporter: "false"` | Disable injection |

### Validation Commands

```bash
# Apply policy
kubectl apply -f inject-prometheus-exporter-policy.yaml

# Create nginx deployment with app-type label
kubectl create deployment nginx --image=nginx -n default
kubectl label deployment nginx app-type=nginx

# Verify nginx-exporter sidecar injected
kubectl get pod -n default -l app=nginx -o jsonpath='{.spec.containers[*].name}'

# Expected output: nginx nginx-prometheus-exporter

# Check Prometheus annotations
kubectl get pod -n default -l app=nginx -o jsonpath='{.metadata.annotations}' | jq

# Create Java application
kubectl create deployment java-app --image=openjdk:11-jre -n default
kubectl label deployment java-app runtime=java

# Verify JMX exporter sidecar injected
kubectl get pod -n default -l app=java-app -o jsonpath='{.spec.containers[*].name}'

# Expected output: java-app jmx-exporter

# Test metrics endpoint
kubectl port-forward -n default deployment/nginx 9113:9113
curl http://localhost:9113/metrics

# Verify Prometheus scraping
kubectl get servicemonitors -A

# Audit pods with metrics exporters
kubectl get pods -A -o json | jq -r '.items[] | select(.metadata.annotations."prometheus.io/scrape" == "true") | "\(.metadata.namespace)/\(.metadata.name): port=\(.metadata.annotations."prometheus.io/port")"'
```

### Use Cases

1. **Legacy Application Monitoring**: Add metrics to apps without native Prometheus support
2. **Automatic Scrape Configuration**: Inject Prometheus annotations automatically
3. **Runtime-Specific Exporters**: JMX for Java, nginx-exporter for NGINX, etc.
4. **Zero-Config Observability**: Deploy apps without metrics configuration
5. **Multi-tenant Metrics**: Inject tenant-specific metric labels
6. **Compliance Monitoring**: Ensure all production workloads expose metrics

---

## Related Resources

- **[Kyverno Mutation - Labels →](kyverno-mutation-labels.md)** - Auto-label resources
- **[Kyverno Pod Security →](kyverno-pod-security.md)** - Security contexts and capabilities
- **[Kyverno Resource Limits →](kyverno-resource-limits.md)** - Resource requests and limits
- **[Kyverno Image Validation →](kyverno-image-validation.md)** - Image security
- **[Template Library Overview →](index.md)** - Back to main page
