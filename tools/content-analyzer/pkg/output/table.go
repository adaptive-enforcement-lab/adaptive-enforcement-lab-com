package output

import (
	"fmt"
	"io"
	"strings"

	"github.com/adaptive-enforcement-lab/content-analyzer/pkg/analyzer"
)

// Table writes results in human-readable table format.
func Table(w io.Writer, results []*analyzer.Result, verbose bool) {
	for _, r := range results {
		writeFileResult(w, r, verbose)
		fmt.Fprintln(w)
	}

	if len(results) > 1 {
		writeSummary(w, results)
	}
}

func writeFileResult(w io.Writer, r *analyzer.Result, verbose bool) {
	// File path
	fmt.Fprintf(w, "%s\n", r.File)

	// Basic metrics
	fmt.Fprintf(w, "  Lines: %d | Words: %d | Reading time: %d min\n",
		r.Structural.Lines,
		r.Structural.Words,
		r.Structural.ReadingTimeMinutes,
	)

	// Headings
	fmt.Fprintf(w, "  Headers: H1=%d H2=%d H3=%d H4=%d\n",
		r.Headings.H1,
		r.Headings.H2,
		r.Headings.H3,
		r.Headings.H4,
	)

	// Readability scores
	ease := readabilityLabel(r.Readability.FleschReadingEase)
	fmt.Fprintf(w, "  Readability: FK=%.1f ARI=%.1f Flesch=%.1f (%s)\n",
		r.Readability.FleschKincaidGrade,
		r.Readability.ARI,
		r.Readability.FleschReadingEase,
		ease,
	)

	// Composition
	fmt.Fprintf(w, "  Code: %.0f%% | Prose: %d lines\n",
		r.Composition.CodeBlockRatio*100,
		r.Composition.ProseLines,
	)

	// Status
	status := strings.ToUpper(r.Status)
	fmt.Fprintf(w, "  Status: %s\n", status)

	if verbose {
		fmt.Fprintf(w, "  Additional metrics:\n")
		fmt.Fprintf(w, "    Coleman-Liau: %.1f\n", r.Readability.ColemanLiau)
		fmt.Fprintf(w, "    Gunning Fog: %.1f\n", r.Readability.GunningFog)
		fmt.Fprintf(w, "    SMOG: %.1f\n", r.Readability.SMOG)
		fmt.Fprintf(w, "    Sentences: %d\n", r.Structural.Sentences)
		fmt.Fprintf(w, "    Characters: %d\n", r.Structural.Characters)
	}
}

func writeSummary(w io.Writer, results []*analyzer.Result) {
	fmt.Fprintln(w, "---")
	fmt.Fprintf(w, "Summary: %d files analyzed\n", len(results))

	passed := 0
	failed := 0
	totalWords := 0
	totalLines := 0

	for _, r := range results {
		if r.Status == "pass" {
			passed++
		} else {
			failed++
		}
		totalWords += r.Structural.Words
		totalLines += r.Structural.Lines
	}

	fmt.Fprintf(w, "  Passed: %d | Failed: %d\n", passed, failed)
	fmt.Fprintf(w, "  Total: %d words, %d lines\n", totalWords, totalLines)
}

// readabilityLabel converts Flesch Reading Ease score to human label.
func readabilityLabel(score float64) string {
	switch {
	case score >= 90:
		return "Very Easy"
	case score >= 80:
		return "Easy"
	case score >= 70:
		return "Fairly Easy"
	case score >= 60:
		return "Standard"
	case score >= 50:
		return "Fairly Difficult"
	case score >= 30:
		return "Difficult"
	default:
		return "Very Difficult"
	}
}
