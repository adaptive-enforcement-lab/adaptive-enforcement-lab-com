---
description: >-
  Coordinate multi-step workflows through a single CLI entry point. Implement dry-run mode, consistent exit codes, and error handling for production use.
---

# Orchestrator Pattern

Coordinate multi-step workflows through a single entry point.

!!! tip "Single Entry Point"
    For complex workflows, expose one command that coordinates subcommands. Users run `myctl orchestrate` instead of chaining multiple commands.

---

## Implementation

```go
package cmd

import (
    "context"
    "fmt"

    "github.com/spf13/cobra"
)

var orchestrateCmd = &cobra.Command{
    Use:   "orchestrate",
    Short: "Run the full orchestration workflow",
    Long: `Execute the complete workflow: check cache, rebuild if needed,
select deployments, and trigger restarts.

This is the main entry point for automated execution.`,
    RunE: runOrchestrate,
}

func runOrchestrate(cmd *cobra.Command, args []string) error {
    ctx := cmd.Context()

    // Step 1: Check cache
    fmt.Println("Checking cache...")
    valid, err := checkCache(ctx)
    if err != nil {
        return fmt.Errorf("cache check failed: %w", err)
    }

    if valid {
        fmt.Println("Cache valid, nothing to do")
        return nil
    }

    // Step 2: Rebuild cache
    fmt.Println("Rebuilding cache...")
    if err := rebuildCache(ctx); err != nil {
        return fmt.Errorf("cache rebuild failed: %w", err)
    }

    // Step 3: Select deployments
    fmt.Println("Selecting deployments...")
    deployments, err := selectDeployments(ctx)
    if err != nil {
        return fmt.Errorf("deployment selection failed: %w", err)
    }

    if len(deployments) == 0 {
        fmt.Println("No deployments need restart")
        return nil
    }

    // Step 4: Restart deployments
    fmt.Printf("Restarting %d deployments...\n", len(deployments))
    if err := restartDeployments(ctx, deployments); err != nil {
        return fmt.Errorf("restart failed: %w", err)
    }

    fmt.Println("Orchestration complete")
    return nil
}
```

---

## Rebuild Command

The rebuild command forces a cache rebuild:

```go
package cmd

import (
    "context"
    "fmt"

    "github.com/spf13/cobra"
)

var rebuildCmd = &cobra.Command{
    Use:   "rebuild",
    Short: "Force rebuild of the cache",
    Long: `Rebuild the cache from scratch, ignoring any existing cached data.

Use this when you suspect the cache is corrupted or out of sync.`,
    RunE: runRebuild,
}

var forceRebuild bool

func init() {
    rebuildCmd.Flags().BoolVar(&forceRebuild, "force", false, "Skip confirmation prompt")
    rootCmd.AddCommand(rebuildCmd)
}

func runRebuild(cmd *cobra.Command, args []string) error {
    ctx := cmd.Context()

    if !forceRebuild {
        fmt.Print("This will invalidate all cached data. Continue? [y/N]: ")
        var response string
        fmt.Scanln(&response)
        if response != "y" && response != "Y" {
            fmt.Println("Aborted")
            return nil
        }
    }

    fmt.Println("Rebuilding cache...")
    if err := rebuildCache(ctx); err != nil {
        return fmt.Errorf("rebuild failed: %w", err)
    }

    fmt.Println("Cache rebuilt successfully")
    return nil
}
```

---

## Error Handling and Exit Codes

### Consistent Exit Codes

| Code | Meaning |
| ------ | --------- |
| 0 | Success |
| 1 | Operation failed or condition not met |
| 2 | Invalid usage or configuration error |
| 3 | Partial failure (some operations succeeded) |

### ExitError Type

```go
package cmd

import (
    "fmt"
    "os"
)

// ExitError wraps an error with an exit code
type ExitError struct {
    Err  error
    Code int
}

func (e *ExitError) Error() string {
    return e.Err.Error()
}

// Execute handles ExitError for proper exit codes
func Execute() {
    if err := rootCmd.Execute(); err != nil {
        if exitErr, ok := err.(*ExitError); ok {
            fmt.Fprintln(os.Stderr, exitErr.Error())
            os.Exit(exitErr.Code)
        }
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }
}

// Usage in commands
func runCheck(cmd *cobra.Command, args []string) error {
    valid, err := performCacheCheck(cmd.Context())
    if err != nil {
        return &ExitError{Err: err, Code: 2}
    }
    if !valid {
        return &ExitError{Err: fmt.Errorf("cache needs rebuild"), Code: 1}
    }
    return nil
}
```

---

## Dry Run Mode

!!! tip "Always Implement Dry Run"

    Users expect `--dry-run` to preview changes safely. This builds trust and enables CI integration without side effects.

Add a global `--dry-run` flag that shows what would happen:

```go
package cmd

import (
    "fmt"

    "github.com/spf13/cobra"
)

var dryRun bool

func init() {
    rootCmd.PersistentFlags().BoolVar(&dryRun, "dry-run", false, "Show what would be done")
}

func runRestart(cmd *cobra.Command, args []string) error {
    ctx := cmd.Context()

    deployments, err := selectDeployments(ctx)
    if err != nil {
        return err
    }

    for _, d := range deployments {
        if dryRun {
            fmt.Printf("[dry-run] Would restart deployment: %s\n", d)
            continue
        }
        fmt.Printf("Restarting deployment: %s\n", d)
        if err := restartDeployment(ctx, d); err != nil {
            return fmt.Errorf("failed to restart %s: %w", d, err)
        }
    }

    return nil
}
```

---

*The orchestrator coordinates; individual commands do the work.*
