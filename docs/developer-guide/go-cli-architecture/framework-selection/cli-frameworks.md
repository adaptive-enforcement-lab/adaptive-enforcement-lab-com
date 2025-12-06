# CLI Frameworks

Compare Go CLI frameworks to choose the right foundation for your tool.

---

## Cobra

The de facto standard for Go CLIs. Powers kubectl, docker, gh, and most Kubernetes ecosystem tools.

```go
package cmd

import (
    "fmt"
    "os"

    "github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
    Use:   "myctl",
    Short: "Kubernetes orchestration CLI",
    Long:  `A CLI for managing deployments and cache operations.`,
}

func Execute() {
    if err := rootCmd.Execute(); err != nil {
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }
}

func init() {
    rootCmd.PersistentFlags().StringP("namespace", "n", "default", "Kubernetes namespace")
    rootCmd.PersistentFlags().Bool("verbose", false, "Enable verbose output")
}
```

**Strengths:**

- Mature ecosystem with extensive documentation
- Built-in help generation, shell completion
- Hierarchical command structure
- Pairs well with Viper for configuration

**When to use:** Most Kubernetes-native CLIs. Default choice unless you have specific reasons otherwise.

### Help Text Generation

Cobra automatically generates help text from your command definitions:

```go
var checkCmd = &cobra.Command{
    Use:   "check [flags]",
    Short: "Check cache status",
    Long: `Check the current cache state and determine if a rebuild is required.

The check command validates the cache against the current state of
deployments in the cluster and reports whether action is needed.

Exit codes:
  0 - Cache is valid
  1 - Cache needs rebuild
  2 - Error occurred`,
    Example: `  # Check cache status
  myctl check

  # Check with JSON output
  myctl check --json

  # Check specific namespace
  myctl check -n production`,
    RunE: runCheck,
}
```

---

## urfave/cli

Simpler API, good for straightforward CLIs without deep command hierarchies.

```go
package main

import (
    "fmt"
    "log"
    "os"

    "github.com/urfave/cli/v2"
)

func main() {
    app := &cli.App{
        Name:  "myctl",
        Usage: "Kubernetes orchestration CLI",
        Flags: []cli.Flag{
            &cli.StringFlag{
                Name:    "namespace",
                Aliases: []string{"n"},
                Value:   "default",
                Usage:   "Kubernetes namespace",
            },
        },
        Commands: []*cli.Command{
            {
                Name:  "check",
                Usage: "Check cache status",
                Action: func(c *cli.Context) error {
                    fmt.Println("Checking cache...")
                    return nil
                },
            },
        },
    }

    if err := app.Run(os.Args); err != nil {
        log.Fatal(err)
    }
}
```

**Strengths:**

- Single-file friendly
- Less boilerplate for simple CLIs
- Good for scripts evolving into tools

**When to use:** Simple CLIs with few commands, prototypes.

---

## Kong

Type-safe CLI parsing using struct tags. Newer but gaining adoption.

```go
package main

import (
    "fmt"

    "github.com/alecthomas/kong"
)

type CLI struct {
    Namespace string `short:"n" default:"default" help:"Kubernetes namespace"`
    Verbose   bool   `help:"Enable verbose output"`

    Check   CheckCmd   `cmd:"" help:"Check cache status"`
    Rebuild RebuildCmd `cmd:"" help:"Rebuild cache"`
}

type CheckCmd struct {
    All bool `help:"Check all namespaces"`
}

func (c *CheckCmd) Run() error {
    fmt.Println("Checking cache...")
    return nil
}

type RebuildCmd struct{}

func (r *RebuildCmd) Run() error {
    fmt.Println("Rebuilding cache...")
    return nil
}

func main() {
    var cli CLI
    ctx := kong.Parse(&cli)
    err := ctx.Run()
    ctx.FatalIfErrorf(err)
}
```

**Strengths:**

- Type-safe command definitions
- Compile-time validation of CLI structure
- Clean struct-based API

**When to use:** New projects that value type safety, teams familiar with struct tags.

---

## Best Practices

### Flag Naming

| Pattern | Example | Notes |
|---------|---------|-------|
| Kebab-case for flags | `--dry-run` | Standard convention |
| Short flags for common options | `-n` for namespace | Match kubectl patterns |
| Avoid abbreviations | `--namespace` not `--ns` | Clarity over brevity |

### Required vs Optional

```go
// Required flags
cmd.MarkFlagRequired("name")

// Mutually exclusive
cmd.MarkFlagsMutuallyExclusive("file", "stdin")

// Required together
cmd.MarkFlagsRequiredTogether("username", "password")
```

---

*Match kubectl conventions. Your users already know them.*
