# Helm Charts

Deploy your CLI with Helm for Kubernetes environments.

---

## Chart Structure

```text
charts/myctl/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   ├── serviceaccount.yaml
│   ├── role.yaml
│   └── rolebinding.yaml
└── .helmignore
```

---

## Chart.yaml

```yaml
apiVersion: v2
name: myctl
description: Kubernetes orchestration CLI
type: application
version: 0.1.0
appVersion: "1.0.0"
```

---

## values.yaml

```yaml
image:
  repository: ghcr.io/myorg/myctl
  tag: ""  # Defaults to appVersion
  pullPolicy: IfNotPresent

serviceAccount:
  create: true
  name: ""  # Generated if not specified

rbac:
  create: true
  clusterWide: false  # Use Role vs ClusterRole

namespace: default

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

config:
  cacheTTL: 300
  verbose: false
```

---

## Deployment Template

Use `Job` resources for one-shot CLI operations:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "myctl.fullname" . }}
  labels:
    {{- include "myctl.labels" . | nindent 4 }}
spec:
  template:
    spec:
      serviceAccountName: {{ include "myctl.serviceAccountName" . }}
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
        fsGroup: 65532
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          args:
            - orchestrate
            - --namespace={{ .Values.namespace }}
            {{- if .Values.config.verbose }}
            - --verbose
            {{- end }}
          securityContext:
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
  backoffLimit: 3
```

---

## ServiceAccount Template

```yaml
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "myctl.serviceAccountName" . }}
  labels:
    {{- include "myctl.labels" . | nindent 4 }}
{{- end }}
```

---

## RBAC Templates

### Role (namespace-scoped)

```yaml
{{- if .Values.rbac.create -}}
{{- if not .Values.rbac.clusterWide }}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "myctl.fullname" . }}
  labels:
    {{- include "myctl.labels" . | nindent 4 }}
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "patch"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "create", "update", "patch"]
{{- end }}
{{- end }}
```

### RoleBinding

```yaml
{{- if .Values.rbac.create -}}
{{- if not .Values.rbac.clusterWide }}
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "myctl.fullname" . }}
  labels:
    {{- include "myctl.labels" . | nindent 4 }}
subjects:
  - kind: ServiceAccount
    name: {{ include "myctl.serviceAccountName" . }}
    namespace: {{ .Release.Namespace }}
roleRef:
  kind: Role
  name: {{ include "myctl.fullname" . }}
  apiGroup: rbac.authorization.k8s.io
{{- end }}
{{- end }}
```

---

## Installation

```bash
# Install from local chart
helm install myctl ./charts/myctl -n myctl-system --create-namespace

# Install with custom values
helm install myctl ./charts/myctl \
  --set namespace=production \
  --set config.verbose=true

# Upgrade
helm upgrade myctl ./charts/myctl --reuse-values
```

---

*Helm charts make your CLI deployable with standard Kubernetes tooling.*
