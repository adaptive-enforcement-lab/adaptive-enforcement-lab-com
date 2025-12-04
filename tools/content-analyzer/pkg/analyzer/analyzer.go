package analyzer

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/adaptive-enforcement-lab/content-analyzer/pkg/markdown"
	"github.com/darkliquid/textstats"
)

// Analyzer processes markdown files and computes metrics.
type Analyzer struct {
	Thresholds Thresholds
}

// New creates a new Analyzer with default thresholds.
func New() *Analyzer {
	return &Analyzer{
		Thresholds: DefaultThresholds(),
	}
}

// NewWithThresholds creates an Analyzer with custom thresholds.
func NewWithThresholds(t Thresholds) *Analyzer {
	return &Analyzer{
		Thresholds: t,
	}
}

// AnalyzeFile processes a single markdown file.
func (a *Analyzer) AnalyzeFile(path string) (*Result, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	return a.Analyze(path, content)
}

// Analyze processes markdown content and returns metrics.
func (a *Analyzer) Analyze(path string, content []byte) (*Result, error) {
	// Parse markdown to extract prose and structure
	parsed, err := markdown.Parse(content)
	if err != nil {
		return nil, err
	}

	// Skip frontmatter from prose analysis
	prose := stripFrontmatter(parsed.Prose)

	// Calculate readability metrics using textstats
	// Use the function-based API which takes strings directly
	result := &Result{
		File: path,
		Structural: Structural{
			Lines:              parsed.TotalLines,
			Words:              countWords(prose),
			Sentences:          countSentences(prose),
			Characters:         len(prose),
			ReadingTimeMinutes: calculateReadingTime(countWords(prose)),
		},
		Headings: countHeadings(parsed.Headings),
		Readability: Readability{
			FleschKincaidGrade: textstats.FleschKincaidGradeLevel(prose),
			FleschReadingEase:  textstats.FleschKincaidReadingEase(prose),
			ARI:                textstats.AutomatedReadabilityIndex(prose),
			ColemanLiau:        textstats.ColemanLiauIndex(prose),
			GunningFog:         textstats.GunningFogScore(prose),
			SMOG:               textstats.SMOGIndex(prose),
		},
		Composition: Composition{
			TotalLines:     parsed.TotalLines,
			ProseLines:     parsed.TotalLines - parsed.CodeLines - parsed.EmptyLines,
			CodeLines:      parsed.CodeLines,
			EmptyLines:     parsed.EmptyLines,
			CodeBlockRatio: calculateRatio(parsed.CodeLines, parsed.TotalLines),
		},
	}

	result.Status = a.checkStatus(result)

	return result, nil
}

// AnalyzeDirectory processes all markdown files in a directory.
func (a *Analyzer) AnalyzeDirectory(dir string) ([]*Result, error) {
	var results []*Result

	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			return nil
		}

		if !strings.HasSuffix(strings.ToLower(path), ".md") {
			return nil
		}

		// Skip common files that shouldn't be analyzed
		base := filepath.Base(path)
		if base == "CHANGELOG.md" || base == "CONTRIBUTING.md" {
			return nil
		}

		result, err := a.AnalyzeFile(path)
		if err != nil {
			return err
		}

		results = append(results, result)
		return nil
	})

	return results, err
}

// checkStatus determines pass/fail based on thresholds.
func (a *Analyzer) checkStatus(r *Result) string {
	if r.Readability.FleschKincaidGrade > a.Thresholds.MaxFleschKincaidGrade {
		return "fail"
	}
	if r.Readability.ARI > a.Thresholds.MaxARI {
		return "fail"
	}
	if r.Readability.GunningFog > a.Thresholds.MaxGunningFog {
		return "fail"
	}
	if r.Readability.FleschReadingEase < a.Thresholds.MinFleschReadingEase {
		return "fail"
	}
	if a.Thresholds.MaxLines > 0 && r.Structural.Lines > a.Thresholds.MaxLines {
		return "fail"
	}
	return "pass"
}

// stripFrontmatter removes YAML frontmatter from content.
func stripFrontmatter(content string) string {
	if !strings.HasPrefix(content, "---") {
		return content
	}

	// Find the closing ---
	rest := content[3:]
	idx := strings.Index(rest, "---")
	if idx == -1 {
		return content
	}

	return strings.TrimSpace(rest[idx+3:])
}

// countWords counts words in text.
func countWords(text string) int {
	fields := strings.Fields(text)
	return len(fields)
}

// countSentences estimates sentence count.
func countSentences(text string) int {
	count := 0
	for _, r := range text {
		if r == '.' || r == '!' || r == '?' {
			count++
		}
	}
	if count == 0 && len(text) > 0 {
		return 1
	}
	return count
}

// calculateReadingTime estimates reading time at 200 WPM for technical content.
func calculateReadingTime(words int) int {
	minutes := words / 200
	if minutes == 0 && words > 0 {
		return 1
	}
	return minutes
}

// calculateRatio safely calculates a ratio.
func calculateRatio(part, total int) float64 {
	if total == 0 {
		return 0
	}
	return float64(part) / float64(total)
}

// countHeadings counts headings by level.
func countHeadings(headings []markdown.Heading) Headings {
	h := Headings{}
	for _, heading := range headings {
		switch heading.Level {
		case 1:
			h.H1++
		case 2:
			h.H2++
		case 3:
			h.H3++
		case 4:
			h.H4++
		case 5:
			h.H5++
		case 6:
			h.H6++
		}
	}
	return h
}
