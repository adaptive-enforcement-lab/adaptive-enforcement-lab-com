package output

import (
	"fmt"
	"io"
	"sort"

	"github.com/adaptive-enforcement-lab/content-analyzer/pkg/analyzer"
)

// Markdown writes results as a GitHub-flavored markdown table.
func Markdown(w io.Writer, results []*analyzer.Result) {
	fmt.Fprintln(w, "## Documentation Readability Report")
	fmt.Fprintln(w)

	// Summary first
	passed, failed, totalWords, totalLines := aggregateCounts(results)
	fmt.Fprintf(w, "**%d files** analyzed | **%d passed** | **%d failed** | %d words | %d lines\n\n",
		len(results), passed, failed, totalWords, totalLines)

	// Table header
	fmt.Fprintln(w, "| File | Lines | Words | FK Grade | ARI | Flesch | Status |")
	fmt.Fprintln(w, "|------|------:|------:|---------:|----:|-------:|:------:|")

	// Sort by status (failed first), then by file path
	sorted := make([]*analyzer.Result, len(results))
	copy(sorted, results)
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].Status != sorted[j].Status {
			return sorted[i].Status == "fail"
		}
		return sorted[i].File < sorted[j].File
	})

	for _, r := range sorted {
		status := "✅"
		if r.Status == "fail" {
			status = "❌"
		}
		fmt.Fprintf(w, "| `%s` | %d | %d | %.1f | %.1f | %.1f | %s |\n",
			r.File,
			r.Structural.Lines,
			r.Structural.Words,
			r.Readability.FleschKincaidGrade,
			r.Readability.ARI,
			r.Readability.FleschReadingEase,
			status,
		)
	}
}

// Summary writes only an aggregate summary in markdown format.
func Summary(w io.Writer, results []*analyzer.Result) {
	passed, failed, totalWords, totalLines := aggregateCounts(results)

	fmt.Fprintln(w, "## Documentation Quality Summary")
	fmt.Fprintln(w)

	// Overall status
	if failed == 0 {
		fmt.Fprintln(w, "✅ **All documentation meets readability standards**")
	} else {
		fmt.Fprintf(w, "❌ **%d file(s) failed readability checks**\n", failed)
	}
	fmt.Fprintln(w)

	// Stats table
	fmt.Fprintln(w, "| Metric | Value |")
	fmt.Fprintln(w, "|--------|------:|")
	fmt.Fprintf(w, "| Files analyzed | %d |\n", len(results))
	fmt.Fprintf(w, "| Passed | %d |\n", passed)
	fmt.Fprintf(w, "| Failed | %d |\n", failed)
	fmt.Fprintf(w, "| Total words | %d |\n", totalWords)
	fmt.Fprintf(w, "| Total lines | %d |\n", totalLines)
	fmt.Fprintf(w, "| Avg reading time | %d min |\n", totalWords/200)
	fmt.Fprintln(w)

	// Failed files list if any
	if failed > 0 {
		fmt.Fprintln(w, "### Files Requiring Attention")
		fmt.Fprintln(w)
		fmt.Fprintln(w, "| File | FK Grade | Issue |")
		fmt.Fprintln(w, "|------|:--------:|-------|")

		for _, r := range results {
			if r.Status == "fail" {
				issue := identifyIssue(r)
				fmt.Fprintf(w, "| `%s` | %.1f | %s |\n", r.File, r.Readability.FleschKincaidGrade, issue)
			}
		}
	}

	// Readability distribution
	fmt.Fprintln(w)
	fmt.Fprintln(w, "### Readability Distribution")
	fmt.Fprintln(w)
	dist := calculateDistribution(results)
	fmt.Fprintln(w, "| Level | Count | Percentage |")
	fmt.Fprintln(w, "|-------|------:|-----------:|")
	for _, d := range dist {
		fmt.Fprintf(w, "| %s | %d | %.0f%% |\n", d.Label, d.Count, d.Percent)
	}
}

func aggregateCounts(results []*analyzer.Result) (passed, failed, totalWords, totalLines int) {
	for _, r := range results {
		if r.Status == "pass" {
			passed++
		} else {
			failed++
		}
		totalWords += r.Structural.Words
		totalLines += r.Structural.Lines
	}
	return
}

func identifyIssue(r *analyzer.Result) string {
	issues := []string{}

	if r.Readability.FleschKincaidGrade > 14 {
		issues = append(issues, "Grade level too high")
	}
	if r.Readability.ARI > 14 {
		issues = append(issues, "ARI too high")
	}
	if r.Readability.FleschReadingEase < 30 {
		issues = append(issues, "Reading ease too low")
	}
	if r.Structural.Lines > 375 {
		issues = append(issues, "Too many lines")
	}

	if len(issues) == 0 {
		return "Threshold exceeded"
	}
	return issues[0]
}

type distribution struct {
	Label   string
	Count   int
	Percent float64
}

func calculateDistribution(results []*analyzer.Result) []distribution {
	counts := map[string]int{
		"Very Easy (90+)":       0,
		"Easy (80-89)":          0,
		"Fairly Easy (70-79)":   0,
		"Standard (60-69)":      0,
		"Fairly Difficult (50-59)": 0,
		"Difficult (30-49)":     0,
		"Very Difficult (<30)":  0,
	}

	for _, r := range results {
		score := r.Readability.FleschReadingEase
		switch {
		case score >= 90:
			counts["Very Easy (90+)"]++
		case score >= 80:
			counts["Easy (80-89)"]++
		case score >= 70:
			counts["Fairly Easy (70-79)"]++
		case score >= 60:
			counts["Standard (60-69)"]++
		case score >= 50:
			counts["Fairly Difficult (50-59)"]++
		case score >= 30:
			counts["Difficult (30-49)"]++
		default:
			counts["Very Difficult (<30)"]++
		}
	}

	total := float64(len(results))
	order := []string{
		"Very Easy (90+)",
		"Easy (80-89)",
		"Fairly Easy (70-79)",
		"Standard (60-69)",
		"Fairly Difficult (50-59)",
		"Difficult (30-49)",
		"Very Difficult (<30)",
	}

	dist := make([]distribution, 0, len(order))
	for _, label := range order {
		count := counts[label]
		if count > 0 {
			dist = append(dist, distribution{
				Label:   label,
				Count:   count,
				Percent: float64(count) / total * 100,
			})
		}
	}
	return dist
}
