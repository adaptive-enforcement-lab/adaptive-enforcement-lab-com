---
description: >-
  Complete Go security toolkit reference: race detector, golangci-lint, Trivy, govulncheck,
  syft, TruffleHog. Free tools that run on every commit automatically.
---

# The Standard Toolkit

Go provides a complete security toolkit built into the standard toolchain. No separate installations or subscriptions required.

!!! note "Zero-Cost Security"
    All tools listed here are free and open source. They integrate with standard Go workflows (`go test`, `go build`) and run on every commit.

## Race Detector

**Purpose**: Detect data races (concurrent access to shared memory without synchronization)

**Command**:

```bash
go test -race ./...
```

**CI Integration**:

```yaml
- name: Run tests with race detection
  run: go test -race -v ./...
```

**Pre-commit Integration**:

```yaml
- id: go-test
  name: Run Go tests with race detector
  entry: gotestsum --format testdox -- -race ./...
  language: system
  files: '\.go$'
  pass_filenames: false
```

**What It Catches**:

- Concurrent map writes
- Unsynchronized shared variable access
- Channel race conditions
- Slice/array concurrent modification

**Performance Impact**: ~10x slower test execution, run on every commit in CI

---

## Static Analysis: golangci-lint

**Purpose**: Comprehensive linting suite with security-focused analyzers

**Installation**:

```bash
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

**Command**:

```bash
golangci-lint run
```

**Configuration** (`.golangci.yml`):

```yaml
linters:
  enable:
    - gosec        # Security-focused static analysis
    - govet        # Go vet integration
    - errcheck     # Check error handling
    - staticcheck  # Advanced static analysis
    - unused       # Find unused code
    - ineffassign  # Detect ineffectual assignments
    - gocyclo      # Cyclomatic complexity
    - gofmt        # Formatting check
    - goconst      # Find repeated strings

linters-settings:
  gosec:
    severity: medium
    confidence: medium
  gocyclo:
    min-complexity: 15
```

**Security Checks via gosec**:

- G101: Hardcoded credentials
- G102: Bind to all network interfaces
- G103: Unsafe pointer usage
- G104: Unhandled errors
- G201-204: SQL injection
- G301-307: File permissions
- G401-405: Weak cryptography
- G501-505: Insecure imports

**CI Integration**:

```yaml
- name: Lint
  run: golangci-lint run --timeout 5m
```

---

## Formatting: gofmt

**Purpose**: Enforce consistent code formatting (consistency reduces bugs)

**Command**:

```bash
gofmt -s -w .
```

**Flags**:

- `-s`: Simplify code
- `-w`: Write changes to files
- `-d`: Show diffs instead of rewriting

**Pre-commit Hook**:

```yaml
- id: gofmt
  name: Format Go code
  entry: gofmt -s -w
  language: system
  files: '\.go$'
```

**Why It Matters for Security**:

- Consistent formatting makes code review easier
- Simplified expressions reduce cognitive load
- Standardized structure highlights anomalies

---

## Vulnerability Scanning: Trivy

**Purpose**: Scan dependencies and container images for known vulnerabilities (CVEs)

**Installation**:

```bash
# Binary installation
wget https://github.com/aquasecurity/trivy/releases/download/v0.50.0/trivy_0.50.0_Linux-64bit.tar.gz
tar zxvf trivy_0.50.0_Linux-64bit.tar.gz
sudo mv trivy /usr/local/bin/
```

**Scan Go Dependencies**:

```bash
trivy fs --scanners vuln,secret,misconfig .
```

**CI Integration**:

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: '.'
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload to GitHub Security
  uses: github/codeql-action/upload-sarif@v4
  with:
    sarif_file: 'trivy-results.sarif'
    category: 'trivy'
```

**What It Scans**:

- Go module dependencies (`go.mod`)
- Known CVEs in dependencies
- Secrets in code (API keys, tokens)
- Misconfigurations

---

## Dependency Vulnerability Check: govulncheck

**Purpose**: Official Go vulnerability scanner from the Go team

**Installation**:

```bash
go install golang.org/x/vuln/cmd/govulncheck@latest
```

**Command**:

```bash
govulncheck ./...
```

**CI Integration**:

```yaml
- name: Run govulncheck
  run: |
    go install golang.org/x/vuln/cmd/govulncheck@latest
    govulncheck ./...
```

**Difference from Trivy**:

- **Trivy**: Scans `go.mod` for any vulnerable dependencies
- **govulncheck**: Only reports vulnerabilities in code you actually call
- **Use both**: Trivy catches everything, govulncheck reduces false positives

---

## SBOM Generation: syft

**Purpose**: Generate Software Bill of Materials for supply chain security

**Installation**:

```bash
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
```

**Generate SBOM**:

```bash
syft packages . -o cyclonedx-json > sbom.cdx.json
```

**CI Integration**:

```yaml
- name: Generate SBOM
  run: |
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
    syft packages . -o cyclonedx-json > sbom.cdx.json

- name: Upload SBOM artifact
  uses: actions/upload-artifact@v4
  with:
    name: sbom
    path: sbom.cdx.json
```

**Formats Supported**:

- CycloneDX JSON (recommended)
- CycloneDX XML
- SPDX JSON
- SPDX Tag-Value

---

## Secret Scanning: TruffleHog

**Purpose**: Detect leaked credentials in code and commit history

**Installation**:

```bash
# Via OCI container (recommended)
podman pull trufflesecurity/trufflehog:latest

# Via binary
wget https://github.com/trufflesecurity/trufflehog/releases/download/v3.68.0/trufflehog_3.68.0_linux_amd64.tar.gz
tar -xzf trufflehog_3.68.0_linux_amd64.tar.gz
sudo mv trufflehog /usr/local/bin/
```

**Scan Repository**:

```bash
trufflehog git file://. --only-verified
```

**CI Integration**:

```yaml
- name: TruffleHog secret scan
  uses: trufflesecurity/trufflehog@main
  with:
    extra_args: --only-verified
```

**What It Finds**:

- AWS credentials
- GitHub tokens
- API keys
- Private keys
- Database credentials
- OAuth tokens
