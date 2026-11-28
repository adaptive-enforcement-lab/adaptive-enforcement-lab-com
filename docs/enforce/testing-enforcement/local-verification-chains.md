---
title: Local Verification Chains
description: >-
  Verify every change locally before CI does: command chains for code logic, CLI flags and pipeline changes, a checklist template, and pre-commit hooks.
provenance: human
---
# Local Verification Chains

CI should confirm, not discover. Run the change yourself before you push, using the chain
that matches the kind of change.

!!! tip "The Rule"
    Read the output. A command that ran is not a result you observed.

---

## Code Logic Changes

```bash
# 1. Build
go build ./...

# 2. Run unit tests
go test ./...

# 3. Run the specific scenario
./my-tool --flag-i-changed input.txt

# 4. Verify output matches expectations
# (Actually read the output, don't assume)
```

## CLI Flag Changes

```bash
# 1. Build
go build ./...

# 2. Test the new flag
./my-tool --new-flag value

# 3. Test flag interactions
./my-tool --new-flag value --existing-flag

# 4. Test help output
./my-tool --help | grep new-flag

# 5. Test invalid input
./my-tool --new-flag invalid-value
```

## CI/CD Pipeline Changes

```bash
# 1. Lint the workflow file
actionlint .github/workflows/my-workflow.yml

# 2. Validate YAML syntax
yamllint .github/workflows/my-workflow.yml

# 3. Create a test branch and push
git checkout -b test-workflow
git push origin test-workflow

# 4. Watch CI run, don't assume
gh run view <run-id> --log
```

---

## Checklist Template

For a change with several behaviours, write the checklist before you start:

```markdown
## Verification Checklist

- [ ] Code compiles: `go build ./...`
- [ ] Linter passes: `golangci-lint run ./...`
- [ ] Warning appears for failure case:
  - Create failing input
  - Run tool with `--check`
  - Observe expected warning message
- [ ] No warnings for passing case:
  - Run tool on valid input
  - Observe no warnings
- [ ] Exit codes correct:
  - Failure returns exit 1
  - Success returns exit 0
```

---

## Enforce It With Pre-commit

Local hooks make the build and lint steps automatic:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: go-build
        name: go build
        entry: go build ./...
        language: system
        pass_filenames: false

      - id: go-lint
        name: golangci-lint
        entry: golangci-lint run
        language: system
        pass_filenames: false
```

---

## Related

- [Coverage Enforcement](coverage-enforcement.md) - Gate merges on test coverage
- [Should Work ≠ Does Work](../../blog/posts/2025-12-08-always-works-qa-methodology.md) - The story behind the method
