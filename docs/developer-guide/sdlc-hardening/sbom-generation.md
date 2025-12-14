---
title: SBOM Generation
description: >-
  Software Bill of Materials for supply chain security. Catalog every dependency,
  verify licenses, and provide audit evidence of container contents.
---

# SBOM Generation

Auditors want to know what's in your containers. Not just what you say is in them -- what's actually there.

!!! warning "Security Foundation"
    These controls form the baseline security posture. All controls must be implemented for audit compliance.

SBOMs (Software Bill of Materials) provide the inventory.

---

## What is an SBOM?

Machine-readable catalog of all software components in an artifact:

- Application dependencies (npm, go modules, pip packages)
- Base image layers
- System libraries
- Licenses

Formats: CycloneDX (JSON/XML), SPDX (JSON/YAML).

---

## Why Auditors Care

Supply chain attacks target dependencies. SolarWinds, Log4Shell, event-stream npm package.

Auditors need proof you know what's in production:

- No GPL-licensed code in proprietary software
- No libraries with known HIGH/CRITICAL CVEs
- Dependencies match declared versions
- Supply chain visibility

SBOM provides the evidence.

---

## Generate SBOM in CI/CD

```yaml
# .github/workflows/build.yml
- name: Build container
  run: |
    buildah bud -t app:${{ github.sha }} .

- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    image: app:${{ github.sha }}
    format: cyclonedx-json
    output-file: sbom.json

- name: Upload SBOM
  uses: actions/upload-artifact@v4
  with:
    name: sbom-${{ github.sha }}
    path: sbom.json
    retention-days: 90
```

Every build generates SBOM. Artifact stored for 90 days (or longer for compliance).

---

## SBOM Tools

### Syft (Anchore)

```bash
# Generate SBOM for container image
syft gcr.io/project/app:v1.0.0 -o cyclonedx-json > sbom.json

# Generate for local directory
syft dir:. -o spdx-json > sbom.json
```

Supports multiple formats, integrates with Grype for vulnerability scanning.

### Trivy

```bash
# Generate SBOM
trivy image --format cyclonedx gcr.io/project/app:v1.0.0 > sbom.json

# Generate and scan
trivy image --scanners vuln gcr.io/project/app:v1.0.0
```

Combined SBOM generation and vulnerability scanning.

### Docker SBOM (experimental)

```bash
# Docker buildx SBOM generation
docker buildx build --sbom=true -t app:v1.0.0 .
docker buildx imagetools inspect app:v1.0.0 --format "{{ json .SBOM }}"
```

Native Docker support (experimental feature).

---

## CycloneDX Format

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "metadata": {
    "component": {
      "type": "container",
      "name": "app",
      "version": "1.0.0"
    }
  },
  "components": [
    {
      "type": "library",
      "name": "github.com/gin-gonic/gin",
      "version": "v1.9.1",
      "purl": "pkg:golang/github.com/gin-gonic/gin@v1.9.1",
      "licenses": [
        {"license": {"id": "MIT"}}
      ]
    }
  ]
}
```

Machine-readable. Tools can parse and validate.

---

## License Compliance

Verify no GPL in proprietary code:

```bash
# Extract licenses from SBOM
jq '.components[].licenses[].license.id' sbom.json | sort -u

# Check for GPL
jq '.components[] | select(.licenses[].license.id | contains("GPL"))' sbom.json
```

Fail build if GPL detected:

```yaml
- name: Check licenses
  run: |
    FORBIDDEN="GPL|AGPL|LGPL"
    if jq '.components[].licenses[].license.id' sbom.json | grep -E "$FORBIDDEN"; then
      echo "Forbidden license detected"
      exit 1
    fi
```

---

## Vulnerability Correlation

SBOM + CVE database = vulnerability report.

```bash
# Generate SBOM
syft gcr.io/project/app:v1.0.0 -o cyclonedx-json > sbom.json

# Scan SBOM for vulnerabilities
grype sbom:sbom.json --fail-on high
```

Blocks deployment if HIGH/CRITICAL vulnerabilities found.

See [Zero-Vulnerability Pipelines](../../blog/posts/2025-12-15-zero-vulnerability-pipelines.md) for full pattern.

---

## SBOM Storage

### Artifact Storage

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: sbom-${{ github.sha }}
    path: sbom.json
    retention-days: 365  # 1 year for compliance
```

### Cloud Storage

```yaml
- name: Upload to GCS
  run: |
    gsutil cp sbom.json gs://sbom-archive/app-${{ github.sha }}.json
```

### Container Registry

Attach SBOM as OCI artifact:

```bash
# Attach SBOM to image
oras attach gcr.io/project/app:v1.0.0 \
  --artifact-type application/vnd.cyclonedx \
  sbom.json
```

SBOM stored alongside image.

---

## SBOM Comparison

Track dependency changes between releases:

```bash
# Generate SBOM for v1.0.0
syft gcr.io/project/app:v1.0.0 -o json > sbom-1.0.0.json

# Generate SBOM for v1.1.0
syft gcr.io/project/app:v1.1.0 -o json > sbom-1.1.0.json

# Compare
diff <(jq -S '.artifacts[].name' sbom-1.0.0.json) \
     <(jq -S '.artifacts[].name' sbom-1.1.0.json)
```

Shows added, removed, and updated dependencies.

---

## Audit Evidence

Auditors ask: "Show me the SBOM for the container running in production on March 15, 2025."

Query:

```bash
# Get image digest from production
DIGEST=$(kubectl get deployment app -o jsonpath='{.spec.template.spec.containers[0].image}')

# Retrieve SBOM from storage
gsutil cp gs://sbom-archive/${DIGEST}.json sbom.json

# Verify contents
jq '.metadata.component, .components[] | {name, version}' sbom.json
```

Proves what was running at that time.

---

## NTIA Minimum Elements

US National Telecommunications and Information Administration (NTIA) defines minimum SBOM elements:

- Author name
- Timestamp
- Component name
- Version
- Unique identifier (PURL)
- Dependency relationships
- SBOM creator

Tools like Syft and Trivy generate compliant SBOMs.

---

## Integration with Signing

Sign SBOMs for integrity:

```bash
# Generate SBOM
syft gcr.io/project/app:v1.0.0 -o cyclonedx-json > sbom.json

# Sign with cosign
cosign sign-blob sbom.json --output-signature sbom.json.sig

# Verify
cosign verify-blob sbom.json --signature sbom.json.sig
```

Proves SBOM wasn't tampered with.

---

## Policy Enforcement

Kyverno can require SBOMs for deployed images:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-sbom
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-sbom-exists
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "Image must have attached SBOM"
        pattern:
          spec:
            containers:
              - image: "*"
                # Verify SBOM artifact exists
```

See [Policy-as-Code with Kyverno](../../blog/posts/2025-12-13-policy-as-code-kyverno.md) for runtime admission control.

---

## Related Patterns

- **[Zero-Vulnerability Pipelines](../../blog/posts/2025-12-15-zero-vulnerability-pipelines.md)** - SBOM + CVE scanning
- **[Policy-as-Code](../../blog/posts/2025-12-13-policy-as-code-kyverno.md)** - Runtime SBOM enforcement
- **[Required Status Checks](status-checks/index.md)** - SBOM generation as CI gate

---

*SBOMs were generated for every build. Licenses verified. Vulnerabilities correlated. Audit trail complete. Supply chain visible.*
