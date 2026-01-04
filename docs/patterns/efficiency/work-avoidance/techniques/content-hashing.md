---
title: Content Hashing
description: >-
  Compare cryptographic hashes to detect meaningful changes. SHA-256, streaming strategies, and algorithm selection for file comparisons and config synchronization.
---
# Content Hashing

Compare content hashes to detect meaningful changes.

!!! tip "When to Use"
    Use content hashing when exact byte equality matters—file comparisons, config sync, and artifact validation.

---

## The Technique

Instead of comparing entire files byte-by-byte, compute cryptographic hashes and compare those. If hashes match, content is identical.

```go
package main

import (
    "crypto/sha256"
    "bytes"
)

func contentChanged(source, target []byte) bool {
    sourceHash := sha256.Sum256(source)
    targetHash := sha256.Sum256(target)
    return !bytes.Equal(sourceHash[:], targetHash[:])
}

func main() {
    if contentChanged(newConfig, existingConfig) {
        deploy(newConfig)
    } else {
        log.Println("No changes, skipping deployment")
    }
}
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

```go
package main

import (
    "crypto/sha256"
    "encoding/hex"
    "encoding/json"
    "log"
)

func normalizeAndHash(data map[string]any) string {
    // JSON marshal with sorted keys for consistent comparison
    normalized, _ := json.Marshal(data)
    hash := sha256.Sum256(normalized)
    return hex.EncodeToString(hash[:])
}

func main() {
    currentState := fetchAPIState()
    desiredState := loadDesiredState()

    if normalizeAndHash(currentState) == normalizeAndHash(desiredState) {
        log.Println("State already matches, skipping sync")
    } else {
        applyState(desiredState)
    }
}
```

---

## Hash Algorithm Selection

| Algorithm | Speed | Security | Use Case |
| ----------- | ------- | ---------- | ---------- |
| MD5 | Fast | Weak | Non-security comparisons |
| SHA-1 | Fast | Weak | Git compatibility |
| SHA-256 | Medium | Strong | General purpose |
| xxHash | Very fast | None | Performance-critical |

For work avoidance (non-security), speed often matters more than cryptographic strength. MD5 or xxHash are fine choices.

---

## Edge Cases

| Scenario | Handling |
| ---------- | ---------- |
| File doesn't exist | Treat as "changed" (needs creation) |
| Empty file | Hash the empty content (valid state) |
| Binary files | Works identically to text |
| Large files | Stream hash instead of loading to memory |

### Streaming Large Files

```go
package main

import (
    "crypto/sha256"
    "encoding/hex"
    "io"
    "os"
)

func hashFile(path string) (string, error) {
    f, err := os.Open(path)
    if err != nil {
        return "", err
    }
    defer f.Close()

    h := sha256.New()
    if _, err := io.Copy(h, f); err != nil {
        return "", err
    }

    return hex.EncodeToString(h.Sum(nil)), nil
}
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
