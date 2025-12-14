# Integrated Workflow

Security tools only work if they run automatically. Pre-commit hooks catch issues before commit. CI pipelines enforce checks before merge.

!!! tip "Automated Enforcement"
    Configure hooks once. Security runs on every commit with zero friction. Developers can't bypass the checks.

## Pre-commit Hooks (`.pre-commit-config.yaml`)

```yaml
repos:
  - repo: local
    hooks:
      - id: gofmt
        name: Format Go code
        entry: gofmt -s -w
        language: system
        files: '\.go$'

      - id: go-vet
        name: Go vet
        entry: go vet ./...
        language: system
        files: '\.go$'
        pass_filenames: false

      - id: golangci-lint
        name: golangci-lint
        entry: golangci-lint run
        language: system
        files: '\.go$'
        pass_filenames: false

      - id: gocyclo
        name: Check cyclomatic complexity
        entry: >
          bash -c '
          command -v gocyclo >/dev/null || go install github.com/fzipp/gocyclo/cmd/gocyclo@latest;
          gocyclo -over 15 .
          '
        language: system
        files: '\.go$'
        pass_filenames: false

      - id: go-test
        name: Run Go tests
        entry: >
          bash -c '
          command -v gotestsum >/dev/null || go install gotest.tools/gotestsum@latest;
          gotestsum --format testdox -- -race ./...
          '
        language: system
        files: '\.go$'
        pass_filenames: false

      - id: go-coverage
        name: Check test coverage threshold
        entry: >
          bash -c '
          command -v gotestsum >/dev/null || go install gotest.tools/gotestsum@latest;
          THRESHOLD=$(grep -A2 "project:" codecov.yml | grep "target:" | head -1 | sed "s/.*target: *\([0-9]*\).*/\1/") || THRESHOLD=95;
          gotestsum --format testdox -- -race -coverprofile=/tmp/coverage.out -covermode=atomic ./... &&
          COVERAGE=$(go tool cover -func=/tmp/coverage.out | grep total | awk "{print \$3}" | sed "s/%//") &&
          if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
            echo "Coverage ${COVERAGE}% is below ${THRESHOLD}%"; exit 1;
          fi
          '
        language: system
        files: '\.go$'
        pass_filenames: false
        stages: [pre-push]
```

## CI Pipeline (`.github/workflows/ci.yml`)

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

permissions: {}

jobs:
  lint:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - uses: actions/setup-go@v6
        with:
          go-version: "1.23"

      - name: golangci-lint
        uses: golangci/golangci-lint-action@v7
        with:
          version: latest
          args: --timeout 5m

  test:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - uses: actions/setup-go@v6
        with:
          go-version: "1.23"

      - name: Install gotestsum
        run: go install gotest.tools/gotestsum@latest

      - name: Run tests with coverage and race detection
        run: |
          gotestsum \
            --junitfile junit.xml \
            --format testdox \
            -- -v -race -coverprofile=coverage.out -covermode=atomic ./...

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v5
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./coverage.out
          flags: unit

  security:
    permissions:
      contents: read
      security-events: write
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Run Trivy scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v4
        with:
          sarif_file: 'trivy-results.sarif'
          category: 'trivy'

      - name: TruffleHog secret scan
        uses: trufflesecurity/trufflehog@main
        with:
          extra_args: --only-verified

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
