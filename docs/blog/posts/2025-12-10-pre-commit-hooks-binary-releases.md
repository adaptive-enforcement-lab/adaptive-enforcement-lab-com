---
title: Pre-commit Hooks That Don't Make You Wait
date: 2025-12-10
authors:
  - mark
categories:
  - Go
  - Pre-commit
  - Developer Tools
description: >-
  Binary releases eliminate the 30-second cold start penalty. Ship pre-commit
  hooks developers actually want to use.
slug: pre-commit-hooks-binary-releases
provenance: human
---
# Pre-commit Hooks That Don't Make You Wait

Your first commit after cloning a repo takes 30 seconds. Why? Pre-commit is compiling Go from source.

Binary releases fix this. Ship hooks backed by pre-built binaries.

<!-- more -->

## The Problem with `language: golang`

What happens with `language: golang` hooks:

1. First commit runs `go install` from source
2. User waits 30+ seconds to compile
3. Go version mismatches break builds
4. Network issues fail the install

The result: developers disable pre-commit hooks.

!!! danger "Friction Kills Adoption"
    Every second of delay makes bypass more likely. Developers disable slow hooks.

---

## Binary Release Advantages

| Aspect | Source Build | Binary Release |
| -------- | -------------- | ---------------- |
| First run | 30+ seconds | ~1 second |
| Go required | Yes | No |
| Version issues | Depends on user's Go | Same binary for all |
| Network needs | Fetch modules | One file download |

---

## The .pre-commit-hooks.yaml File

Define hooks in your tool repo.

Two hooks: `readability` runs `readability --check` on every staged markdown file, and `readability-docs` runs `readability --check docs/` once, without file names.
The [pre-commit hook distribution guide](../../build/go-cli-architecture/packaging/pre-commit-hooks.md) has the file.

!!! tip "Two Hook Variants"
    Offer both file-based and directory-based hooks. Projects have different needs.

---

## Key Hook Definition Fields

| Field | Purpose |
| ------- | --------- |
| `id` | Name users put in their config |
| `entry` | Command to execute |
| `language` | Runtime: golang, system, python |
| `files` | Regex to match files |
| `pass_filenames` | Pass matched files as args or not |
| `types` | File type filter |

---

## CLI Design for Pre-commit

### Exit Codes

Pre-commit checks exit codes:

- `0`: All files pass
- `1`: One or more files failed
- Other: Error (config issues, crashes)

`run()` returns an error when `--check` is set and any file failed. `main()` prints it to stderr and exits 1.

### The --check Flag Pattern

Always implement `--check` that:

1. Shows results to the user
2. Exits with code 1 on failure
3. Used by default in hook entry

The hook entry is always `my-tool --check`.

### Accepting Multiple Files

With `pass_filenames: true`, pre-commit passes files as args.

A call looks like `my-tool --check file1.md file2.md docs/guide.md`.

Your CLI must handle this.

Treat each argument as a path, fall back to `.` when there are none, and merge the results before reporting.

---

## GoReleaser Configuration

Build for all platforms.

One binary per OS and architecture: Linux, macOS and Windows on amd64 and arm64, with `CGO_ENABLED=0` and the version set through `ldflags`, packed as `tar.gz`.
The [pre-commit hook distribution guide](../../build/go-cli-architecture/packaging/pre-commit-hooks.md) has the config.

---

## Consumer Configuration

In repos that use your hook.

A consumer lists your repo, a `rev` tag and the hook `id` in `.pre-commit-config.yaml`.

### With Arguments

Add `args`, such as `['--config', '.readability.yml']`.

### Excluding Files

Add `exclude` with a regex such as `'^CHANGELOG\.md$|^vendor/'`.
The [pre-commit hook distribution guide](../../build/go-cli-architecture/packaging/pre-commit-hooks.md) shows the full entry.

---

## Floating Version Tags

Keep floating tags for easy updates.

The release workflow force-moves the major tag, such as `v1`, to each new release with `git tag -f` and `git push -f`.
The [GitHub Actions distribution guide](../../build/go-cli-architecture/packaging/github-actions.md) has the step.

Users can then reference:

```yaml
rev: v1  # Always gets latest v1.x.x
```

---

## Testing Pre-commit Hooks

### Local Testing

Build the tool, run it with `--check` on a few files, and print the exit code.

### Pre-commit Testing

Install the hooks, then `pre-commit run my-tool` with `--all-files`, `--files` or `--verbose`.
The [pre-commit hook distribution guide](../../build/go-cli-architecture/packaging/pre-commit-hooks.md) has the commands.

---

## Helpful Error Messages

Design output for humans and AI agents.

When a file is too long, the CLI prints `IMPORTANT: Split files, don't delete content.` before it returns the failure count.

See [CLI UX Patterns for AI Agents](2025-12-07-cli-ux-patterns-for-ai-agents.md) for more.

---

## Troubleshooting

### Hook Not Found

```text
[ERROR] Repository owner/my-tool does not contain a .pre-commit-hooks.yaml file
```

Make sure `.pre-commit-hooks.yaml` is in your repo.

### Wrong Version Running

Clear the pre-commit cache.

Run `pre-commit clean`, then `pre-commit install`.

### Slow First Run

This is normal for `language: golang`. Users can install the binary globally.

---

## The Payoff

Binary-backed pre-commit hooks provide:

- **Fast**: No compile wait
- **Consistent**: Same binary for all users
- **High adoption**: Devs keep hooks on
- **Better CI**: Same tool runs everywhere

The setup pays off. Better experience for devs. Better code.

---

## Related

- **[Pre-commit Hooks as Security Gates](2025-12-04-pre-commit-security-gates.md)** - Enforce security policies at commit time
- [Building GitHub Actions in Go](2025-12-09-building-github-actions-in-go.md) - Same patterns for GitHub Actions
- [CLI UX Patterns for AI Agents](2025-12-07-cli-ux-patterns-for-ai-agents.md) - Design error messages AI can use
- [golangci-lint v2 Migration](2025-12-11-golangci-lint-v2-migration.md) - Keep your linting current
- [Shipping a GitHub Action the Right Way](2025-12-06-shipping-a-github-action-the-right-way.md) - The action that uses these patterns
