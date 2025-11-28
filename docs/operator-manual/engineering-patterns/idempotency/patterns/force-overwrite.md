---
title: Force Overwrite
description: >-
  Skip the check, just overwrite. Safe when replacing with identical
  content is acceptable.
---

# Force Overwrite

Sometimes the simplest solution is the best: just overwrite it.

---

## The Pattern

```bash
# Don't check, just write
cp -f "$SOURCE" "$TARGET"
```

Force overwrite skips existence checks entirely. The operation succeeds whether the target exists or not, and the final state is always the desired state.

```mermaid
flowchart LR
    A[Source] --> B[Overwrite]
    B --> C[Target = Source]

    style A fill:#3b4252,stroke:#88c0d0,color:#eceff4
    style B fill:#3b4252,stroke:#ebcb8b,color:#eceff4
    style C fill:#3b4252,stroke:#a3be8c,color:#eceff4
```

!!! example "Zero Decisions"

    Force overwrite has no branches in its logic. The target becomes the source, period. Previous state is irrelevant.

---

## When to Use

!!! success "Good Fit"

    - Writing configuration files (same content = same result)
    - Syncing files where source is authoritative
    - Branch resets where local state should match remote
    - Cache population where stale data should be replaced
    - Artifact uploads where latest version wins

!!! warning "Poor Fit"

    - Resources with history you want to preserve
    - Collaborative content (user edits would be lost)
    - Operations where overwrites have side effects
    - When you need to know if content actually changed

---

## Examples

### File Synchronization

```bash
# Copy file regardless of whether target exists
cp -f "$SOURCE_FILE" "$TARGET_FILE"
```

```bash
# Sync directory contents
rsync -a --delete source/ target/
```

### Git Branch Reset

```bash
# Force-reset branch to match remote
git checkout -B "$BRANCH" "origin/$BRANCH"
```

The `-B` flag creates the branch if it doesn't exist, or resets it if it does.

### Git Push with Lease

```bash
# Force push with safety check
git push --force-with-lease origin "$BRANCH"
```

`--force-with-lease` overwrites the remote but fails if someone else pushed changes you haven't seen. It's force overwrite with a safety net.

### Configuration Files

```bash
# Generate config from template (always overwrites)
envsubst < config.template > config.yaml
```

```bash
# Write known-good config
cat > /etc/app/config.json << 'EOF'
{
  "setting": "value"
}
EOF
```

### GitHub Actions Artifacts

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: build-output
    path: dist/
    overwrite: true  # Explicitly overwrite if exists
```

---

## Safe Force Overwrite Patterns

### Force with Lease (Git)

```bash
# Overwrites remote branch, but fails if remote changed unexpectedly
git push --force-with-lease origin feature-branch
```

This prevents accidentally overwriting someone else's commits while still enabling idempotent branch updates.

### Atomic Write (Files)

```bash
# Write to temp file, then atomically move
cat > "$TARGET.tmp" << 'EOF'
content here
EOF
mv -f "$TARGET.tmp" "$TARGET"
```

Atomic write prevents partial content if the process is interrupted.

!!! tip "The Temp-Then-Move Pattern"

    Always use write-to-temp + atomic move for critical files. A `mv` on the same filesystem is atomic; a multi-megabyte write is not.

### Backup Before Overwrite

```bash
# Preserve previous version just in case
cp "$TARGET" "$TARGET.bak" 2>/dev/null || true
cp -f "$SOURCE" "$TARGET"
```

### Conditional Force Based on Content

```bash
# Only force overwrite if content differs
if ! diff -q "$SOURCE" "$TARGET" &>/dev/null; then
  cp -f "$SOURCE" "$TARGET"
  echo "Updated $TARGET"
else
  echo "No changes needed"
fi
```

This hybrid approach avoids unnecessary writes while still being idempotent.

---

## GitHub Actions Examples

### Cache Overwrite

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: npm-${{ hashFiles('package-lock.json') }}
    # Cache is overwritten on key match (save always runs)
```

### Artifact Replacement

```yaml
- name: Upload coverage report
  uses: actions/upload-artifact@v4
  with:
    name: coverage
    path: coverage/
    overwrite: true
    retention-days: 5
```

### Environment Variable Override

```yaml
- name: Set deployment version
  run: |
    # Always overwrites previous value
    echo "DEPLOY_VERSION=${{ github.sha }}" >> "$GITHUB_ENV"
```

---

## Kubernetes Examples

### ConfigMap Replacement

```bash
# Delete and recreate (force overwrite pattern)
kubectl delete configmap app-config --ignore-not-found
kubectl create configmap app-config --from-file=config/
```

Or use the declarative approach:

```bash
# Apply overwrites existing ConfigMap
kubectl apply -f configmap.yaml
```

### Secret Rotation

```bash
# Force-replace secret
kubectl create secret generic db-creds \
  --from-literal=password="$NEW_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## Edge Cases and Gotchas

### Loss of History

Force overwrite destroys previous state:

```bash
# Previous content of config.yaml is gone
cp -f new-config.yaml config.yaml
```

**Mitigation**: Use version control or backups for important files.

### Unexpected Content Changes

If source content changes between runs, target changes too:

```bash
# Run 1: writes v1.0
cp -f release.tar.gz /deploy/

# Run 2: writes v1.1 (source changed)
cp -f release.tar.gz /deploy/
```

**Consideration**: This might be desired (latest wins) or problematic (version mismatch).

### Force Push Dangers

!!! danger "Never Force Push to Shared Branches"

    `git push --force` to `main` or `master` can destroy your team's work. Commits they pushed will vanish. Always use `--force-with-lease` at minimum.

```bash
# DANGEROUS: can destroy team members' work
git push --force origin main
```

```bash
# SAFER: fails if remote has unexpected commits
git push --force-with-lease origin main
```

### Partial Writes

Non-atomic overwrites can leave corrupt state:

```bash
# If process dies mid-write, file is corrupt
cat > large-file.bin < /dev/stdin
```

**Mitigation**: Write to temp file, then atomic move.

---

## Anti-Patterns

### Force Push to Shared Branches

```bash
# Bad: destroys others' work without warning
git push --force origin main

# Better: use force-with-lease
git push --force-with-lease origin main

# Best: don't force push to main at all
```

### Silent Overwrites of User Data

```bash
# Bad: user's customizations lost without warning
cp -f default.config ~/.myapp/config

# Better: merge or prompt
if [ -f ~/.myapp/config ]; then
  echo "Config exists. Overwrite? (y/n)"
fi
```

### Overwrite Without Verification

```bash
# Bad: no way to know if overwrite was needed
cp -f source target

# Better: log whether content changed
if ! diff -q source target &>/dev/null; then
  cp -f source target
  echo "Updated target"
fi
```

---

## Comparison with Other Patterns

| Aspect | [Check-Before-Act](check-before-act.md) | [Upsert](upsert.md) | Force Overwrite |
|--------|-----------------|--------|-----------------|
| Preserves history | Yes | Depends | No |
| Requires existence check | Yes | No | No |
| Shows if content changed | Yes | Sometimes | No (unless you add diff) |
| Simplicity | Medium | High | Highest |

---

## Summary

Force overwrite is the simplest idempotency pattern.

!!! abstract "Key Takeaways"

    1. **Use for authoritative sources** - when your source is always correct
    2. **Add safety nets** - `--force-with-lease`, atomic writes, backups
    3. **Consider history** - don't destroy data you might need
    4. **Log changes** - add diff checks if you need visibility into what changed
