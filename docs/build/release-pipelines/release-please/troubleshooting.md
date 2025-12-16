# Troubleshooting

Common release-please issues and solutions.

!!! tip "Validate Config First"
    Most issues stem from configuration. Use the JSON schema and verify paths match between config and manifest files.

---

## Common Issues

| Issue | Cause | Solution |
| ------- | ------- | ---------- |
| No PR created | No conventional commits | Use `feat:`, `fix:`, etc. prefixes |
| Wrong version bump | Commit type mismatch | Check commit types match changelog-sections |
| Changelog empty | Hidden sections | Remove `hidden: true` from desired sections |
| Duplicate tags | Inconsistent component settings | Verify `include-component-in-tag` consistency |
| PRs don't trigger builds | Using GITHUB_TOKEN | Switch to GitHub App token |
| Version not updated in file | Missing annotation | Add `# x-release-please-version` comment |

---

## Debugging Steps

### 1. Check Commit Format

```bash
git log --oneline -10
```

Commits must follow conventional format:

```text
feat: add new feature
fix: resolve bug
chore: update dependencies
```

### 2. Validate Configuration

Ensure `$schema` is set in `release-please-config.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json"
}
```

### 3. Check Manifest Versions

Verify `.release-please-manifest.json` contains correct package paths:

```json
{
  "packages/backend": "1.0.0",
  "packages/frontend": "1.0.0"
}
```

Paths must match `release-please-config.json` exactly.

### 4. Review Workflow Logs

Check the release-please action output for errors:

```bash
gh run view --log
```

---

## Version Stuck

If versions aren't bumping:

1. **Check for release PR** - Merge any open release-please PRs
2. **Verify commit scope** - Commits must touch files in package path
3. **Check branch** - Release-please only runs on default branch

---

## Related

- [Release-Please Overview](index.md) - Configuration basics
- [Workflow Triggers](../workflow-triggers.md) - Token issues
- [Release-please Issues](https://github.com/googleapis/release-please/issues) - GitHub issues
