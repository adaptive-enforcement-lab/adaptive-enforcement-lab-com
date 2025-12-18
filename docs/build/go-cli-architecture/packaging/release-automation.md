---
description: >-
  Automate multi-architecture builds with GoReleaser and GitHub Actions. One git tag push creates binaries, container images, and changelogs for all platforms.
---

# Release Automation

Automate multi-architecture builds and releases with GitHub Actions and GoReleaser.

!!! tip "One Tag, Full Release"
    Push a git tag, get binaries for all platforms, container images for amd64/arm64, and an auto-generated changelog. GoReleaser handles the complexity.

---

## GitHub Actions Workflow

```yaml
name: Build and Push

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU
        run: |
          sudo apt-get update
          sudo apt-get install -y qemu-user-static

      - name: Login to GHCR
        uses: redhat-actions/podman-login@v1
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Generate image metadata
        id: meta
        run: |
          IMAGE=ghcr.io/${{ github.repository }}
          VERSION=${GITHUB_REF_NAME#v}
          MAJOR=$(echo $VERSION | cut -d. -f1)
          MINOR=$(echo $VERSION | cut -d. -f1-2)
          SHA=${GITHUB_SHA::7}

          TAGS="${IMAGE}:${VERSION},${IMAGE}:${MAJOR}.${MINOR},${IMAGE}:${MAJOR},${IMAGE}:${SHA}"

          echo "tags=${TAGS}" >> $GITHUB_OUTPUT
          echo "version=${VERSION}" >> $GITHUB_OUTPUT

      - name: Build multi-arch image
        id: build
        uses: redhat-actions/buildah-build@v2
        with:
          image: ghcr.io/${{ github.repository }}
          tags: ${{ steps.meta.outputs.tags }}
          platforms: linux/amd64,linux/arm64
          containerfiles: ./Dockerfile
          build-args: |
            VERSION=${{ github.ref_name }}
          labels: |
            org.opencontainers.image.source=${{ github.event.repository.html_url }}
            org.opencontainers.image.revision=${{ github.sha }}
            org.opencontainers.image.version=${{ steps.meta.outputs.version }}

      - name: Push to GHCR
        uses: redhat-actions/push-to-registry@v2
        with:
          image: ${{ steps.build.outputs.image }}
          tags: ${{ steps.build.outputs.tags }}
          registry: ghcr.io
```

---

## GoReleaser Configuration

For automated binary releases, use [GoReleaser](https://goreleaser.com/):

```yaml
# .goreleaser.yaml
version: 2

before:
  hooks:
    - go mod tidy

builds:
  - id: myctl
    binary: myctl
    main: ./main.go
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
      - -X main.version={{.Version}}
      - -X main.commit={{.ShortCommit}}
      - -X main.date={{.Date}}

archives:
  - id: myctl
    formats:
      - tar.gz
      - zip
    name_template: "{{ .ProjectName }}_{{ .Version }}_{{ .Os }}_{{ .Arch }}"
    files:
      - LICENSE
      - README.md

checksum:
  name_template: 'checksums.txt'
  algorithm: sha256

changelog:
  use: github
  sort: asc
  filters:
    exclude:
      - '^docs:'
      - '^test:'
      - '^chore:'

dockers:
  - image_templates:
      - "ghcr.io/myorg/myctl:{{ .Version }}-amd64"
    use: podman
    build_flag_templates:
      - "--platform=linux/amd64"
      - "--label=org.opencontainers.image.title={{ .ProjectName }}"
      - "--label=org.opencontainers.image.version={{ .Version }}"
    dockerfile: Dockerfile

  - image_templates:
      - "ghcr.io/myorg/myctl:{{ .Version }}-arm64"
    use: podman
    build_flag_templates:
      - "--platform=linux/arm64"
    goarch: arm64
    dockerfile: Dockerfile

podman_manifests:
  - name_template: "ghcr.io/myorg/myctl:{{ .Version }}"
    image_templates:
      - "ghcr.io/myorg/myctl:{{ .Version }}-amd64"
      - "ghcr.io/myorg/myctl:{{ .Version }}-arm64"
  - name_template: "ghcr.io/myorg/myctl:latest"
    image_templates:
      - "ghcr.io/myorg/myctl:{{ .Version }}-amd64"
      - "ghcr.io/myorg/myctl:{{ .Version }}-arm64"
```

---

## Release Workflow with GoReleaser

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write
  packages: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-go@v5
        with:
          go-version: '1.23'

      - name: Install Podman
        run: |
          sudo apt-get update
          sudo apt-get install -y podman

      - name: Set up QEMU
        run: |
          sudo apt-get install -y qemu-user-static

      - name: Login to GHCR
        uses: redhat-actions/podman-login@v1
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Run GoReleaser
        uses: goreleaser/goreleaser-action@v6
        with:
          version: latest
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## Makefile Integration

```makefile
.PHONY: release snapshot

VERSION ?= $(shell git describe --tags --always --dirty)

release:
    goreleaser release --clean

snapshot:
    goreleaser release --snapshot --clean

image-build:
    podman build --build-arg VERSION=$(VERSION) -t myctl:$(VERSION) .

image-push:
    podman push ghcr.io/myorg/myctl:$(VERSION)
```

---

*Automate releases: one tag push creates binaries, images, and changelogs.*
