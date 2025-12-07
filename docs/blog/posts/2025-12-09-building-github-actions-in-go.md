---
date: 2025-12-09
authors:
  - mark
categories:
  - Go
  - GitHub Actions
  - Release Engineering
description: >-
  Single-binary distribution, millisecond cold starts, zero runtime deps.
  Ship Go-based GitHub Actions the right way.
slug: building-github-actions-in-go
---

# Go-Based GitHub Actions: From Code to Marketplace

Go works well for GitHub Actions. Single binaries, fast starts, cross-platform builds, and no runtime deps.

Here's how to go from code to release.

<!-- more -->

## Why Go for GitHub Actions?

| Advantage | Impact |
|-----------|--------|
| Single binary | No `node_modules` or virtual env needed |
| Fast cold start | Starts in milliseconds, not seconds |
| Cross-platform | One codebase builds for Linux, macOS, Windows |
| Strong typing | Catch errors at compile time |

The trade-off is larger binary size, but caching helps.

!!! tip "Binary Distribution"
    Use composite actions with pre-built binaries. Don't make users compile from source.

---

## Project Structure

```text
my-action/
├── action.yml                 # GitHub Action definition
├── cmd/
│   └── my-action/
│       └── main.go           # CLI entrypoint
├── pkg/
│   ├── analyzer/             # Core business logic
│   ├── config/               # Configuration handling
│   └── output/               # Output formatters
├── .github/workflows/
│   ├── build.yml             # CI: build, test, lint
│   └── release.yml           # Release automation
├── .goreleaser.yml           # Binary release configuration
├── go.mod
└── README.md
```

---

## The action.yml File

Define your action interface. Composite steps download and run the binary:

```yaml
name: 'My Go Action'
description: 'Analyze things with Go speed'
author: 'Your Name'

inputs:
  path:
    description: 'Path to analyze'
    required: false
    default: '.'
  check:
    description: 'Exit with error on failure'
    required: false
    default: 'true'
  version:
    description: 'Tool version to use'
    required: false
    default: 'latest'

runs:
  using: 'composite'
  steps:
    - name: Download binary
      shell: bash
      run: |
        VERSION="${{ inputs.version }}"

        if [ "$VERSION" = "latest" ]; then
          VERSION=$(curl -sL "https://api.github.com/repos/OWNER/REPO/releases/latest" \
            | jq -r '.tag_name')
        fi

        ARCH="amd64"
        [ "$RUNNER_ARCH" = "ARM64" ] && ARCH="arm64"

        URL="https://github.com/OWNER/REPO/releases/download/${VERSION}/my-action_linux_${ARCH}.tar.gz"
        curl -sL "$URL" | tar -xz -C /tmp
        chmod +x /tmp/my-action

    - name: Run analysis
      shell: bash
      run: |
        ARGS=""
        [ "${{ inputs.check }}" = "true" ] && ARGS="--check"
        /tmp/my-action $ARGS "${{ inputs.path }}"
```

---

## CLI Structure

Standard Cobra CLI with version injection:

```go
package main

import (
    "fmt"
    "os"

    "github.com/spf13/cobra"
)

var version = "dev" // Set by goreleaser

func main() {
    rootCmd := &cobra.Command{
        Use:     "my-action [path]",
        Short:   "Analyze things quickly",
        Version: version,
        RunE:    run,
    }

    rootCmd.Flags().Bool("check", false, "Exit 1 on failure")
    rootCmd.Flags().StringP("config", "c", "", "Config file path")

    if err := rootCmd.Execute(); err != nil {
        os.Exit(1)
    }
}

func run(cmd *cobra.Command, args []string) error {
    check, _ := cmd.Flags().GetBool("check")

    // Your logic here...

    if check && failed > 0 {
        return fmt.Errorf("%d file(s) failed", failed)
    }
    return nil
}
```

---

## GoReleaser Configuration

Build cross-platform binaries:

```yaml
# .goreleaser.yml
version: 2

builds:
  - id: my-action
    main: ./cmd/my-action
    binary: my-action_{{ .Os }}_{{ .Arch }}
    env:
      - CGO_ENABLED=0
    goos:
      - linux
      - darwin
      - windows
    goarch:
      - amd64
      - arm64
    ldflags:
      - -s -w
      - -X main.version={{ .Version }}

archives:
  - id: my-action
    builds: [my-action]
    format: tar.gz
    name_template: "my-action_{{ .Os }}_{{ .Arch }}"

checksum:
  name_template: 'checksums.txt'

changelog:
  use: github-native
```

---

## Release Workflow

Trigger GoReleaser on tags. Update floating version tags:

```yaml
name: Release

on:
  push:
    tags: ['*']

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - uses: actions/setup-go@v6
        with:
          go-version-file: go.mod

      - uses: goreleaser/goreleaser-action@v6
        with:
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Update floating tags
        run: |
          VERSION=${GITHUB_REF#refs/tags/}
          MAJOR=$(echo $VERSION | cut -d. -f1)

          git tag -f $MAJOR
          git push -f origin $MAJOR
```

!!! info "Floating Tags"
    `v1` points to the latest `v1.x.x`. Users pin to `@v1` for auto bug fix updates.

---

## Job Summaries

Write markdown summaries to `$GITHUB_STEP_SUMMARY`:

```go
func writeJobSummary(results []*Result) error {
    path := os.Getenv("GITHUB_STEP_SUMMARY")
    if path == "" {
        return nil // Not in GitHub Actions
    }

    f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0644)
    if err != nil {
        return err
    }
    defer f.Close()

    fmt.Fprintln(f, "## Analysis Results")
    fmt.Fprintln(f, "| File | Status |")
    fmt.Fprintln(f, "|------|--------|")
    for _, r := range results {
        status := "Pass"
        if r.Failed {
            status = "Fail"
        }
        fmt.Fprintf(f, "| %s | %s |\n", r.File, status)
    }
    return nil
}
```

---

## Testing Your Action

### Local Testing

```bash
# Build and test directly
go build -o my-action ./cmd/my-action
./my-action --check docs/

# Test with act (local GitHub Actions runner)
brew install act
act -j test-action
```

### CI Testing

```yaml
test-action:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v6

    - name: Test action
      uses: ./
      with:
        path: README.md
        check: false
```

---

## Versioning Strategy

1. **Full versions**: `v1.0.0`, `v1.0.1`, `v1.1.0`
2. **Floating tags**: `v1` → latest `v1.x.x`

Users reference your action as:

```yaml
- uses: owner/my-action@v1  # Gets latest v1.x.x
```

---

## The Payoff

Go-based actions provide:

- **Fast execution**: No interpreter startup
- **Reliable distribution**: Binaries work everywhere
- **Simple updates**: Floating tags for easy upgrades
- **Professional polish**: Job summaries and exit codes

The setup effort pays off. You get better reliability and user experience.

---

## Related

- [Shipping a GitHub Action the Right Way](2025-12-06-shipping-a-github-action-the-right-way.md) - The motivation for this guide
- [Pre-commit Hooks with Binary Releases](2025-12-10-pre-commit-hooks-binary-releases.md) - Same patterns for pre-commit
- [Should Work ≠ Does Work](2025-12-08-always-works-qa-methodology.md) - Verify your action before release
- [Go CLI Architecture](../../developer-guide/go-cli-architecture/index.md) - Comprehensive CLI design patterns
