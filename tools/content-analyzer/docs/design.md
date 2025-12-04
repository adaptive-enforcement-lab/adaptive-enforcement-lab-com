# Content Analyzer Design

A Go-based tool for analyzing documentation quality, readability, and structure.

## Overview

The content analyzer computes readability metrics, structural analysis, and quality
indicators for markdown documentation. It provides actionable feedback for maintaining
consistent, accessible technical content.

## Architecture

```
cmd/
  content-analyzer/
    main.go              # CLI entry point, cobra setup
pkg/
  analyzer/
    analyzer.go          # Core orchestration
    types.go             # Metric types and result structs
    thresholds.go        # Default and configurable thresholds
  markdown/
    parser.go            # Goldmark-based markdown parsing
  output/
    json.go              # JSON output format
    table.go             # CLI table output
    markdown.go          # Markdown table output for CI
```

## Dependencies

| Library | Purpose | License |
|---------|---------|---------|
| [darkliquid/textstats](https://github.com/darkliquid/textstats) | Readability metrics | MIT |
| [goldmark](https://github.com/yuin/goldmark) | Markdown parsing | MIT |
| [cobra](https://github.com/spf13/cobra) | CLI framework | Apache 2.0 |

## Usage

```bash
# Analyze single file
content-analyzer docs/quickstart.md

# Analyze directory
content-analyzer docs/

# JSON output for CI
content-analyzer docs/ --format json

# Markdown output for GitHub Actions job summary
content-analyzer docs/ --format markdown

# Aggregate summary only
content-analyzer docs/ --format summary

# Check against thresholds (exit 1 on failure)
content-analyzer docs/ --check --max-grade 12

# Verbose with all metrics
content-analyzer docs/ --verbose
```

## Related Documentation

- [Readability Formulas](readability-formulas.md) - Formula definitions and benchmarks
- [Thresholds](thresholds.md) - Target values for different document types
- [Integration](integration.md) - Pre-commit and GitHub Actions setup

## Related Issues

- [#57 - Add content analysis tooling](https://github.com/adaptive-enforcement-lab/adaptive-enforcement-lab-com/issues/57)
- [#58 - Market analysis of readability criteria](https://github.com/adaptive-enforcement-lab/adaptive-enforcement-lab-com/issues/58)
