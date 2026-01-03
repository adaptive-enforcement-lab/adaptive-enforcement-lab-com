# Container Registry Publishing

!!! tip "Key Insight"
    Container registries require OIDC authentication for provenance generation.

## Container Registries

```yaml
name: Publish to GHCR

on:
  release:
    types: [created]

permissions: {}

jobs:
  publish:
    permissions:
      contents: read
      packages: write
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - uses: docker/login-action@9780b0c442fbb1117ed29e0efdff1e18412f7567  # v3.3.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@5176d81f87c23d6fc96624dfdbcd9f3830bbe445  # v6.5.0
        with:
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ github.ref_name }}
            ghcr.io/${{ github.repository }}:latest
```

**Scorecard result**: Packaging 10/10
