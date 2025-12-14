# Volume Patterns

Volumes connect workflows to persistent storage, configuration, and secrets. Understanding when to use each volume type prevents both data loss and security issues.

---

## Why Volume Choice Matters

A workflow that writes output to the container filesystem loses that data when the pod terminates. A workflow that stores credentials in environment variables exposes them in logs. A workflow that reads configuration from a hardcoded path can't be reused across environments.

Volumes solve these problems, but different volume types have different characteristics. Using the wrong type causes subtle issues: data disappearing unexpectedly, secrets visible to unauthorized processes, configuration changes requiring workflow updates.

---

## Volume Types

```yaml
spec:
  volumes:
    # Persistent storage - survives workflow completion
    - name: data-pvc
      persistentVolumeClaim:
        claimName: workflow-data

    # Temporary workspace - fast, local, deleted when pod terminates
    - name: workspace
      emptyDir: {}

    # Configuration from ConfigMap - read-only settings
    - name: config
      configMap:
        name: workflow-config
        optional: true

    # Secrets - credentials, keys, certificates
    - name: credentials
      secret:
        secretName: git-credentials
```

**Choosing the right volume type:**

| Volume Type | Survives Pod Restart | Survives Workflow Completion | Use Case |
| ------------- | --------------------- | ------------------------------ | ---------- |
| `emptyDir` | No | No | Scratch space, inter-container communication |
| `configMap` | N/A (read-only) | N/A | Configuration files, cache data |
| `secret` | N/A (read-only) | N/A | Credentials, certificates |
| `persistentVolumeClaim` | Yes | Yes | Build artifacts, collected data |

---

## EmptyDir for Scratch Space

EmptyDir volumes provide temporary storage that multiple containers can share. The data exists only while the pod runs. When the pod terminates, the data is gone.

```yaml
spec:
  volumes:
    - name: workspace
      emptyDir: {}
    - name: cache
      emptyDir:
        medium: Memory  # Use RAM for speed
        sizeLimit: 256Mi

  templates:
    - name: processor
      container:
        image: processor:latest
        volumeMounts:
          - name: workspace
            mountPath: /tmp/work
          - name: cache
            mountPath: /cache
```

The `medium: Memory` option creates a tmpfs mount backed by RAM. Reads and writes are fast, but the data counts against the container's memory limit. Use this for caches where speed matters more than persistence.

---

## ConfigMap for Configuration

ConfigMaps store configuration data as key-value pairs or files. Workflows mount them read-only to access settings without hardcoding values.

```yaml
spec:
  volumes:
    - name: config
      configMap:
        name: workflow-config
        optional: true

  templates:
    - name: processor
      container:
        image: processor:latest
        volumeMounts:
          - name: config
            mountPath: /etc/config
            readOnly: true
```

The `optional: true` flag prevents workflow failures when the ConfigMap doesn't exist. This is useful for caches that might not be populated yet. The workflow can handle the missing data gracefully instead of failing immediately.

**ConfigMap as cache pattern:**

ConfigMaps can store precomputed data that workflows read instead of computing on demand. For example, a deployment-to-image mapping that would require cluster scanning:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: deployment-image-cache
data:
  cache.json: |
    {
      "registry/app:v1.0": ["default/app-deployment"],
      "registry/worker:v2.0": ["jobs/worker-deployment"]
    }
```

Reading this file takes milliseconds. Scanning the cluster for the same information takes seconds and hammers the API server.

---

## Secrets for Credentials

Secrets store sensitive data: passwords, API keys, and certificates. They work like ConfigMaps but with additional protections. They're not logged, stored in etcd with encryption, and can be restricted via RBAC.

```yaml
spec:
  volumes:
    - name: credentials
      secret:
        secretName: git-credentials
        defaultMode: 0400  # Read-only for owner

  templates:
    - name: git-clone
      container:
        image: alpine/git
        volumeMounts:
          - name: credentials
            mountPath: /secrets
            readOnly: true
        env:
          - name: GIT_SSH_COMMAND
            value: "ssh -i /secrets/id_rsa -o StrictHostKeyChecking=no"
```

**Always mount secrets read-only.** There's no legitimate reason for a workflow to modify its credentials at runtime.

---

## PersistentVolumeClaim for Durability

PVCs provide storage that survives pod and workflow termination. Use them when output must persist beyond the workflow's lifetime.

```yaml
spec:
  volumes:
    - name: data-pvc
      persistentVolumeClaim:
        claimName: workflow-data

  templates:
    - name: collector
      container:
        image: collector:latest
        volumeMounts:
          - name: data-pvc
            mountPath: /data
```

PVCs have access mode constraints:

| Access Mode | Description | Use Case |
| ------------- | ------------- | ---------- |
| `ReadWriteOnce` | Single pod read/write | Most workflows |
| `ReadOnlyMany` | Multiple pods read | Shared reference data |
| `ReadWriteMany` | Multiple pods read/write | Parallel processing |

Most cloud providers only support `ReadWriteOnce` for standard storage. If you need shared access, use a storage class that supports it or use external storage like GCS/S3 instead.

---

## Mount Permissions

Control access patterns with mount options:

```yaml
volumeMounts:
  - name: data-pvc
    mountPath: /data
  - name: workspace
    mountPath: /tmp/work
  - name: config
    mountPath: /etc/config
    readOnly: true          # ConfigMaps should be read-only
  - name: credentials
    mountPath: /secrets
    readOnly: true          # Secrets must be read-only
```

**Always mount secrets and ConfigMaps as read-only.** Workflows should never modify their configuration at runtime. Doing so creates state that's invisible to version control and impossible to reproduce.

---

## SubPath for Selective Mounting

Mount specific files from a ConfigMap or Secret instead of the entire volume:

```yaml
volumeMounts:
  - name: github-credentials
    mountPath: /home/app/.ssh/id_rsa
    subPath: private-key
    readOnly: true
```

This mounts only the `private-key` key from the secret, not all keys. The file appears at the specified path rather than in a directory.

Use subPath when:

- You need files at specific paths (not in a directory)
- You only need some keys from a multi-key secret
- You're mounting into an existing directory without overwriting it

---

!!! warning "PVC Access Modes"
    ReadWriteOnce PVCs can only be mounted by pods on the same node. For parallel steps that need shared storage, use ReadWriteMany or pass data through artifacts instead.

---

## Related

- [Basic Structure](basic-structure.md) - WorkflowTemplate anatomy
- [Init Containers](init-containers.md) - Volume sharing between containers
- [RBAC Configuration](rbac.md) - Restricting volume access
