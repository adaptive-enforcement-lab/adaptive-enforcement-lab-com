# Content Hashing

Compare content hashes to detect meaningful changes.

---

## The Technique

Instead of comparing entire files byte-by-byte, compute cryptographic hashes and compare those. If hashes match, content is identical.

```python
import hashlib

def content_changed(source: bytes, target: bytes) -> bool:
    return hashlib.sha256(source).digest() != hashlib.sha256(target).digest()

if content_changed(new_config, existing_config):
    deploy(new_config)
else:
    log("No changes, skipping deployment")
```

---

## When to Use

- Comparing files or configurations
- Detecting changes in API responses
- Validating cached artifacts
- Any scenario where exact byte equality matters

---

## Implementation Patterns

### File Comparison

```bash
# Bash: Compare file hashes
SOURCE_HASH=$(sha256sum source.txt | cut -d' ' -f1)
TARGET_HASH=$(sha256sum target.txt | cut -d' ' -f1)

if [ "$SOURCE_HASH" = "$TARGET_HASH" ]; then
  echo "Files identical, skipping"
else
  echo "Files differ, processing"
fi
```

### Directory Comparison

```bash
# Hash entire directory contents
dir_hash() {
  find "$1" -type f -exec sha256sum {} \; | sort | sha256sum | cut -d' ' -f1
}

SOURCE_HASH=$(dir_hash src/)
CACHE_HASH=$(cat .cache-hash 2>/dev/null || echo "")

if [ "$SOURCE_HASH" = "$CACHE_HASH" ]; then
  echo "No source changes, skipping build"
else
  run_build
  echo "$SOURCE_HASH" > .cache-hash
fi
```

### API Response Comparison

```python
import hashlib
import json

def normalize_and_hash(data: dict) -> str:
    """Hash JSON after sorting keys for consistent comparison."""
    normalized = json.dumps(data, sort_keys=True, separators=(',', ':'))
    return hashlib.sha256(normalized.encode()).hexdigest()

current_state = fetch_api_state()
desired_state = load_desired_state()

if normalize_and_hash(current_state) == normalize_and_hash(desired_state):
    log("State already matches, skipping sync")
else:
    apply_state(desired_state)
```

---

## Hash Algorithm Selection

| Algorithm | Speed | Security | Use Case |
|-----------|-------|----------|----------|
| MD5 | Fast | Weak | Non-security comparisons |
| SHA-1 | Fast | Weak | Git compatibility |
| SHA-256 | Medium | Strong | General purpose |
| xxHash | Very fast | None | Performance-critical |

For work avoidance (non-security), speed often matters more than cryptographic strength. MD5 or xxHash are fine choices.

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| File doesn't exist | Treat as "changed" (needs creation) |
| Empty file | Hash the empty content (valid state) |
| Binary files | Works identically to text |
| Large files | Stream hash instead of loading to memory |

### Streaming Large Files

```python
def hash_file(path: str, chunk_size: int = 8192) -> str:
    """Hash large files without loading entirely into memory."""
    hasher = hashlib.sha256()
    with open(path, 'rb') as f:
        while chunk := f.read(chunk_size):
            hasher.update(chunk)
    return hasher.hexdigest()
```

---

## Limitations

Content hashing catches **all** changes, including:

- Whitespace differences
- Comment changes
- Metadata updates (versions, timestamps)

If you need to ignore certain changes, combine with [Volatile Field Exclusion](volatile-field-exclusion.md).

---

## Related

- [Volatile Field Exclusion](volatile-field-exclusion.md) - When you need to ignore some changes
- [Cache-Based Skip](cache-based-skip.md) - Using hashes as cache keys
- [Techniques Overview](index.md) - All work avoidance techniques
