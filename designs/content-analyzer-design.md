---
title: Content Analyzer Design
description: >-
  Design document for a Go-based documentation quality analyzer
  implementing readability metrics and structural analysis.
---

# Content Analyzer Design

A Go-based tool for analyzing documentation quality, readability, and structure.

---

## Overview

The content analyzer computes readability metrics, structural analysis, and quality indicators for markdown documentation. It provides actionable feedback for maintaining consistent, accessible technical content.

---

## Readability Formulas

### Formula Comparison Matrix

| Formula | Input Variables | Output | Best For | Limitations |
|---------|-----------------|--------|----------|-------------|
| **Flesch-Kincaid Grade** | Words, sentences, syllables | US grade level | General content | Syllable counting complexity |
| **Flesch Reading Ease** | Words, sentences, syllables | 0-100 score | Quick assessment | Not grade-aligned |
| **Gunning Fog** | Words, sentences, complex words | Years of education | Business/professional | Overestimates technical docs |
| **SMOG** | Polysyllabic words, sentences | Years of education | Healthcare/safety | Requires 30+ sentences |
| **Coleman-Liau** | Characters, words, sentences | US grade level (1-12) | Technical docs | Capped at grade 12 |
| **Automated Readability Index** | Characters, words, sentences | US grade level | Machine analysis | Character-based only |

### Selected Formulas for Implementation

**Primary metrics** (implement first):

1. **Flesch-Kincaid Grade Level** - Industry standard, widely understood
2. **Automated Readability Index (ARI)** - Character-based, easy to compute accurately
3. **Coleman-Liau Index** - Designed for technical content

**Secondary metrics** (implement later):

4. **Gunning Fog Index** - Useful for professional content
5. **SMOG Index** - Valuable for safety-critical documentation

### Formula Definitions

#### Flesch-Kincaid Grade Level

```
FK = 0.39 × (words/sentences) + 11.8 × (syllables/words) − 15.59
```

Interpretation: US grade level required to understand the text.

#### Flesch Reading Ease

```
FRE = 206.835 − 1.015 × (words/sentences) − 84.6 × (syllables/words)
```

| Score | Difficulty | Audience |
|-------|------------|----------|
| 90-100 | Very Easy | 5th grade |
| 80-89 | Easy | 6th grade |
| 70-79 | Fairly Easy | 7th grade |
| 60-69 | Standard | 8th-9th grade |
| 50-59 | Fairly Difficult | 10th-12th grade |
| 30-49 | Difficult | College |
| 0-29 | Very Difficult | College graduate |

#### Automated Readability Index (ARI)

```
ARI = 4.71 × (characters/words) + 0.5 × (words/sentences) − 21.43
```

Advantage: Character-based counting is deterministic (no syllable ambiguity).

#### Coleman-Liau Index

```
CLI = 0.0588 × L − 0.296 × S − 15.8
```

Where:

- `L` = average letters per 100 words
- `S` = average sentences per 100 words

Advantage: Designed for technical documents, character-based.

#### Gunning Fog Index

```
Fog = 0.4 × ((words/sentences) + 100 × (complex_words/words))
```

Where `complex_words` = words with 3+ syllables (excluding proper nouns, compounds, common suffixes).

#### SMOG Index

```
SMOG = 1.0430 × √(polysyllables × (30/sentences)) + 3.1291
```

Where `polysyllables` = words with 3+ syllables in a 30-sentence sample.

---

## Target Thresholds for DevSecOps Documentation

### Recommended Readability Targets

| Document Type | FK Grade | ARI | Flesch Ease | Rationale |
|---------------|----------|-----|-------------|-----------|
| **Quickstart guides** | 6-8 | 6-8 | 60-70 | Accessible to all skill levels |
| **Tutorials** | 8-10 | 8-10 | 50-60 | Step-by-step learning |
| **Concept guides** | 10-12 | 10-12 | 40-50 | Deeper technical understanding |
| **API reference** | 10-14 | 10-14 | 30-50 | Technical precision required |
| **Troubleshooting** | 8-10 | 8-10 | 50-60 | Clarity under pressure |

### Industry Benchmarks

| Source | Target Grade Level | Notes |
|--------|-------------------|-------|
| [Microsoft Style Guide](https://learn.microsoft.com/en-us/style-guide/) | 8-10 | "Clean, simple, crisp and clear" |
| [Google Developer Docs](https://developers.google.com/style) | 8-10 | "Conversational, friendly" |
| US Government (Plain Language Act) | 6-8 | Legal requirement for public docs |
| [MIL-STD-38784](http://everyspec.com/MIL-STD/MIL-STD-10000-and-Up/MIL-STD-38784B_57086/) | 8-10 | Military technical manuals |

### Code Block Handling

Technical documentation contains significant code blocks which should be:

1. **Excluded from readability calculations** - Code is not prose
2. **Tracked separately** - Code-to-prose ratio is a useful metric
3. **Analyzed for comments** - Inline comments affect understanding

---

## Structural Metrics

### Heading Analysis

```go
type HeadingMetrics struct {
    H1Count     int
    H2Count     int
    H3Count     int
    H4Count     int
    MaxDepth    int
    Violations  []string  // e.g., "H4 without parent H3"
}
```

Validation rules:

- Exactly one H1 per document
- No heading level skips (H2 → H4)
- Reasonable section balance (no 500-line H2 sections)

### Section Balance

```go
type SectionMetrics struct {
    TotalSections   int
    AvgLinesPerSection int
    MaxLinesSection    int
    MinLinesSection    int
    ImbalanceWarnings  []string
}
```

### Content Composition

```go
type CompositionMetrics struct {
    TotalLines      int
    ProseLines      int
    CodeLines       int
    ListLines       int
    TableLines      int
    EmptyLines      int
    CodeBlockRatio  float64  // CodeLines / TotalLines
    ListDensity     float64  // ListLines / ProseLines
}
```

---

## Go Implementation Architecture

### Package Structure

```
cmd/
  content-analyzer/
    main.go              # CLI entry point, cobra setup
pkg/
  analyzer/
    analyzer.go          # Core orchestration
    types.go             # Metric types and result structs
  markdown/
    parser.go            # Goldmark-based markdown parsing
    extractor.go         # Extract prose, code blocks, headings
  output/
    json.go              # JSON output format
    table.go             # CLI table output
```

The structure is simplified because `textstats` handles all readability calculations internally. Our code focuses on:

1. **Markdown parsing** - Extract prose content, excluding code blocks
2. **Structural analysis** - Heading counts, line metrics, composition
3. **Output formatting** - Table and JSON formats for CLI and CI

### Core Dependencies

| Library | Purpose | License |
|---------|---------|---------|
| [darkliquid/textstats](https://github.com/darkliquid/textstats) | Readability metrics (FK, ARI, Coleman-Liau, Gunning-Fog, SMOG, Dale-Chall) | MIT |
| [goldmark](https://github.com/yuin/goldmark) | Markdown parsing, code block extraction | MIT |
| [cobra](https://github.com/spf13/cobra) | CLI framework | Apache 2.0 |

### Why textstats?

The `darkliquid/textstats` library provides all readability metrics out of the box:

- Flesch-Kincaid Grade Level & Reading Ease
- Automated Readability Index (ARI)
- Coleman-Liau Index
- Gunning-Fog Index
- SMOG Index
- Dale-Chall Readability

It handles syllable counting internally, supports `io.Reader` for streaming, and is a mature port of the well-tested TextStatistics.js library.

```go
import "github.com/darkliquid/textstats"

// Analyze prose text (code blocks already stripped)
stats := textstats.NewTextStats(proseContent)

metrics := Readability{
    FleschKincaidGrade: stats.FleschKincaidGradeLevel(),
    FleschReadingEase:  stats.FleschKincaidReadingEase(),
    ARI:                stats.AutomatedReadabilityIndex(),
    ColemanLiau:        stats.ColemanLiauIndex(),
    GunningFog:         stats.GunningFogScore(),
    SMOG:               stats.SMOGIndex(),
}
```

---

## CLI Interface

### Usage Examples

```bash
# Analyze single file
content-analyzer docs/quickstart.md

# Analyze directory
content-analyzer docs/

# JSON output for CI
content-analyzer docs/ --format json

# Check against thresholds (exit 1 on failure)
content-analyzer docs/ --check --max-grade 10

# Verbose with all metrics
content-analyzer docs/ --verbose
```

### Output Formats

#### Default (Table)

```
docs/operator-manual/github-actions/index.md
  Lines: 245 | Words: 1,847 | Reading time: 8 min
  Headers: H1=1 H2=5 H3=12 H4=3
  Readability: FK=10.2 ARI=9.8 Flesch=52.1 (Fairly Difficult)
  Code: 23% | Lists: 15%
  Status: PASS
```

#### JSON

```json
{
  "file": "docs/operator-manual/github-actions/index.md",
  "structural": {
    "lines": 245,
    "words": 1847,
    "sentences": 89,
    "reading_time_minutes": 8
  },
  "headings": {
    "h1": 1, "h2": 5, "h3": 12, "h4": 3
  },
  "readability": {
    "flesch_kincaid_grade": 10.2,
    "ari": 9.8,
    "flesch_reading_ease": 52.1,
    "coleman_liau": 11.3
  },
  "composition": {
    "code_ratio": 0.23,
    "list_density": 0.15
  },
  "status": "pass"
}
```

---

## Integration Points

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
- repo: local
  hooks:
    - id: content-analyzer
      name: check documentation readability
      entry: bin/content-analyzer --check --max-grade 12
      language: system
      files: \.md$
      exclude: ^(CHANGELOG|CONTRIBUTING)\.md$
```

### GitHub Actions

```yaml
- name: Analyze documentation
  run: |
    ./bin/content-analyzer docs/ --format json > readability-report.json

- name: Comment on PR
  if: github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    script: |
      const report = require('./readability-report.json')
      // Format and post comment
```

---

## Development Phases

### Phase 1: MVP

- [ ] Go module setup with dependencies (textstats, goldmark, cobra)
- [ ] Markdown parser with code block extraction
- [ ] All readability metrics via textstats
- [ ] Basic CLI with table output
- [ ] Single file analysis

### Phase 2: Structural Analysis

- [ ] Heading structure extraction and validation
- [ ] Line count and composition metrics
- [ ] Reading time estimation
- [ ] JSON output format
- [ ] Directory scanning

### Phase 3: Threshold Enforcement

- [ ] `--check` mode with configurable thresholds
- [ ] Exit code 1 on threshold violations
- [ ] Pre-commit hook configuration
- [ ] Aggregate reporting for multiple files

### Phase 4: CI Integration

- [ ] GitHub Actions workflow example
- [ ] PR comment formatting
- [ ] Threshold configuration file (`.content-analyzer.yml`)
- [ ] Per-directory threshold overrides

---

## References

### Readability Research

- [Flesch-Kincaid Readability Tests - Wikipedia](https://en.wikipedia.org/wiki/Flesch–Kincaid_readability_tests)
- [Automated Readability Index - Wikipedia](https://en.wikipedia.org/wiki/Automated_readability_index)
- [Complete Guide to Readability Formulas](https://gorby.app/readability/readability-formulas-guide/)
- [How to Decide Which Readability Formula to Use](https://readabilityformulas.com/how-to-decide-which-readability-formula-to-use/)

### Style Guides

- [Google Developer Documentation Style Guide](https://developers.google.com/style/)
- [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/welcome/)
- [MIL-STD-38784B - Technical Manual Standards](http://everyspec.com/MIL-STD/MIL-STD-10000-and-Up/MIL-STD-38784B_57086/)

### Go Libraries

- [darkliquid/textstats - Readability metrics](https://github.com/darkliquid/textstats)
- [goldmark - Markdown parser](https://github.com/yuin/goldmark)
- [cobra - CLI framework](https://github.com/spf13/cobra)

### Related Issues

- [#57 - Add content analysis tooling](https://github.com/adaptive-enforcement-lab/adaptive-enforcement-lab-com/issues/57)
- [#58 - Market analysis of readability criteria](https://github.com/adaptive-enforcement-lab/adaptive-enforcement-lab-com/issues/58)
