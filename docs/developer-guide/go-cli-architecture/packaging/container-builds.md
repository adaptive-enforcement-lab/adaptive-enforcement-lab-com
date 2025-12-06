# Container Builds

Create minimal, secure container images with multi-stage builds.

---

## Standard Pattern

```dockerfile
# Build stage
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Build binary
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${VERSION:-dev}" \
    -o /myctl \
    ./main.go

# Runtime stage
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /myctl /myctl

USER nonroot:nonroot

ENTRYPOINT ["/myctl"]
```

---

## Distroless Benefits

!!! danger "Security First"

    Never use `latest` tags in production. Pin to specific versions and scan images for vulnerabilities in CI.

Distroless is preferred for security:

- No shell (reduces attack surface)
- No package manager
- Non-root user by default
- Automatic security updates via base image

```dockerfile
# Use nonroot variant for security
FROM gcr.io/distroless/static-debian12:nonroot

# Or debug variant for troubleshooting (includes shell)
FROM gcr.io/distroless/static-debian12:debug-nonroot
```

---

## Version Injection

### Build-Time Variables

```go
// main.go
package main

import (
    "myctl/cmd"
)

// Set via ldflags at build time
var (
    version = "dev"
    commit  = "unknown"
    date    = "unknown"
)

func main() {
    cmd.SetVersionInfo(version, commit, date)
    cmd.Execute()
}
```

```go
// cmd/version.go
package cmd

import (
    "fmt"
    "runtime"

    "github.com/spf13/cobra"
)

var (
    Version string
    Commit  string
    Date    string
)

func SetVersionInfo(version, commit, date string) {
    Version = version
    Commit = commit
    Date = date
}

var versionCmd = &cobra.Command{
    Use:   "version",
    Short: "Print version information",
    Run: func(cmd *cobra.Command, args []string) {
        fmt.Printf("Version:    %s\n", Version)
        fmt.Printf("Commit:     %s\n", Commit)
        fmt.Printf("Built:      %s\n", Date)
        fmt.Printf("Go version: %s\n", runtime.Version())
        fmt.Printf("OS/Arch:    %s/%s\n", runtime.GOOS, runtime.GOARCH)
    },
}

func init() {
    rootCmd.AddCommand(versionCmd)
}
```

### Build Script

```bash
#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo 'dev')}"
COMMIT="${COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')}"
DATE="${DATE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

go build \
    -ldflags="-w -s \
        -X main.version=${VERSION} \
        -X main.commit=${COMMIT} \
        -X main.date=${DATE}" \
    -o myctl \
    ./main.go
```

---

## Multi-Architecture Builds

### Dockerfile for Multi-Arch

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder

ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG VERSION=dev

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -ldflags="-w -s -X main.version=${VERSION}" \
    -o /myctl \
    ./main.go

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /myctl /myctl

USER nonroot:nonroot

ENTRYPOINT ["/myctl"]
```

---

## Security Context

When deploying, use a secure pod security context:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

---

*Small image + non-root + read-only = secure container.*
