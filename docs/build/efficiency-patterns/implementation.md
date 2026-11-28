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
provenance: human
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

## 4. Go Client: Mount First, API Fallback

A Go CLI can read the same cache with a three-tier fallback: volume mount, then the
ConfigMap API, then a rebuild from a cluster scan.

**Cache file** (`/etc/cache/cache.json`, mapping images to the deployments that use them):

```json
{
  "images": {
    "us-docker.pkg.dev/project/repo/app:v1.2.3": [
      {"name": "api", "namespace": "production"},
      {"name": "api", "namespace": "staging"}
    ],
    "us-docker.pkg.dev/project/repo/worker:v2.0.1": [
      {"name": "worker", "namespace": "production"}
    ]
  }
}
```

**Read from the mount**:

```go
func readCache(mountPath string) (*Cache, error) {
    data, err := os.ReadFile(filepath.Join(mountPath, "cache.json"))
    if err != nil {
        return nil, fmt.Errorf("reading cache file: %w", err)
    }

    var cache Cache
    if err := json.Unmarshal(data, &cache); err != nil {
        return nil, fmt.Errorf("parsing cache: %w", err)
    }

    return &cache, nil
}
```

**Fall back to the API, then rebuild**:

```go
func GetDeployments(image string, cachePath string, client kubernetes.Interface) ([]Deployment, error) {
    // Try volume mount first
    if cache, err := readCache(cachePath); err == nil {
        if deployments, found := cache.Images[image]; found {
            return deployments, nil
        }
        // Image not in cache, trigger rebuild
        return rebuildCache(client)
    }

    // Fallback to API
    cache, err := getConfigMapCache(client)
    if err != nil {
        // Cache doesn't exist, rebuild from cluster scan
        return rebuildCache(client)
    }

    if deployments, found := cache.Images[image]; found {
        return deployments, nil
    }

    // Image not tracked, rebuild cache
    return rebuildCache(client)
}
```

**Write through the API** (the mount is read-only; the kubelet syncs the change to every
mount, typically within seconds):

```go
func updateCache(client kubernetes.Interface, cache *Cache) error {
    data, err := json.MarshalIndent(cache, "", "  ")
    if err != nil {
        return fmt.Errorf("marshaling cache: %w", err)
    }

    cm := &corev1.ConfigMap{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "deployment-image-cache",
            Namespace: "automation",
        },
        Data: map[string]string{
            "cache.json": string(data),
        },
    }

    _, err = client.CoreV1().ConfigMaps("automation").Update(
        context.Background(), cm, metav1.UpdateOptions{},
    )
    return err
}
```

**RBAC** for readers in other namespaces:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cache-reader
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get"]
    resourceNames: ["deployment-image-cache"]
```

---

## Related Patterns

- [ConfigMap Cache Pattern](configmap-cache.md) - Main overview
- [Refresh Strategies](refresh-strategies.md) - How to update cache data
- [Use Cases](use-cases.md) - Real-world examples and troubleshooting

---

*Three steps. Create ConfigMap. Mount volume. Read file. Zero API calls. Sub-millisecond lookups. Simple implementation. Massive performance win.*
