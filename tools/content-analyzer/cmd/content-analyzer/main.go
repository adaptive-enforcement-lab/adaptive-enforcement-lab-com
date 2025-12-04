package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/adaptive-enforcement-lab/content-analyzer/pkg/analyzer"
	"github.com/adaptive-enforcement-lab/content-analyzer/pkg/config"
	"github.com/adaptive-enforcement-lab/content-analyzer/pkg/output"
	"github.com/spf13/cobra"
)

var (
	formatFlag   string
	verboseFlag  bool
	checkFlag    bool
	configFlag   string
	maxGradeFlag float64
	maxARIFlag   float64
	maxLinesFlag int
)

func main() {
	rootCmd := &cobra.Command{
		Use:   "content-analyzer [path]",
		Short: "Analyze markdown documentation for readability and structure",
		Long: `A tool for analyzing documentation quality, readability, and structure.

Computes readability metrics (Flesch-Kincaid, ARI, Coleman-Liau, etc.),
structural analysis (headings, line counts), and content composition.

Configuration:
  Reads .content-analyzer.yml from the target directory or git root.
  CLI flags override config file values.

Examples:
  content-analyzer docs/quickstart.md
  content-analyzer docs/
  content-analyzer docs/ --format json
  content-analyzer docs/ --format markdown
  content-analyzer docs/ --check
  content-analyzer docs/ --config .content-analyzer.yml`,
		Args: cobra.ExactArgs(1),
		RunE: run,
	}

	rootCmd.Flags().StringVarP(&formatFlag, "format", "f", "table", "Output format: table, json, markdown, summary")
	rootCmd.Flags().BoolVarP(&verboseFlag, "verbose", "v", false, "Show all metrics")
	rootCmd.Flags().BoolVar(&checkFlag, "check", false, "Check against thresholds (exit 1 on failure)")
	rootCmd.Flags().StringVarP(&configFlag, "config", "c", "", "Path to config file (default: auto-detect .content-analyzer.yml)")
	rootCmd.Flags().Float64Var(&maxGradeFlag, "max-grade", 0, "Maximum Flesch-Kincaid grade level (overrides config)")
	rootCmd.Flags().Float64Var(&maxARIFlag, "max-ari", 0, "Maximum ARI score (overrides config)")
	rootCmd.Flags().IntVar(&maxLinesFlag, "max-lines", 0, "Maximum lines per file (overrides config, 0 to disable)")

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func run(cmd *cobra.Command, args []string) error {
	path := args[0]

	// Load configuration
	var cfg *config.Config
	if configFlag != "" {
		var err error
		cfg, err = config.Load(configFlag)
		if err != nil {
			return fmt.Errorf("cannot load config %s: %w", configFlag, err)
		}
	} else {
		// Auto-detect config file
		startDir := path
		if info, err := os.Stat(path); err == nil && !info.IsDir() {
			startDir = filepath.Dir(path)
		}
		configPath := config.FindConfigFile(startDir)
		if configPath != "" {
			cfg, _ = config.Load(configPath)
		}
	}

	// Use default config if none found
	if cfg == nil {
		cfg = config.DefaultConfig()
	}

	// Apply CLI flag overrides
	if maxGradeFlag > 0 {
		cfg.Thresholds.MaxGrade = maxGradeFlag
	}
	if maxARIFlag > 0 {
		cfg.Thresholds.MaxARI = maxARIFlag
	}
	if cmd.Flags().Changed("max-lines") {
		cfg.Thresholds.MaxLines = maxLinesFlag
	}

	a := analyzer.NewWithConfig(cfg)

	// Check if path is file or directory
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("cannot access %s: %w", path, err)
	}

	var results []*analyzer.Result

	if info.IsDir() {
		results, err = a.AnalyzeDirectory(path)
		if err != nil {
			return fmt.Errorf("error analyzing directory: %w", err)
		}
	} else {
		result, err := a.AnalyzeFile(path)
		if err != nil {
			return fmt.Errorf("error analyzing file: %w", err)
		}
		results = []*analyzer.Result{result}
	}

	if len(results) == 0 {
		fmt.Fprintln(os.Stderr, "No markdown files found")
		return nil
	}

	// Output results
	switch formatFlag {
	case "json":
		if err := output.JSON(os.Stdout, results); err != nil {
			return fmt.Errorf("error writing JSON: %w", err)
		}
	case "markdown":
		output.Markdown(os.Stdout, results)
	case "summary":
		output.Summary(os.Stdout, results)
	default:
		output.Table(os.Stdout, results, verboseFlag)
	}

	// Check mode: exit with error if any files failed
	if checkFlag {
		failed := 0
		for _, r := range results {
			if r.Status == "fail" {
				failed++
			}
		}
		if failed > 0 {
			return fmt.Errorf("%d file(s) failed readability checks", failed)
		}
	}

	return nil
}
