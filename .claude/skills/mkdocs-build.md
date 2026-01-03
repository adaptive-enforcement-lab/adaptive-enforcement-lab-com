---
name: mkdocs-build
description: Use when modifying documentation, configuration files, or before completing doc-related tasks
runOn: always
---

# MkDocs Build

Run MkDocs build in strict mode. This is the EXACT command from the pre-commit hook.

## Command

```bash
if [ -f .venv/bin/mkdocs ]; then .venv/bin/mkdocs build --strict; else mkdocs build --strict; fi
```

**No substitutions. No variations. No "I'll just run mkdocs build".**

## When This Runs

Triggered by changes to:

- `*.md` files
- `*.yml` or `*.yaml` files

## What --strict Does

Fails on:

- Missing references
- Invalid links
- Configuration errors
- Any MkDocs warnings

**If the build fails, fix the error. Don't disable strict mode.**
