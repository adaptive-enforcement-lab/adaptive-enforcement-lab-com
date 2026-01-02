---
title: Pod Security Standards
description: Enforce Pod Security Standards with restricted, baseline, and privileged levels for namespace-level workload security policies in production GKE environments.
---

# Pod Security Standards

Pod Security Standards enforce security policies at the pod level. Configure based on workload sensitivity.

!!! info "Standard Levels"

    - **Privileged**: Unrestricted (not recommended)
    - **Baseline**: Minimal restrictions, prevents known exploits
    - **Restricted**: Hardened, enforces security best practices

## Terraform Configuration

```hcl
# gke/security/pod-security.tf
resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"

    labels = {
      "pod-security.kubernetes.io/enforce"        = "restricted"
      "pod-security.kubernetes.io/audit"          = "restricted"
      "pod-security.kubernetes.io/warn"           = "restricted"
    }
  }
}

resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"

    labels = {
      "pod-security.kubernetes.io/enforce"        = "baseline"
      "pod-security.kubernetes.io/audit"          = "restricted"
      "pod-security.kubernetes.io/warn"           = "restricted"
    }
  }
}

resource "kubernetes_namespace" "system" {
  metadata {
    name = "kube-system"

    labels = {
      "pod-security.kubernetes.io/enforce"        = "privileged"
    }
  }
}
```

!!! warning "Production Standard"

    Production namespaces must use `restricted` standard. Development can use `baseline` for compatibility.

## Pod Manifest Examples

```yaml
# manifests/secure-pod.yaml
---
# Secure pod for production
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: prod
spec:
  serviceAccountName: secure-app

  containers:
    - name: app
      image: gcr.io/my-project/secure-app:latest
      imagePullPolicy: Always

      securityContext:
        allowPrivilegeEscalation: false
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
          add:
            - NET_BIND_SERVICE

      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 512Mi

      livenessProbe:
        httpGet:
          path: /health
          port: 8080
        initialDelaySeconds: 10
        periodSeconds: 10
        timeoutSeconds: 5
        failureThreshold: 3

      readinessProbe:
        httpGet:
          path: /ready
          port: 8080
        initialDelaySeconds: 5
        periodSeconds: 5
        timeoutSeconds: 3
        failureThreshold: 3

      volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache

  volumes:
    - name: tmp
      emptyDir: {}
    - name: cache
      emptyDir:
        sizeLimit: 1Gi

  # Pod security context
  securityContext:
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault

  # Network policies (implicit default-deny)
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app
                  operator: In
                  values:
                    - secure-app
            topologyKey: kubernetes.io/hostname
```

!!! tip "Security Best Practices"

    - Always set `runAsNonRoot: true`
    - Drop all capabilities, add only what's needed
    - Use `readOnlyRootFilesystem: true` when possible
    - Define resource limits to prevent DoS

## Deployment Workflow

### 1. Configure Pod Security Standards

```bash
# Label production namespace for restricted policy
kubectl label namespace prod pod-security.kubernetes.io/enforce=restricted
kubectl label namespace prod pod-security.kubernetes.io/audit=restricted
kubectl label namespace prod pod-security.kubernetes.io/warn=restricted

# Verify labels
kubectl get namespace prod -o yaml | grep pod-security
```

## Runtime Security Checklist

```bash
#!/bin/bash
# Pod Security Standards verification

echo "=== Pod Security Standards ==="
kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.pod-security\.kubernetes\.io/enforce}{"\n"}{end}' | column -t

echo ""
echo "=== Pod Security Violations ==="
kubectl get events --all-namespaces --field-selector reason=FailedCreate | grep -i "violates PodSecurity" | wc -l | \
  awk '{if ($1 > 0) print "⚠ "$1" pod security violations"; else print "✓ No violations"}'
```

## Related Content

- **[Admission Controllers](admission-controllers.md)** - Pre-deployment validation
- **[Runtime Monitoring](runtime-monitoring.md)** - Behavioral analysis and alerting
- **[Cluster Configuration](../cluster-configuration/index.md)** - Private GKE cluster setup

## References

- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
