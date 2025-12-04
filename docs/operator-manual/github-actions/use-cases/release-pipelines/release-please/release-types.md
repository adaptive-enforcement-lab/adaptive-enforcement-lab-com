# Release Types

Release-please supports multiple package ecosystems with type-specific version management.

---

## Node

For npm packages. Updates `package.json` and `package-lock.json`:

```json
{
  "packages/my-package": {
    "release-type": "node",
    "component": "my-package",
    "package-name": "@org/my-package"
  }
}
```

---

## Helm

For Helm charts. Updates `Chart.yaml`:

```json
{
  "charts/my-chart": {
    "release-type": "helm",
    "component": "my-chart",
    "include-component-in-tag": false
  }
}
```

!!! tip "Helm Versioning"

    Set `include-component-in-tag: false` for Helm charts so tags match
    `Chart.yaml` version (e.g., `1.0.0` not `my-chart-1.0.0`).

---

## Simple

For generic versioning. Updates a `version.txt` or similar:

```json
{
  ".": {
    "release-type": "simple",
    "component": "root"
  }
}
```

---

## Changelog Sections

Control how commits appear in changelogs:

```json
{
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug Fixes" },
    { "type": "perf", "section": "Performance" },
    { "type": "refactor", "section": "Code Refactoring", "hidden": true },
    { "type": "docs", "section": "Documentation", "hidden": true },
    { "type": "chore", "section": "Maintenance" },
    { "type": "test", "section": "Tests", "hidden": true },
    { "type": "ci", "section": "CI/CD", "hidden": true }
  ]
}
```

| Property | Description |
|----------|-------------|
| `type` | Conventional commit type to match |
| `section` | Heading in changelog |
| `hidden` | Exclude from changelog (still affects versioning) |

---

## Scope Filtering

Target specific commit scopes to hide noise while keeping other commits visible:

```json
{
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug Fixes" },
    { "type": "chore", "scope": "deps", "section": "Dependencies", "hidden": true },
    { "type": "chore", "section": "Maintenance" }
  ]
}
```

The `scope` field matches the parenthetical in conventional commits:

| Commit | Matches | Result |
|--------|---------|--------|
| `chore(deps): bump lodash` | `scope: "deps"` | Hidden |
| `chore: update config` | No scope match | Visible under Maintenance |
| `chore(build): fix webpack` | No `scope: "build"` rule | Visible under Maintenance |

This prevents dependency updates from cluttering changelogs while keeping other maintenance commits visible.

---

## Related

- [Release-Please Overview](index.md) - Configuration basics
- [Extra-Files](extra-files.md) - Version tracking in arbitrary files
- [Conventional Commits](https://www.conventionalcommits.org/) - Commit message specification
