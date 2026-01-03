# npm Publishing

!!! tip "Key Insight"
    npm provenance attestations provide verifiable build integrity.

## npm (Automated Publishing)

```yaml
name: Publish to npm

on:
  release:
    types: [created]

permissions: {}

jobs:
  publish:
    permissions:
      contents: read
      id-token: write  # npm provenance
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - uses: actions/setup-node@1e60f620b9541d16bece96c5465dc8ee9832be0b  # v4.0.3
        with:
          node-version: 20
          registry-url: https://registry.npmjs.org/

      - run: npm ci
      - run: npm publish --provenance --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

**Scorecard result**: Packaging 10/10

**Bonus**: `--provenance` flag generates npm provenance attestations (similar to SLSA).
