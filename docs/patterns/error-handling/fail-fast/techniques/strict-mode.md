---
title: Strict Mode Execution
description: >-
  Strict mode execution: shell strict mode, TypeScript strict mode, linter enforcement, and schema validation.
tags:
  - fail-fast
  - strict-mode
  - validation
---
# Strict Mode Execution

Enable strictest validation and error detection.

!!! tip "Strict Mode Catches Bugs at Compile Time"
    Enabling strict mode shifts errors from runtime to compile time. TypeScript's `strict: true` and shell's `set -euo pipefail` catch bugs before they reach production.

---

## Shell Strict Mode

```bash
#!/bin/bash
set -euo pipefail

# Fail on:
# - Any command failure (-e)
# - Undefined variables (-u)
# - Pipeline failures (-o pipefail)

# Bad: silent failure on typo
name=$USRNAME  # Typo, but no error without -u
echo "Hello $name"

# Good: fails immediately
set -u
name=$USRNAME  # Error: USRNAME: unbound variable
```

---

## TypeScript Strict Mode

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  }
}
```

```typescript
// Strict mode catches errors at compile time

// Error: implicit any
function processData(data) {  // Must specify type
    return data.value;
}

// Error: possible null
function getName(user: User | null): string {
    return user.name;  // Error: Object is possibly 'null'
}

// Good: explicit checks
function getName(user: User | null): string {
    if (!user) {
        throw new Error("user is null");
    }
    return user.name;
}
```

---

## Linter Enforcement

```yaml
# .golangci.yml - Strict linting
linters:
  enable:
    - errcheck      # Check all errors are handled
    - gosec         # Security issues
    - govet         # Suspicious constructs
    - staticcheck   # Advanced static analysis
    - unused        # Unused code

linters-settings:
  errcheck:
    check-blank: true  # Fail on blank identifier assignments
    check-type-assertions: true
```

```yaml
# GitHub Actions - Enforce linting
- name: Lint
  run: golangci-lint run --config .golangci.yml
  # Workflow fails if linter finds issues
```

---

## Back to Fail Fast

- [Fail Fast Overview](../index.md)
- [Early Termination](early-termination.md)
- [Assertions](assertions.md)
- [Error Escalation](error-escalation.md)
- [Timeouts](timeouts.md)
