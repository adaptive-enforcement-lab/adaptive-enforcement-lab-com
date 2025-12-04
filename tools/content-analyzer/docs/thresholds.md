# Readability Thresholds

## Default Thresholds

The content analyzer uses these default thresholds:

| Metric | Default | Description |
|--------|---------|-------------|
| **Max FK Grade** | 14.0 | Maximum Flesch-Kincaid grade level |
| **Max ARI** | 14.0 | Maximum Automated Readability Index |
| **Max Gunning Fog** | 17.0 | Maximum Gunning Fog score |
| **Min Flesch Ease** | 30.0 | Minimum Flesch Reading Ease score |
| **Max Lines** | 375 | Maximum lines per file |

## CLI Override Flags

```bash
content-analyzer docs/ --check \
  --max-grade 12 \
  --max-ari 12 \
  --max-lines 400
```

## Recommended Targets by Document Type

| Document Type | FK Grade | ARI | Flesch Ease | Rationale |
|---------------|----------|-----|-------------|-----------|
| **Quickstart guides** | 6-8 | 6-8 | 60-70 | Accessible to all skill levels |
| **Tutorials** | 8-10 | 8-10 | 50-60 | Step-by-step learning |
| **Concept guides** | 10-12 | 10-12 | 40-50 | Deeper technical understanding |
| **API reference** | 10-14 | 10-14 | 30-50 | Technical precision required |
| **Troubleshooting** | 8-10 | 8-10 | 50-60 | Clarity under pressure |

## Code Block Handling

Technical documentation contains significant code blocks which are:

1. **Excluded from readability calculations** - Code is not prose
2. **Tracked separately** - Code-to-prose ratio is reported
3. **Not counted** toward grade levels

This prevents code examples from artificially inflating difficulty scores.

## Status Determination

A file receives `fail` status if ANY threshold is exceeded:

```go
if r.Readability.FleschKincaidGrade > thresholds.MaxFleschKincaidGrade {
    return "fail"
}
if r.Readability.ARI > thresholds.MaxARI {
    return "fail"
}
if r.Readability.GunningFog > thresholds.MaxGunningFog {
    return "fail"
}
if r.Readability.FleschReadingEase < thresholds.MinFleschReadingEase {
    return "fail"
}
if thresholds.MaxLines > 0 && r.Structural.Lines > thresholds.MaxLines {
    return "fail"
}
return "pass"
```

## Configuration File (Planned)

Future versions will support `.content-analyzer.yml`:

```yaml
thresholds:
  max_grade: 12
  max_ari: 12
  max_lines: 400

overrides:
  docs/api-reference/:
    max_grade: 14
  docs/quickstart/:
    max_grade: 8
```
