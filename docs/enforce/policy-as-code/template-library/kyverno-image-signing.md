---
description: >-
  Kyverno image signature verification using Sigstore cosign. Verify container image signatures and attestations before deployment for supply chain security.
tags:
  - kyverno
  - image-signing
  - cosign
  - sigstore
  - kubernetes
  - templates
---

# Kyverno Image Signature Verification

Verifies container image signatures using Sigstore cosign before allowing deployment. Ensures only cryptographically signed images from trusted sources reach production.

!!! warning "Signature Verification Requires Digest References"
    Image signature verification only works with digest-based image references (`image@sha256:...`). Tags are mutable and cannot be reliably verified. Combine with digest requirement policies.

---

## Template 3: Cosign Image Signature Verification

Verifies container images are signed using Sigstore cosign. Blocks unsigned images and validates signatures against public keys or keyless (OIDC) signing.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: false  # Signature verification only works on admission
  webhookTimeoutSeconds: 30
  failurePolicy: Fail
  rules:
    - name: verify-cosign-signature
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
      verifyImages:
        - imageReferences:
            - "registry.example.com/*"
            - "ghcr.io/myorg/*"
          attestors:
            - count: 1
              entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE8xVwU5R3...
                      -----END PUBLIC KEY-----
          attestations:
            - predicateType: https://cosign.sigstore.dev/attestation/v1
              conditions:
                - all:
                    - key: "{{ attestation.predicate.buildType }}"
                      operator: Equals
                      value: "https://github.com/slsa-framework/slsa-github-generator"
    - name: verify-keyless-signature
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
      verifyImages:
        - imageReferences:
            - "ghcr.io/sigstore/*"
          attestors:
            - count: 1
              entries:
                - keyless:
                    subject: "https://github.com/{{ORG}}/*"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
          attestations:
            - predicateType: https://slsa.dev/provenance/v0.2
              conditions:
                - all:
                    - key: "{{ attestation.predicate.builder.id }}"
                      operator: Equals
                      value: "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `validationFailureAction` | `enforce` | Block unsigned images |
| `webhookTimeoutSeconds` | `30` | Timeout for signature verification |
| `failurePolicy` | `Fail` | Block on verification errors |
| `imageReferences` | Registry patterns | Images requiring signatures |
| `publicKeys` | PEM format | Cosign public keys for verification |
| `keyless.subject` | OIDC identity | Required identity for keyless signing |
| `keyless.issuer` | OIDC provider | Trusted identity provider |
| `attestation.predicateType` | SLSA/in-toto | Required attestation format |

### Validation Commands

```bash
# Apply policy
kubectl apply -f image-signature-policy.yaml

# Sign an image with cosign (key-based)
cosign generate-key-pair
cosign sign --key cosign.key registry.example.com/app:v1.2.3

# Sign an image with cosign (keyless)
cosign sign registry.example.com/app:v1.2.3

# Verify signature locally
cosign verify --key cosign.pub registry.example.com/app:v1.2.3

# Generate SLSA provenance attestation
cosign attest --predicate provenance.json --key cosign.key registry.example.com/app:v1.2.3

# Test unsigned image (should fail)
kubectl run test --image=registry.example.com/unsigned:latest

# Test signed image (should pass)
kubectl run test --image=registry.example.com/signed@sha256:abc123...

# Check signature verification logs
kubectl logs -n kyverno deployment/kyverno | grep "image verification"
```

### Use Cases

1. **Supply Chain Security**: Ensure images come from verified build pipelines
2. **SLSA Compliance**: Enforce SLSA Level 3 provenance attestations
3. **Insider Threat Prevention**: Block unauthorized image pushes to production registries
4. **Regulatory Compliance**: Meet SOC2/FedRAMP requirements for code signing
5. **Build Provenance**: Verify images were built by approved GitHub Actions workflows

### Setting Up Cosign Signing

Generate signing keys and configure GitHub Actions:

```bash
# Generate cosign key pair
cosign generate-key-pair

# Store private key in GitHub Secrets
gh secret set COSIGN_PRIVATE_KEY < cosign.key
gh secret set COSIGN_PASSWORD

# Extract public key for Kyverno policy
cat cosign.pub
```

Example GitHub Actions workflow with cosign signing:

```yaml
name: Build and Sign Container

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
    steps:
      - uses: actions/checkout@v4

      - name: Install cosign
        uses: sigstore/cosign-installer@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build image
        run: |
          docker build -t ghcr.io/${{ github.repository }}/app:${{ github.sha }} .
          docker push ghcr.io/${{ github.repository }}/app:${{ github.sha }}

      - name: Sign image (keyless)
        run: |
          cosign sign --yes ghcr.io/${{ github.repository }}/app:${{ github.sha }}

      - name: Generate SLSA provenance
        uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v1.9.0
        with:
          image: ghcr.io/${{ github.repository }}/app
          digest: ${{ github.sha }}
```

### Keyless vs Key-Based Signing

**Keyless Signing (Recommended)**:

- Uses OIDC identity from GitHub Actions, GitLab CI, etc.
- No key management required
- Signatures stored in Rekor transparency log
- Ephemeral keys generated per-build
- Best for cloud-native CI/CD pipelines

**Key-Based Signing**:

- Traditional PKI with long-lived keys
- Requires secure key storage (KMS, Vault, HSM)
- Better for air-gapped environments
- Requires key rotation policies
- Best for on-premise or regulated environments

### Verifying Multiple Attestation Types

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-multiple-attestations
spec:
  validationFailureAction: enforce
  background: false
  rules:
    - name: require-slsa-and-spdx
      match:
        resources:
          kinds:
            - Pod
      verifyImages:
        - imageReferences:
            - "registry.example.com/prod/*"
          attestors:
            - count: 1
              entries:
                - keys:
                    publicKeys: "{{ configmap.kyverno.data.cosign-pub }}"
          attestations:
            # Require SLSA provenance
            - predicateType: https://slsa.dev/provenance/v0.2
              conditions:
                - all:
                    - key: "{{ attestation.predicate.buildType }}"
                      operator: Equals
                      value: "https://github.com/slsa-framework/slsa-github-generator"
            # Require SBOM
            - predicateType: https://spdx.dev/Document
              conditions:
                - all:
                    - key: "{{ attestation.predicate.spdxVersion }}"
                      operator: Equals
                      value: "SPDX-2.3"
            # Require vulnerability scan
            - predicateType: https://cosign.sigstore.dev/attestation/vuln/v1
              conditions:
                - all:
                    - key: "{{ attestation.predicate.scanner.name }}"
                      operator: Equals
                      value: "trivy"
                    - key: "{{ attestation.predicate.metadata.scanFinishedOn }}"
                      operator: GreaterThan
                      value: "{{ time_now_utc() - '24h' }}"
```

---

## Troubleshooting

### Signature Verification Failures

**Error**: `failed to verify signature: no matching signatures`

```bash
# Check image has signature
cosign verify --key cosign.pub registry.example.com/app@sha256:abc123

# Verify public key in policy matches signing key
kubectl get clusterpolicy verify-image-signature -o yaml | grep "BEGIN PUBLIC KEY"

# Check Rekor transparency log for keyless signatures
rekor-cli search --sha sha256:abc123
```

**Error**: `webhookTimeoutSeconds exceeded`

```bash
# Increase timeout in policy
kubectl patch clusterpolicy verify-image-signature --type=merge -p '
spec:
  webhookTimeoutSeconds: 60
'

# Check network connectivity to Rekor
kubectl exec -n kyverno deployment/kyverno -- curl -I https://rekor.sigstore.dev
```

**Error**: `image reference must be by digest`

```bash
# Convert tag to digest
IMAGE_DIGEST=$(crane digest registry.example.com/app:v1.2.3)
kubectl set image deployment/web app=registry.example.com/app@${IMAGE_DIGEST}
```

---

## Related Resources

- **[Kyverno Image Validation →](kyverno-image-validation.md)** - Digest requirements and registry allowlists
- **[Kyverno Image Security →](kyverno-image-security.md)** - Base image enforcement and CVE gates
- **[Kyverno Pod Security →](kyverno-pod-security.md)** - Security contexts and capabilities
- **[Template Library Overview →](index.md)** - Back to main page

---

## External Documentation

- **[Sigstore Cosign](https://docs.sigstore.dev/cosign/overview/)** - Official cosign documentation
- **[SLSA Framework](https://slsa.dev/)** - Supply chain security levels
- **[Kyverno Image Verification](https://kyverno.io/docs/writing-policies/verify-images/)** - Kyverno-specific guidance
- **[Rekor Transparency Log](https://docs.sigstore.dev/rekor/overview/)** - Public signature transparency
