---
description: >-
  Design CLI output for both humans and scripts. Table format for eyes, JSON/names format for pipes. Support quiet mode for automation workflows.
---

# Input/Output Contracts

Design commands to work in pipelines and automation.

!!! abstract "Dual Audience"
    Design for both humans and scripts: table format for eyes, JSON/names format for pipes and automation.

---

## Structured Output for Piping

Design commands to work in pipelines:

```go
package cmd

import (
    "encoding/json"
    "fmt"
    "os"

    "github.com/spf13/cobra"
)

type SelectResult struct {
    Deployments []string `json:"deployments"`
    Namespace   string   `json:"namespace"`
    Count       int      `json:"count"`
}

var selectCmd = &cobra.Command{
    Use:   "select",
    Short: "Select deployments for restart",
    Long: `Select deployments that need to be restarted based on cache changes.

Output can be piped to other commands:
  myctl select --output names | xargs -I {} kubectl rollout restart deployment/{}`,
    RunE: runSelect,
}

var outputFormat string

func init() {
    selectCmd.Flags().StringVarP(&outputFormat, "output", "o", "table", "Output format: table, json, names")
    rootCmd.AddCommand(selectCmd)
}

func runSelect(cmd *cobra.Command, args []string) error {
    ctx := cmd.Context()

    deployments, err := selectDeployments(ctx)
    if err != nil {
        return err
    }

    result := SelectResult{
        Deployments: deployments,
        Namespace:   namespace,
        Count:       len(deployments),
    }

    switch outputFormat {
    case "json":
        enc := json.NewEncoder(os.Stdout)
        enc.SetIndent("", "  ")
        return enc.Encode(result)

    case "names":
        // One name per line for piping
        for _, d := range deployments {
            fmt.Println(d)
        }

    default: // table
        if len(deployments) == 0 {
            fmt.Println("No deployments selected")
            return nil
        }
        fmt.Printf("NAMESPACE\tDEPLOYMENT\n")
        for _, d := range deployments {
            fmt.Printf("%s\t%s\n", namespace, d)
        }
    }

    return nil
}
```

---

## Pipeline Examples

```bash
# Pipe deployment names to restart
myctl select --output names | myctl restart -

# Filter with grep before restarting
myctl select --output names | grep "api-" | myctl restart -

# Export to JSON for processing
myctl select --output json | jq '.deployments[]'

# Use with xargs
myctl select --output names | xargs -I {} kubectl describe deployment/{}
```

---

## Output Format Guidelines

| Format | Use Case | Example |
| -------- | ---------- | --------- |
| `table` | Human reading in terminal | Default, formatted columns |
| `json` | Scripting and parsing | `jq` processing |
| `names` | Piping to other commands | One item per line |
| `yaml` | Configuration export | kubectl-style output |
| `wide` | Extended information | Additional columns |

---

## Input Flexibility

Support multiple input methods:

```go
func getDeploymentsFromInput(cmd *cobra.Command, args []string) ([]string, error) {
    // Priority 1: Explicit arguments
    if len(args) > 0 && args[0] != "-" {
        return args, nil
    }

    // Priority 2: Stdin (with - argument)
    if len(args) == 1 && args[0] == "-" {
        return readFromStdin()
    }

    // Priority 3: Interactive selection (if TTY)
    if isatty.IsTerminal(os.Stdin.Fd()) {
        return interactiveSelect()
    }

    return nil, fmt.Errorf("no deployments specified")
}
```

---

## Quiet and Verbose Modes

```go
var (
    quiet   bool
    verbose bool
)

func init() {
    rootCmd.PersistentFlags().BoolVarP(&quiet, "quiet", "q", false, "Suppress non-essential output")
    rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "Enable verbose output")
}

func log(format string, args ...interface{}) {
    if !quiet {
        fmt.Printf(format+"\n", args...)
    }
}

func debug(format string, args ...interface{}) {
    if verbose {
        fmt.Printf("[DEBUG] "+format+"\n", args...)
    }
}
```

---

## Best Practices

| Practice | Description |
| ---------- | ------------- |
| **Default to table** | Human-readable output by default |
| **Support JSON** | Enable scripting and automation |
| **One item per line** | For `names` format, enable easy piping |
| **Quiet mode** | Suppress non-essential output for scripts |
| **Consistent formats** | Use same format options across commands |

---

*Design for both humans and scripts: table for eyes, JSON/names for pipes.*
