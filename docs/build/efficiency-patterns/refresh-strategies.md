---
title: ConfigMap Cache Refresh Strategies
description: >-
  Strategies for updating ConfigMap cache data: manual updates, automated CronJob refresh, event-driven refresh, and RBAC configuration for cache updaters.
tags:
  - kubernetes
  - configmap
  - automation
  - cronjob
  - operators
---

# ConfigMap Cache Refresh Strategies

How to update ConfigMap cache data: manual updates, automated refresh with CronJob, event-driven updates, and RBAC patterns.

!!! tip "Choose Your Strategy"
    Manual updates for infrequent changes. Automated CronJob for regular refresh. Event-driven for source data changes. Pick the pattern that matches your data update frequency.

---

## 1. Manual Update

```bash
# Update ConfigMap
kubectl create configmap workflow-cache --from-file=mappings.json --dry-run=client -o yaml | kubectl apply -f -

# Rollout restart to pick up changes (Deployments)
kubectl rollout restart deployment/my-app

# Note: Workflows pick up changes on next execution (no restart needed)
```

---

## 2. Automated Refresh with CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: refresh-workflow-cache
  namespace: argo
spec:
  schedule: "0 2 * * *"  # Daily at 2am
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: cache-updater
          containers:
            - name: updater
              image: alpine/k8s:latest
              command:
                - sh
                - -c
                - |\
                  #!/bin/sh
                  set -euo pipefail

                  # Generate fresh cache data from source (API, database, etc.)
                  curl -s https://api.example.com/repo-mappings > /tmp/mappings.json

                  # Update ConfigMap
                  kubectl create configmap workflow-cache \
                    --from-file=mappings.json=/tmp/mappings.json \
                    --dry-run=client -o yaml | kubectl apply -f -

                  echo "Cache refreshed at $(date)"
          restartPolicy: OnFailure
```

**RBAC for cache updater**:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cache-updater
  namespace: argo
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: configmap-updater
  namespace: argo
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["workflow-cache"]
    verbs: ["get", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cache-updater-binding
  namespace: argo
subjects:
  - kind: ServiceAccount
    name: cache-updater
    namespace: argo
roleRef:
  kind: Role
  name: configmap-updater
  apiGroup: rbac.authorization.k8s.io
```

---

## 3. Event-Driven Refresh

Trigger cache refresh on source data change:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: refresh-cache-on-change
spec:
  entrypoint: refresh
  templates:
    - name: refresh
      steps:
        - - name: detect-changes
            template: check-source
        - - name: update-cache
            template: update-configmap
            when: "{{steps.detect-changes.outputs.result}} == changed"

    - name: check-source
      script:
        image: alpine:latest
        command: [sh]
        source: |\
          # Check if source data changed
          # Output \"changed\" or \"unchanged\"

    - name: update-configmap
      script:
        image: alpine/k8s:latest
        command: [sh]
        source: |\
          # Fetch fresh data and update ConfigMap
```

---

## Related Patterns

- [ConfigMap Cache Pattern](configmap-cache.md) - Main overview
- [Implementation](implementation.md) - How to create and mount ConfigMaps
- [Use Cases](use-cases.md) - Real-world examples and troubleshooting

---

*Manual for infrequent changes. Automated CronJob for regular refresh. Event-driven for source changes. Pick the pattern that matches your update frequency. Cache stays fresh. Workflows stay fast.*
