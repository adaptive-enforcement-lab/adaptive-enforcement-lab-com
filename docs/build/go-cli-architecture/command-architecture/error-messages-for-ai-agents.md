---
title: Error Messages for AI Agents
description: >-
  Write CLI error output that AI coding agents fix correctly: state the fix, forbid the destructive shortcut, and print guidance only for the failure that occurred.
provenance: human
---
# Error Messages for AI Agents

AI coding agents act on CLI output literally. A message that only states the problem
invites the cheapest fix, which is often deletion. These rules keep agent fixes safe.

!!! abstract "Three Rules"
    State what to do. State what not to do. Print only the guidance that matches the failure.

---

## State the Fix, Not Only the Problem

```go
// Bad: Only describes the problem
fmt.Fprintln(os.Stderr, "Error: Readability score too low")

// Good: Describes problem AND solution approach
fmt.Fprintln(os.Stderr, "READABILITY: High grade level indicates complex sentences.")
fmt.Fprintln(os.Stderr, "- Break long sentences into shorter ones (15-20 words)")
fmt.Fprintln(os.Stderr, "- Add introductory sentences before code blocks")
```

## Forbid the Destructive Shortcut

```go
fmt.Fprintln(os.Stderr, "Do NOT remove content to meet thresholds.")
fmt.Fprintln(os.Stderr, "Do NOT remove technical accuracy. Rewrite for clarity.")
```

## Be Specific

```go
// Bad: Vague
fmt.Fprintln(os.Stderr, "Improve the readability of this document.")

// Good: Specific actions
fmt.Fprintln(os.Stderr, "- Break sentences over 20 words into multiple sentences")
fmt.Fprintln(os.Stderr, "- Add brief explanations before bullet lists")
fmt.Fprintln(os.Stderr, "- Use transitional phrases between dense sections")
```

---

## Contextual Warnings

Count each failure type, and print each block of guidance only when its failure occurred:

```go
func run() error {
    // Analyze files...

    if checkFlag && failed > 0 {
        tooLong := countFilesExceedingLines(results, 375)
        lowReadability := countLowReadability(results)

        if tooLong > 0 {
            fmt.Fprintln(os.Stderr, "")
            fmt.Fprintln(os.Stderr, "IMPORTANT: Files exceeding line limits should be SPLIT.")
            fmt.Fprintln(os.Stderr, "Do NOT remove content. Split by topic or section.")
            fmt.Fprintln(os.Stderr, "")
        }

        if lowReadability > 0 {
            fmt.Fprintln(os.Stderr, "")
            fmt.Fprintln(os.Stderr, "READABILITY: Complex sentence structure detected.")
            fmt.Fprintln(os.Stderr, "- Break long sentences (aim for 15-20 words)")
            fmt.Fprintln(os.Stderr, "- Add context before code blocks and lists")
            fmt.Fprintln(os.Stderr, "Do NOT remove technical content.")
            fmt.Fprintln(os.Stderr, "")
        }

        return fmt.Errorf("%d file(s) failed", failed)
    }
    return nil
}
```

Line-limit guidance on a readability failure is noise, and noise confuses agents.

---

## Templates

### Threshold Exceeded

```text
[CATEGORY]: [Metric] exceeds threshold ([actual] > [max]).

To fix:
- [Specific action 1]
- [Specific action 2]

Do NOT [prohibited shortcut].
```

### Quality Issue

```text
[CATEGORY]: [What the metric indicates].

Improvement strategies:
- [Strategy 1]
- [Strategy 2]

Do NOT [prohibited approach]. [Why it's wrong].
```

---

## Test With an Agent

1. Create a file that fails your checks.
2. Give an AI assistant the error message and the file.
3. Ask it to fix the error.
4. Check the fix restructures instead of deleting.

If the agent deletes content, the message failed.

---

## Related

- [Input/Output Contracts](io-contracts.md) - Output for humans and scripts
- [Designing Error Messages AI Agents Can't Misinterpret](../../../blog/posts/2025-12-07-cli-ux-patterns-for-ai-agents.md) - The story behind these rules
