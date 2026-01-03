---
description: >-
  OPA Gatekeeper image signature verification. Require annotations proving cosign signature validation for supply chain security.
tags:
  - opa
  - gatekeeper
  - image-signing
  - cosign
  - kubernetes
  - templates
---

# OPA Image Verification Templates

Validates container images have been cryptographically verified. Enforces required annotations proving cosign signature validation occurred in CI/CD pipeline.

!!! warning "OPA Cannot Verify Signatures Directly"
    Unlike Kyverno, OPA/Gatekeeper cannot verify cosign signatures natively. This policy enforces that signature verification happened in your CI/CD pipeline by requiring specific annotations on workloads.

---

## Template 4: Image Signature Verification Annotations

Requires workloads to include annotations proving image signature verification. Ensures only cryptographically verified images reach production.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequireimageverification
spec:
  crd:
    spec:
      names:
        kind: K8sRequireImageVerification
      validation:
        openAPIV3Schema:
          properties:
            requiredAnnotations:
              type: array
              items:
                type: string
              description: "Annotations required to prove signature verification"
            exemptNamespaces:
              type: array
              items:
                type: string
              description: "Namespaces exempt from verification requirement"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequireimageverification

        violation[{"msg": msg, "details": {}}] {
          not exempt_namespace
          missing := get_missing_annotations
          count(missing) > 0
          msg := sprintf("Missing required image verification annotations: %v. Add these annotations to prove cosign verification occurred in CI/CD.",
            [missing])
        }

        violation[{"msg": msg, "details": {}}] {
          not exempt_namespace
          annotation := input.review.object.metadata.annotations["image.signature.verified"]
          annotation != "true"
          msg := "Annotation 'image.signature.verified' must be 'true'"
        }

        violation[{"msg": msg, "details": {}}] {
          not exempt_namespace
          image_digest := input.review.object.metadata.annotations["image.digest"]
          container := input_containers[_]
          not contains(container.image, image_digest)
          msg := sprintf("Container %v digest does not match verified digest in annotation: %v",
            [container.name, image_digest])
        }

        get_missing_annotations = missing {
          required := {annotation | annotation := input.parameters.requiredAnnotations[_]}
          present := {annotation | input.review.object.metadata.annotations[annotation]}
          missing := required - present
        }

        exempt_namespace {
          namespace := input.review.object.metadata.namespace
          exempt := input.parameters.exemptNamespaces[_]
          namespace == exempt
        }

        input_containers[c] {
          c := input.review.object.spec.containers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.initContainers[_]
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireImageVerification
metadata:
  name: require-image-verification
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
  parameters:
    requiredAnnotations:
      - "image.signature.verified"
      - "image.digest"
      - "image.signature.timestamp"
    exemptNamespaces:
      - "kube-system"
      - "kube-public"
      - "development"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `requiredAnnotations` | Verification metadata | Annotations proving signature verification |
| `exemptNamespaces` | System/dev namespaces | Namespaces exempt from verification |
| `enforcementAction` | `deny` | Use `dryrun` for gradual rollout |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-image-verification.yaml

# Verify installation
kubectl get constrainttemplates k8srequireimageverification
kubectl get k8srequireimageverification

# Test without verification annotations (should fail)
kubectl run test --image=nginx@sha256:abc123...

# Test with verification annotations (should pass)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: verified-app
  annotations:
    image.signature.verified: "true"
    image.digest: "sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603"
    image.signature.timestamp: "2024-01-15T10:30:00Z"
spec:
  containers:
    - name: nginx
      image: nginx@sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603
EOF

# Check violations
kubectl get k8srequireimageverification require-image-verification -o yaml

# Audit pods missing verification annotations
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.metadata.annotations["image.signature.verified"] != "true") |
  "\(.metadata.namespace)/\(.metadata.name)"
'
```

### Use Cases

1. **Supply Chain Security**: Ensure images passed cosign verification in CI/CD
2. **SLSA Compliance**: Enforce SLSA Level 3 provenance attestations
3. **Policy Bridge**: Use OPA for other policies, verify signatures upstream
4. **Audit Trail**: Annotations provide verification timestamp and metadata
5. **Regulatory Compliance**: Prove cryptographic verification for SOC2/FedRAMP

---

## CI/CD Integration

Add verification annotations in your build pipeline after cosign verification succeeds.

### GitHub Actions Example

```yaml
name: Build, Sign, and Deploy
on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: sigstore/cosign-installer@v3

      - name: Build and sign image
        run: |
          docker build -t ghcr.io/${{ github.repository }}/app:${{ github.sha }} .
          docker push ghcr.io/${{ github.repository }}/app:${{ github.sha }}
          cosign sign --yes ghcr.io/${{ github.repository }}/app:${{ github.sha }}

      - name: Deploy with verification annotations
        run: |
          IMAGE_DIGEST=$(crane digest ghcr.io/${{ github.repository }}/app:${{ github.sha }})
          kubectl apply -f - <<EOF
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: web
            annotations:
              image.signature.verified: "true"
              image.digest: "${IMAGE_DIGEST}"
              image.signature.timestamp: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          spec:
            template:
              spec:
                containers:
                  - name: app
                    image: ghcr.io/${{ github.repository }}/app@${IMAGE_DIGEST}
          EOF
```

---

## Comparison with Kyverno

### OPA Approach (Annotation-Based)

**Advantages**: Works with any CI/CD system, verification in trusted pipeline, flexible annotation schema, lower runtime overhead.

**Disadvantages**: Verification not at admission time, requires CI/CD integration, trust boundary is pipeline not cluster, manual annotation management.

### Kyverno Approach (Native Verification)

**Advantages**: Verification at admission time, no CI/CD changes required, cluster is trust boundary, automatic signature validation.

**Disadvantages**: Webhook timeout risk, network dependency on Rekor, higher resource usage, less flexible for custom workflows.

---

## Security Considerations

### Preventing Annotation Spoofing

Use RBAC to restrict who can set verification annotations:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: image-verification-annotator
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["create", "update"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ci-can-verify-images
subjects:
  - kind: ServiceAccount
    name: github-actions
    namespace: ci-cd
roleRef:
  kind: ClusterRole
  name: image-verification-annotator
  apiGroup: rbac.authorization.k8s.io
```

### Audit Verification Claims

Periodically verify annotations match actual signatures:

```bash
# Verify annotations match actual signatures
for pod in $(kubectl get pods -A -o json | jq -r '.items[].metadata.name'); do
  DIGEST=$(kubectl get pod $pod -o json | jq -r '.metadata.annotations["image.digest"]')
  IMAGE=$(kubectl get pod $pod -o json | jq -r '.spec.containers[0].image')

  # Verify signature matches digest
  cosign verify --key cosign.pub ${IMAGE}
done
```

---

## Related Resources

- **[OPA Image Security Templates →](security.md)** - Registry allowlists and tag validation
- **[OPA Image Digest Templates →](digest.md)** - SHA256 digest enforcement
- **[OPA Base Image Templates →](base.md)** - Approved base image enforcement
- **[Kyverno Image Signing Templates →](../../kyverno/image/signing.md)** - Native cosign verification alternative
- **[Decision Guide →](../../decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page

---

## External Documentation

- **[Sigstore Cosign](https://docs.sigstore.dev/cosign/overview/)** - Container signing
- **[SLSA Framework](https://slsa.dev/)** - Supply chain security levels
- **[OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/)** - Policy engine
- **[Rekor](https://docs.sigstore.dev/rekor/overview/)** - Transparency log
