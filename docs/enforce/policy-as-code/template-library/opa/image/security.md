---
description: >-
  OPA Gatekeeper image security templates. Enforce registry allowlists and tag validation with complete Rego implementations.
tags:
  - opa
  - gatekeeper
  - image-security
  - kubernetes
  - templates
---

# OPA Image Security Templates

OPA/Gatekeeper constraint templates for container image security. Enforce registry allowlists, block `latest` tags, and validate image sources with production-tested Rego implementations.

!!! warning "Untrusted Registries = Supply Chain Risk"
    Container images from untrusted registries can introduce malware, backdoors, or vulnerable dependencies. These policies enforce supply chain security at admission time.

---

## Template 1: Registry Allowlist

Enforces approved registry sources for all container images. Blocks images from public registries and untrusted sources.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sallowedregistries
spec:
  crd:
    spec:
      names:
        kind: K8sAllowedRegistries
      validation:
        openAPIV3Schema:
          properties:
            registries:
              type: array
              items:
                type: string
              description: "Allowed container registry prefixes"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sallowedregistries

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          not registry_allowed(container.image)
          msg := sprintf("Container %v uses disallowed registry: %v. Allowed registries: %v",
            [container.name, container.image, input.parameters.registries])
        }

        registry_allowed(image) {
          registry := input.parameters.registries[_]
          startswith(image, registry)
        }

        input_containers[c] {
          c := input.review.object.spec.containers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.initContainers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.ephemeralContainers[_]
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRegistries
metadata:
  name: allowed-registries
spec:
  enforcementAction: deny  # Use 'dryrun' for testing
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
      - apiGroups: ["batch"]
        kinds: ["Job", "CronJob"]
    excludedNamespaces:
      - kube-system
      - kube-public
  parameters:
    registries:
      - "registry.example.com/"
      - "ghcr.io/myorg/"
      - "gcr.io/myproject/"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `registries` | Private registries | Allowed registry prefixes (must end with `/`) |
| `enforcementAction` | `deny` | Use `dryrun` for audit mode |
| `excludedNamespaces` | System namespaces | Exempt cluster infrastructure |

### Validation Commands

```bash
# Apply constraint template and constraint
kubectl apply -f opa-registry-allowlist.yaml

# Verify installation
kubectl get constrainttemplates k8sallowedregistries
kubectl get k8sallowedregistries

# Test with public Docker Hub image (should fail)
kubectl run test --image=nginx:latest

# Test with allowed registry (should pass)
kubectl run test --image=registry.example.com/apps/nginx:v1.21

# Check violations
kubectl get k8sallowedregistries allowed-registries -o yaml

# Audit existing violations
kubectl get pods -A -o json | jq -r '
  .items[] |
  .spec.containers[] |
  select(.image | startswith("registry.example.com/") | not) |
  .image
' | sort | uniq
```

### Use Cases

1. **Supply Chain Security**: Block untrusted registries with unknown provenance
2. **Cost Control**: Force use of internal registry mirrors to reduce egress costs
3. **Compliance Requirements**: Only use FedRAMP/SOC2 certified registries
4. **Air-gapped Environments**: Enforce local registry for disconnected clusters
5. **Image Scanning Integration**: Ensure all images pass vulnerability scanning in private registry

---

## Template 2: Tag Requirements

Blocks `latest` tags and untagged images. Enforces semantic versioning or specific tag patterns.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sblocklatestimages
spec:
  crd:
    spec:
      names:
        kind: K8sBlockLatestImages
      validation:
        openAPIV3Schema:
          properties:
            exemptImages:
              type: array
              items:
                type: string
              description: "Images exempt from tag validation"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblocklatestimages

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          not exempt_image(container.image)
          has_latest_tag(container.image)
          msg := sprintf("Container %v uses 'latest' tag which is not allowed: %v",
            [container.name, container.image])
        }

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          not exempt_image(container.image)
          not has_tag(container.image)
          not has_digest(container.image)
          msg := sprintf("Container %v must specify image tag or digest: %v",
            [container.name, container.image])
        }

        has_latest_tag(image) {
          endswith(image, ":latest")
        }

        has_tag(image) {
          contains(image, ":")
        }

        has_digest(image) {
          contains(image, "@sha256:")
        }

        exempt_image(image) {
          exempt := input.parameters.exemptImages[_]
          startswith(image, exempt)
        }

        input_containers[c] {
          c := input.review.object.spec.containers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.initContainers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.ephemeralContainers[_]
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockLatestImages
metadata:
  name: block-latest-tags
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
      - apiGroups: ["batch"]
        kinds: ["Job", "CronJob"]
    excludedNamespaces:
      - kube-system
  parameters:
    exemptImages: []
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `exemptImages` | `[]` | Images exempt from tag validation |
| `enforcementAction` | `deny` | Use `dryrun` for gradual rollout |
| `excludedNamespaces` | System namespaces | Exempt cluster components |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-tag-requirements.yaml

# Verify installation
kubectl get constrainttemplates k8sblocklatestimages
kubectl get k8sblocklatestimages

# Test with latest tag (should fail)
kubectl run test --image=nginx:latest

# Test with untagged image (should fail)
kubectl run test --image=nginx

# Test with specific tag (should pass)
kubectl run test --image=nginx:1.21.6

# Test with digest (should pass)
kubectl run test --image=nginx@sha256:abc123...

# Audit existing latest tags
kubectl get pods -A -o json | jq -r '
  .items[] |
  .spec.containers[] |
  select(.image | endswith(":latest")) |
  "\(.image)"
' | sort | uniq
```

### Use Cases

1. **Immutable Deployments**: Prevent silent updates when `:latest` tag changes
2. **Rollback Reliability**: Ensure specific versions for reliable rollbacks
3. **Change Control**: Require explicit version changes in deployment manifests
4. **Audit Trails**: Track exact image versions deployed for compliance
5. **Production Safety**: Prevent accidental `:latest` deployments in production

---

## Related Resources

- **[OPA Image Digest Templates →](digest.md)** - SHA256 digest enforcement
- **[OPA Image Verification Templates →](verification.md)** - Signature verification annotations
- **[OPA Base Image Templates →](base.md)** - Approved base image enforcement
- **[OPA Pod Security Templates →](../pod-security/overview.md)** - Privileged containers and host namespaces
- **[OPA RBAC Templates →](../rbac/overview.md)** - Service account and role restrictions
- **[Kyverno Image Validation Templates →](../../kyverno/image/validation.md)** - Kubernetes-native alternative
- **[Decision Guide →](../../decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
