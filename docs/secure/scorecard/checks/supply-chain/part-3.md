---
title: Binary-Artifacts Check
description: >-
  Detect and remediate binary artifacts in repositories to prevent supply chain compromise and improve dependency transparency for security audits.
---
# Binary-Artifacts Check

!!! tip "Key Insight"
    Binary artifacts in repositories indicate potential supply chain compromise.

## Binary-Artifacts

**Target**: 10/10 by removing binaries from git history

**What it checks**: Whether repository contains binary files (executables, libraries, archives) in git.

**Why it matters**: Binaries in git can hide malware. Source code can be audited, binaries cannot.

### Common Binary Types Flagged

Scorecard detects:

- Executables: `.exe`, `.dll`, `.so`, `.dylib`
- Java archives: `.jar`, `.war`, `.ear`
- Compressed files: `.zip`, `.tar.gz`, `.tgz`
- Python wheels: `.whl`
- Node modules: `.node`
- Fonts: `.ttf`, `.otf`, `.woff` (sometimes)
- Images: `.png`, `.jpg` (if large or in wrong location)

### Find Binaries in Current State

```bash
# Search for common binary extensions

find . -type f \( \
  -name "*.exe" -o \
  -name "*.dll" -o \
  -name "*.so" -o \
  -name "*.dylib" -o \
  -name "*.jar" -o \
  -name "*.zip" -o \
  -name "*.tar.gz" \
\) | grep -v node_modules | grep -v .git
```

### Find Binaries in Git History

Even if binaries are deleted from current state, Scorecard checks git history:

```bash
# Find all binary files ever committed

git log --all --numstat --diff-filter=A --summary | \
  grep -E "\.(exe|dll|so|dylib|jar|zip|tar\.gz)$" | \
  head -20
```

### Removal Strategy

#### Option 1: Remove from Current State (Easiest)

If binary is in current state but you don't want to rewrite history:

```bash
# Move to GitHub Releases

gh release upload v1.0.0 binary_file

# Remove from git

git rm binary_file
git commit -m "Remove binary from git, use GitHub Releases"
git push
```

**Result**: Scorecard may still flag historical presence, but new commits are clean.

#### Option 2: Rewrite Git History (Complete Fix)

**Warning**: Requires force push. Coordinate with team.

```bash
# Install git-filter-repo

pip install git-filter-repo

# Remove binary from all history

git filter-repo --path binary_file --invert-paths

# Force push (DESTRUCTIVE!)

git push --force-with-lease
```

**Impact**: All collaborators must re-clone repository.

### Alternative: Use Package Managers

Instead of committing binaries:

**For release artifacts**:

```yaml
# Don't commit to git

# Upload to GitHub Releases

- name: Upload Release Asset
  run: gh release upload ${{ github.ref_name }} binary_file
```

**For dependencies**:

```dockerfile
# Don't commit vendor/

# Download at build time

FROM golang:1.21
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
```

**For tools**:

```yaml
# Don't commit bin/

# Install from package manager

- name: Install Tools
  run: |
    curl -sSfL https://github.com/tool/releases/download/v1.0.0/tool-linux-amd64.tar.gz | \
      tar -xz -C /usr/local/bin
```

### Prevent Future Binaries

Add to `.gitignore`:

```gitignore
# Binaries

*.exe
*.dll
*.so
*.dylib
*.jar
*.war
*.ear

# Compressed archives

*.zip
*.tar.gz
*.tgz

# Build outputs

bin/
dist/
build/
*.o
*.a

# Package manager caches

vendor/
node_modules/

# OS-specific

.DS_Store
Thumbs.db
```

### Pre-commit Hook

Prevent accidental binary commits:

`.git/hooks/pre-commit`:

```bash
#!/bin/bash

# Check for binary files

binaries=$(git diff --cached --name-only --diff-filter=A | \
  grep -E '\.(exe|dll|so|dylib|jar|zip|tar\.gz)$')

if [ -n "$binaries" ]; then
  echo "Error: Attempting to commit binary files:"
  echo "$binaries"
  echo ""
  echo "Use GitHub Releases or package managers instead."
  exit 1
fi
```

Make executable:

```bash
chmod +x .git/hooks/pre-commit
```

### Legitimate Binary Use Cases

**Documentation images**: Usually fine if in `docs/` or `README.md`

**Test fixtures**: Small binaries for unit tests may be acceptable

**Fonts for UI**: May need to commit font files for web apps

**Decision framework**:

- Is binary necessary for repository function?
- Can it be downloaded at build time instead?
- Is it auditable by humans (no)?
- Does benefit outweigh supply chain risk?

**If legitimate**: Document in repository README why binary is necessary.

### Troubleshooting

#### Scorecard flagging images in docs/

**Check**: Are images very large? Scorecard may flag large files as binaries.

**Solution**: Optimize images or use external hosting (imgur, CDN).

#### Removed binary but still flagged

**Cause**: Binary exists in git history.

**Solution**: Rewrite history with `git filter-repo` or accept historical presence.

#### Need to commit vendor/ for reproducible builds

**Decision**: Security vs. reproducibility trade-off.

**Mitigation**: Document in repository README, accept lower Scorecard score.

---
