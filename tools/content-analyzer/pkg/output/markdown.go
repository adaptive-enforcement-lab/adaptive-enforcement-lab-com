package output

import (
	"fmt"
	"io"
	"sort"
	"strings"

	"github.com/adaptive-enforcement-lab/content-analyzer/pkg/analyzer"
)

// cleanPath strips relative path prefixes for cleaner display.
func cleanPath(path string) string {
	// Strip leading ../ sequences
	for strings.HasPrefix(path, "../") {
		path = path[3:]
	}
	// Strip leading ./
	path = strings.TrimPrefix(path, "./")
	return path
}

// Markdown writes full results as a GitHub-flavored markdown report.
func Markdown(w io.Writer, results []*analyzer.Result) {
	passed, failed, totalWords, totalLines := aggregateCounts(results)

	// Summary table
	fmt.Fprintln(w, "| Metric | Value |")
	fmt.Fprintln(w, "|--------|------:|")
	fmt.Fprintf(w, "| Files | %d |\n", len(results))
	fmt.Fprintf(w, "| Passed | %d |\n", passed)
	fmt.Fprintf(w, "| Failed | %d |\n", failed)
	fmt.Fprintf(w, "| Words | %d |\n", totalWords)
	fmt.Fprintf(w, "| Lines | %d |\n", totalLines)
	fmt.Fprintf(w, "| Reading time | %d min |\n", totalWords/200)
	fmt.Fprintln(w)

	// Sort by status (failed first), then by file path
	sorted := make([]*analyzer.Result, len(results))
	copy(sorted, results)
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].Status != sorted[j].Status {
			return sorted[i].Status == "fail"
		}
		return sorted[i].File < sorted[j].File
	})

	// Results table
	fmt.Fprintln(w, "| Status | File | Lines | Read | FK Grade | ARI | Flesch |")
	fmt.Fprintln(w, "|:------:|------|------:|-----:|---------:|----:|-------:|")

	for _, r := range sorted {
		status := "✅"
		if r.Status == "fail" {
			status = "❌"
		}
		readTime := readingTime(r.Structural.Words)
		fmt.Fprintf(w, "| %s | %s | %d | %s | %.1f | %.1f | %.1f |\n",
			status,
			cleanPath(r.File),
			r.Structural.Lines,
			readTime,
			r.Readability.FleschKincaidGrade,
			r.Readability.ARI,
			r.Readability.FleschReadingEase,
		)
	}
}

// readingTime formats word count as reading time estimate.
func readingTime(words int) string {
	minutes := words / 200
	if minutes < 1 {
		return "<1m"
	}
	return fmt.Sprintf("%dm", minutes)
}

// Summary writes only an aggregate summary in markdown format.
func Summary(w io.Writer, results []*analyzer.Result) {
	passed, failed, totalWords, totalLines := aggregateCounts(results)

	// Overall status
	if failed == 0 {
		fmt.Fprintln(w, "✅ **All files pass readability checks**")
	} else {
		fmt.Fprintf(w, "❌ **%d file(s) failed**\n", failed)
	}
	fmt.Fprintln(w)

	// Summary table
	fmt.Fprintln(w, "| Metric | Value |")
	fmt.Fprintln(w, "|--------|------:|")
	fmt.Fprintf(w, "| Files | %d |\n", len(results))
	fmt.Fprintf(w, "| Passed | %d |\n", passed)
	fmt.Fprintf(w, "| Failed | %d |\n", failed)
	fmt.Fprintf(w, "| Words | %d |\n", totalWords)
	fmt.Fprintf(w, "| Lines | %d |\n", totalLines)
	fmt.Fprintf(w, "| Reading time | %d min |\n", totalWords/200)
	fmt.Fprintln(w)

	// Failed files list if any
	if failed > 0 {
		fmt.Fprintln(w, "### Failed Files")
		fmt.Fprintln(w)
		fmt.Fprintln(w, "| File | FK Grade | ARI | Issue |")
		fmt.Fprintln(w, "|------|:--------:|:---:|-------|")

		for _, r := range results {
			if r.Status == "fail" {
				issue := identifyIssue(r)
				fmt.Fprintf(w, "| %s | %.1f | %.1f | %s |\n",
					cleanPath(r.File),
					r.Readability.FleschKincaidGrade,
					r.Readability.ARI,
					issue,
				)
			}
		}
		fmt.Fprintln(w)
	}

	// Readability distribution
	fmt.Fprintln(w, "### Distribution")
	fmt.Fprintln(w)
	dist := calculateDistribution(results)
	fmt.Fprintln(w, "| Level | Count | % |")
	fmt.Fprintln(w, "|-------|------:|--:|")
	for _, d := range dist {
		fmt.Fprintf(w, "| %s | %d | %.0f |\n", d.Label, d.Count, d.Percent)
	}
}

// Report writes a standalone markdown report suitable for job summaries.
// This is the recommended format for CI integration.
func Report(w io.Writer, results []*analyzer.Result) {
	passed, failed, totalWords, totalLines := aggregateCounts(results)

	fmt.Fprintln(w, "## Documentation Readability")
	fmt.Fprintln(w)

	// Status badge
	if failed == 0 {
		fmt.Fprintln(w, "✅ All files pass")
	} else {
		fmt.Fprintf(w, "❌ %d/%d failed\n", failed, len(results))
	}
	fmt.Fprintln(w)

	// Summary table
	fmt.Fprintln(w, "| Metric | Value |")
	fmt.Fprintln(w, "|--------|------:|")
	fmt.Fprintf(w, "| Files | %d |\n", len(results))
	fmt.Fprintf(w, "| Passed | %d |\n", passed)
	fmt.Fprintf(w, "| Failed | %d |\n", failed)
	fmt.Fprintf(w, "| Words | %d |\n", totalWords)
	fmt.Fprintf(w, "| Lines | %d |\n", totalLines)
	fmt.Fprintf(w, "| Reading time | ~%d min |\n", totalWords/200)
	fmt.Fprintln(w)

	// Only show failed files in report (keep it concise)
	if failed > 0 {
		fmt.Fprintln(w, "### Files Requiring Attention")
		fmt.Fprintln(w)
		fmt.Fprintln(w, "| File | FK | ARI | Issue |")
		fmt.Fprintln(w, "|------|---:|----:|-------|")

		for _, r := range results {
			if r.Status == "fail" {
				issue := identifyIssue(r)
				fmt.Fprintf(w, "| %s | %.1f | %.1f | %s |\n",
					cleanPath(r.File),
					r.Readability.FleschKincaidGrade,
					r.Readability.ARI,
					issue,
				)
			}
		}
		fmt.Fprintln(w)
	}

	// Distribution (collapsed for brevity)
	fmt.Fprintln(w, "<details>")
	fmt.Fprintln(w, "<summary>Readability Distribution</summary>")
	fmt.Fprintln(w)
	dist := calculateDistribution(results)
	fmt.Fprintln(w, "| Level | Count | % |")
	fmt.Fprintln(w, "|-------|------:|--:|")
	for _, d := range dist {
		fmt.Fprintf(w, "| %s | %d | %.0f |\n", d.Label, d.Count, d.Percent)
	}
	fmt.Fprintln(w, "</details>")
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
		"Very Easy (90+)":          0,
		"Easy (80-89)":             0,
		"Fairly Easy (70-79)":      0,
		"Standard (60-69)":         0,
		"Fairly Difficult (50-59)": 0,
		"Difficult (30-49)":        0,
		"Very Difficult (<30)":     0,
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
