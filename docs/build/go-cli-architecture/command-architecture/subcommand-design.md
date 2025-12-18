---
description: >-
  Build composable CLI subcommands that work independently or in pipelines. Support stdin input, command registration, and hidden debugging commands.
---

# Subcommand Design

Each subcommand should be independently useful.

!!! tip "Composable Commands"
    Each command should work independently but compose well with others. `myctl select | myctl restart -` demonstrates good pipeline design.

---

## Check Command

```go
package cmd

import (
    "context"
    "encoding/json"
    "fmt"
    "os"
    "time"

    "github.com/spf13/cobra"
)

type CheckResult struct {
    Valid     bool   `json:"valid"`
    Reason    string `json:"reason,omitempty"`
    Timestamp string `json:"timestamp"`
}

var checkCmd = &cobra.Command{
    Use:   "check",
    Short: "Check if cache rebuild is needed",
    Long: `Check the current cache state and determine if a rebuild is required.

Exit codes:
  0 - Cache is valid
  1 - Cache needs rebuild
  2 - Error occurred`,
    RunE: runCheck,
}

var outputJSON bool

func init() {
    checkCmd.Flags().BoolVar(&outputJSON, "json", false, "Output result as JSON")
    rootCmd.AddCommand(checkCmd)
}

func runCheck(cmd *cobra.Command, args []string) error {
    ctx := cmd.Context()

    valid, reason, err := performCacheCheck(ctx)
    if err != nil {
        return err
    }

    result := CheckResult{
        Valid:     valid,
        Reason:    reason,
        Timestamp: time.Now().Format(time.RFC3339),
    }

    if outputJSON {
        enc := json.NewEncoder(os.Stdout)
        enc.SetIndent("", "  ")
        return enc.Encode(result)
    }

    if valid {
        fmt.Println("Cache is valid")
        return nil
    }

    fmt.Printf("Cache needs rebuild: %s\n", reason)
    os.Exit(1)
    return nil
}
```

---

## Command Registration

Organize command registration cleanly:

```go
// cmd/root.go
package cmd

import (
    "github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
    Use:   "myctl",
    Short: "Kubernetes orchestration CLI",
}

func init() {
    // Global flags
    rootCmd.PersistentFlags().StringP("namespace", "n", "default", "Kubernetes namespace")
    rootCmd.PersistentFlags().Bool("verbose", false, "Enable verbose output")
    rootCmd.PersistentFlags().Bool("dry-run", false, "Show what would be done")

    // Register subcommands
    rootCmd.AddCommand(orchestrateCmd)
    rootCmd.AddCommand(checkCmd)
    rootCmd.AddCommand(rebuildCmd)
    rootCmd.AddCommand(selectCmd)
    rootCmd.AddCommand(restartCmd)
    rootCmd.AddCommand(versionCmd)
}

func Execute() error {
    return rootCmd.Execute()
}
```

---

## Reading from Stdin

Support stdin input with `-` argument for piping:

```go
package cmd

import (
    "bufio"
    "fmt"
    "os"
    "strings"

    "github.com/spf13/cobra"
)

var restartCmd = &cobra.Command{
    Use:   "restart [deployments...]",
    Short: "Restart deployments",
    Long: `Restart the specified deployments.

Deployment names can be provided as arguments or piped via stdin:
  myctl select --output names | myctl restart -`,
    RunE: runRestart,
}

func runRestart(cmd *cobra.Command, args []string) error {
    ctx := cmd.Context()

    var deployments []string

    // Check if reading from stdin
    if len(args) == 1 && args[0] == "-" {
        scanner := bufio.NewScanner(os.Stdin)
        for scanner.Scan() {
            line := strings.TrimSpace(scanner.Text())
            if line != "" {
                deployments = append(deployments, line)
            }
        }
        if err := scanner.Err(); err != nil {
            return fmt.Errorf("failed to read stdin: %w", err)
        }
    } else {
        deployments = args
    }

    if len(deployments) == 0 {
        return fmt.Errorf("no deployments specified")
    }

    for _, d := range deployments {
        fmt.Printf("Restarting %s...\n", d)
        if err := restartDeployment(ctx, d); err != nil {
            return err
        }
    }

    return nil
}
```

---

## Hidden Commands

Mark debugging or internal commands as hidden:

```go
var debugCmd = &cobra.Command{
    Use:    "debug",
    Short:  "Internal debugging commands",
    Hidden: true,  // Won't appear in help
}

var dumpCacheCmd = &cobra.Command{
    Use:   "dump-cache",
    Short: "Dump internal cache state",
    RunE: func(cmd *cobra.Command, args []string) error {
        // Debug implementation
        return nil
    },
}

func init() {
    debugCmd.AddCommand(dumpCacheCmd)
    rootCmd.AddCommand(debugCmd)
}
```

---

*Each command should work independently but compose well with others.*
