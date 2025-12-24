---
title: ConfigMap Cache Implementation
description: >-
  Implementation guide for ConfigMap volume mount pattern: creating ConfigMaps with cache data, mounting in workflows, and script patterns for reading data.
tags:
  - kubernetes
  - configmap
  - implementation
  - argo-workflows
  - operators
---

# ConfigMap Cache Implementation

Complete implementation guide for ConfigMap volume mount pattern. Creating ConfigMaps, mounting volumes, and reading cached data in scripts.

!!! tip "Three Steps"
    Create ConfigMap with data. Mount as volume. Read from file. Zero API calls.

---

## 1. Create ConfigMap with Cache Data

**JSON format** (recommended for structured data):

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: workflow-cache
  namespace: argo
data:
  mappings.json: |\
    {
      "repo-to-namespace": {
        "adaptive-enforcement-lab/readability": "tools",
        "adaptive-enforcement-lab/scorecard-utils": "security",
        "adaptive-enforcement-lab/kustomize-build": "platform"
      },
      "artifact-paths": {
        "readability": "/artifacts/tools/readability",
        "scorecard-utils": "/artifacts/security/scorecard"
      }
    }
```

**Flat file format** (for simple key-value pairs):

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: workflow-cache
  namespace: argo
data:
  repo-namespace.txt: |\
    adaptive-enforcement-lab/readability=tools
    adaptive-enforcement-lab/scorecard-utils=security
    adaptive-enforcement-lab/kustomize-build=platform
```

---

## 2. Mount ConfigMap as Volume in Workflow

**Argo Workflows example**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: deployment-workflow
  namespace: argo
spec:
  templates:
    - name: deploy
      inputs:
        parameters:
          - name: repo
      script:
        image: alpine:latest
        command: [sh]
        source: |\
          #!/bin/sh
          set -euo pipefail

          # Read from mounted ConfigMap (no API call!)
          NAMESPACE=$(jq -r --arg repo "{{inputs.parameters.repo}}" \
            '.[\"repo-to-namespace\"][$repo]' /cache/mappings.json)

          ARTIFACT_PATH=$(jq -r --arg repo "{{inputs.parameters.repo}}" \
            '.[\"artifact-paths\"][$repo] // \"/artifacts/default\"' /cache/mappings.json)

          echo "Deploying {{inputs.parameters.repo}} to namespace: $NAMESPACE"
          echo "Artifact path: $ARTIFACT_PATH"

          # Deployment logic here
        volumeMounts:
          - name: cache-volume
            mountPath: /cache
            readOnly: true

  volumes:
    - name: cache-volume
      configMap:
        name: workflow-cache
```

**Kubernetes Job example**:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processor
  namespace: default
spec:
  template:
    spec:
      containers:
        - name: processor
          image: alpine:latest
          command:
            - sh
            - -c
            - |\
              #!/bin/sh
              set -euo pipefail

              # Read lookup data from mounted ConfigMap
              CATEGORY=$(grep "^${INPUT_ID}=" /data/categories.txt | cut -d'=' -f2)
              echo "Processing input $INPUT_ID in category: $CATEGORY"

              # Processing logic
          env:
            - name: INPUT_ID
              value: "12345"
          volumeMounts:
            - name: cache-data
              mountPath: /data
              readOnly: true
      volumes:
        - name: cache-data
          configMap:
            name: workflow-cache
      restartPolicy: Never
```

---

## 3. Script Patterns for Reading Mounted Data

**JSON with jq**:

```bash
#!/bin/bash
set -euo pipefail

REPO="$1"

# Lookup namespace (returns null if not found)
NAMESPACE=$(jq -r --arg repo "$REPO" '.[\"repo-to-namespace\"][$repo] // \"default\"' /cache/mappings.json)

# Lookup artifact path with fallback
ARTIFACT_PATH=$(jq -r --arg repo "$REPO" '.[\"artifact-paths\"][$repo] // \"/artifacts/default\"' /cache/mappings.json)

echo "Repo: $REPO → Namespace: $NAMESPACE, Path: $ARTIFACT_PATH"
```

**Flat file with grep**:

```bash
#!/bin/bash
set -euo pipefail

REPO="$1"

# Lookup value in flat file
NAMESPACE=$(grep "^${REPO}=" /cache/repo-namespace.txt | cut -d'=' -f2 || echo "default")

echo "Repo: $REPO → Namespace: $NAMESPACE"
```

**YAML with yq**:

```bash
#!/bin/bash
set -euo pipefail

REPO="$1"

# Lookup in YAML file
NAMESPACE=$(yq eval ".repos.\\\"$REPO\\\".namespace // \\\"default\\\"" /cache/config.yaml)

echo "Repo: $REPO → Namespace: $NAMESPACE"
```

---

## Related Patterns

- [ConfigMap Cache Pattern](configmap-cache.md) - Main overview
- [Refresh Strategies](refresh-strategies.md) - How to update cache data
- [Use Cases](use-cases.md) - Real-world examples and troubleshooting

---

*Three steps. Create ConfigMap. Mount volume. Read file. Zero API calls. Sub-millisecond lookups. Simple implementation. Massive performance win.*
