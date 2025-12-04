package main

import (
	"fmt"
	"os"

	"github.com/adaptive-enforcement-lab/content-analyzer/pkg/analyzer"
	"github.com/adaptive-enforcement-lab/content-analyzer/pkg/output"
	"github.com/spf13/cobra"
)

var (
	formatFlag   string
	verboseFlag  bool
	checkFlag    bool
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

Examples:
  content-analyzer docs/quickstart.md
  content-analyzer docs/
  content-analyzer docs/ --format json
  content-analyzer docs/ --check --max-grade 12`,
		Args: cobra.ExactArgs(1),
		RunE: run,
	}

	rootCmd.Flags().StringVarP(&formatFlag, "format", "f", "table", "Output format: table, json")
	rootCmd.Flags().BoolVarP(&verboseFlag, "verbose", "v", false, "Show all metrics")
	rootCmd.Flags().BoolVar(&checkFlag, "check", false, "Check against thresholds (exit 1 on failure)")
	rootCmd.Flags().Float64Var(&maxGradeFlag, "max-grade", 14.0, "Maximum Flesch-Kincaid grade level")
	rootCmd.Flags().Float64Var(&maxARIFlag, "max-ari", 14.0, "Maximum ARI score")
	rootCmd.Flags().IntVar(&maxLinesFlag, "max-lines", 375, "Maximum lines per file (0 to disable)")

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func run(cmd *cobra.Command, args []string) error {
	path := args[0]

	// Configure thresholds
	thresholds := analyzer.DefaultThresholds()
	thresholds.MaxFleschKincaidGrade = maxGradeFlag
	thresholds.MaxARI = maxARIFlag
	thresholds.MaxLines = maxLinesFlag

	a := analyzer.NewWithThresholds(thresholds)

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
