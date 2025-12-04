# CI/CD Examples

Tombstone marker implementations for GitHub Actions and other CI/CD systems.

---

## GitHub Actions Examples

### Step-Level Markers

```yaml
- name: Check if already deployed
  id: check
  run: |
    MARKER=".deployed-${{ github.sha }}"
    if [ -f "$MARKER" ]; then
      echo "skip=true" >> "$GITHUB_OUTPUT"
    else
      echo "skip=false" >> "$GITHUB_OUTPUT"
    fi

- name: Deploy
  if: steps.check.outputs.skip != 'true'
  run: |
    ./deploy.sh
    touch ".deployed-${{ github.sha }}"

- name: Commit marker
  if: steps.check.outputs.skip != 'true'
  run: |
    git add ".deployed-*"
    git commit -m "Mark deployment complete" || true
    git push || true
```

### Artifact-Based Markers

```yaml
- name: Check for completion marker
  id: check
  continue-on-error: true
  uses: actions/download-artifact@v4
  with:
    name: completed-${{ github.sha }}

- name: Run expensive operation
  if: steps.check.outcome == 'failure'
  run: ./expensive-operation.sh

- name: Create completion marker
  if: steps.check.outcome == 'failure'
  run: echo "done" > marker.txt

- name: Upload marker
  if: steps.check.outcome == 'failure'
  uses: actions/upload-artifact@v4
  with:
    name: completed-${{ github.sha }}
    path: marker.txt
```

### Cache-Based Markers

```yaml
- name: Check completion cache
  id: cache
  uses: actions/cache@v4
  with:
    path: .completion-marker
    key: completed-${{ github.sha }}-${{ hashFiles('src/**') }}

- name: Run if not cached
  if: steps.cache.outputs.cache-hit != 'true'
  run: |
    ./build.sh
    mkdir -p .completion-marker
    echo "done" > .completion-marker/status
```

---

## Database-Based Markers

### SQL Tracking Table

```sql
CREATE TABLE operation_markers (
  operation_id VARCHAR(255) PRIMARY KEY,
  completed_at TIMESTAMP DEFAULT NOW(),
  result TEXT,
  metadata JSONB
);

-- Check before operation
SELECT 1 FROM operation_markers WHERE operation_id = $1;

-- Mark complete after operation
INSERT INTO operation_markers (operation_id, result)
VALUES ($1, $2)
ON CONFLICT (operation_id) DO NOTHING;
```

### Redis-Based Markers

```bash
# Check marker
if redis-cli EXISTS "completed:$OPERATION_ID" | grep -q "1"; then
  echo "Already completed"
  exit 0
fi

perform_operation

# Set marker with expiration
redis-cli SETEX "completed:$OPERATION_ID" 86400 "$(date -Iseconds)"
```

---

## Related

- [Tombstone Markers Overview](index.md) - Pattern basics and examples
- [Edge Cases](edge-cases.md) - Gotchas and mitigations
