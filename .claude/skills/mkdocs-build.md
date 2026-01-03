---
name: mkdocs-build
description: Build and validate MkDocs site using venv if available
runOn: always
---

# Build MkDocs Site

Build MkDocs site in strict mode to catch all validation errors.

**CRITICAL**: Use `.venv/bin/mkdocs` if it exists, otherwise fall back to system `mkdocs`.

```bash
if [ -f .venv/bin/mkdocs ]; then
    .venv/bin/mkdocs build --strict
else
    mkdocs build --strict
fi
```

This matches the pre-commit hook configuration exactly.
