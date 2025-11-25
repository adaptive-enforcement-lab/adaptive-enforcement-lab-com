# Contributing

Contributions to Adaptive Enforcement Lab documentation are welcome.

## Quick Start

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Development Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install mkdocs-material
mkdocs serve
```

## Documentation Standards

### Writing Style

- Tactical and direct
- Short sentences, real verbs
- Educational without being preachy
- Code examples over lengthy explanations

### Formatting

- Use MkDocs Material admonitions for tips, warnings, and examples
- Mermaid diagrams use Ghostty Hardcore theme colors
- YAML for workflow examples, bash for scripts
- Tables for permissions and configuration options

### Mermaid Diagrams

Apply the Ghostty Hardcore color palette:

```text
Background:  #1b1d1e
Foreground:  #f8f8f3
Orange:      #fd971e
Cyan:        #65d9ef
Purple:      #9e6ffe
Green:       #a7e22e
Pink:        #f92572
Gray:        #515354
```

### File Structure

New operator manual content goes in `docs/operator-manual/`. Group related topics into directories with an `index.md` overview.

## Pre-commit Hooks

The repository uses markdownlint. Run `pre-commit install` to set up hooks locally.

## Pull Requests

- Clear, descriptive titles
- Reference any related issues
- One logical change per PR
- Ensure `mkdocs build` succeeds

## Questions

Open an issue for questions or discussion.
