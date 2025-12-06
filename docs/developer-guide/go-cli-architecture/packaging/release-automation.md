# Release Automation

Automate multi-architecture builds and releases with GitHub Actions and GoReleaser.

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
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=sha

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            VERSION=${{ github.ref_name }}
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
    use: buildx
    build_flag_templates:
      - "--platform=linux/amd64"
      - "--label=org.opencontainers.image.title={{ .ProjectName }}"
      - "--label=org.opencontainers.image.version={{ .Version }}"
    dockerfile: Dockerfile

  - image_templates:
      - "ghcr.io/myorg/myctl:{{ .Version }}-arm64"
    use: buildx
    build_flag_templates:
      - "--platform=linux/arm64"
    goarch: arm64
    dockerfile: Dockerfile

docker_manifests:
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

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

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

docker-build:
    docker build --build-arg VERSION=$(VERSION) -t myctl:$(VERSION) .

docker-push:
    docker push ghcr.io/myorg/myctl:$(VERSION)
```

---

*Automate releases: one tag push creates binaries, images, and changelogs.*
