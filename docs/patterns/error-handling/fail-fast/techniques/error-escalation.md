---
description: >-
  Error escalation strategies: when to throw vs return, error aggregation, panic vs recoverable errors, and exit codes.
tags:
  - fail-fast
  - error-escalation
  - error-handling
---

# Error Escalation

Determine when to throw vs return, when to panic vs recover.

!!! warning "Panic for Programming Errors Only"
    Use panic for unrecoverable programming errors (nil pointers, index out of bounds). Return errors for expected failure conditions that callers can handle (network timeouts, file not found).

---

## When to Throw vs Return Error

```go
// Return error: recoverable, caller can handle
func fetchUser(id string) (*User, error) {
    if id == "" {
        return nil, errors.New("user ID required")
    }

    user, err := db.Query("SELECT * FROM users WHERE id = ?", id)
    if err != nil {
        return nil, fmt.Errorf("database error: %w", err)
    }

    return user, nil
}

// Panic: programming error, should never happen
func processUsers(users []*User) {
    if users == nil {
        panic("processUsers called with nil slice")  // Programming error
    }

    for _, user := range users {
        if user == nil {
            panic("nil user in slice")  // Data corruption
        }
        // ... process user
    }
}
```

---

## Error Aggregation vs First-Error-Wins

```go
// First-error-wins: fast feedback
func validateFast(config *Config) error {
    if config.Host == "" {
        return errors.New("host required")  // Stop here
    }
    if config.Port == 0 {
        return errors.New("port required")
    }
    return nil
}

// Error aggregation: complete picture
func validateComplete(config *Config) error {
    var errors []string

    if config.Host == "" {
        errors = append(errors, "host required")
    }
    if config.Port == 0 {
        errors = append(errors, "port required")
    }
    if config.Timeout < 0 {
        errors = append(errors, "timeout must be positive")
    }

    if len(errors) > 0 {
        return fmt.Errorf("validation failed:\n- %s",
            strings.Join(errors, "\n- "))
    }
    return nil
}
```

---

## Panic vs Recoverable Errors

```go
func divide(a, b int) (int, error) {
    // Return error: expected error condition
    if b == 0 {
        return 0, errors.New("division by zero")
    }
    return a / b, nil
}

func arrayAccess(arr []int, index int) int {
    // Panic: programming error that should never happen in production
    if index < 0 || index >= len(arr) {
        panic(fmt.Sprintf("index out of bounds: %d (len=%d)", index, len(arr)))
    }
    return arr[index]
}
```

---

## Exit Codes

```bash
#!/bin/bash

# Exit codes communicate error type to caller

# 0: Success
# 1: General error
# 2: Misuse of command
# 126: Command not executable
# 127: Command not found
# 128+n: Fatal error signal n

deploy() {
    if [ $# -ne 2 ]; then
        echo "Usage: deploy <environment> <version>" >&2
        exit 2  # Misuse of command
    fi

    if ! command -v kubectl >/dev/null; then
        echo "kubectl not found" >&2
        exit 127  # Command not found
    fi

    if ! kubectl auth can-i create deployments; then
        echo "Insufficient permissions" >&2
        exit 1  # General error
    fi

    kubectl apply -f deployment.yaml || exit 1

    exit 0  # Success
}

deploy "$@"
```

---

## Back to Fail Fast

- [Fail Fast Overview](../index.md)
- [Early Termination](early-termination.md)
- [Strict Mode](strict-mode.md)
- [Assertions](assertions.md)
- [Timeouts](timeouts.md)
