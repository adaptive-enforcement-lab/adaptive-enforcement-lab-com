# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MkDocs Material static site for **adaptive-enforcement-lab.com**, hosted on GitHub Pages. The site serves as the documentation hub for the `adaptive-enforcement-lab` GitHub organization.

## Build Commands

```bash
# Create and activate virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install mkdocs-material

# Local development server (hot reload at http://127.0.0.1:8000)
mkdocs serve

# Build static site to site/
mkdocs build

# Deploy to GitHub Pages
mkdocs gh-deploy
```

## Repository Structure

```text
mkdocs.yml                      # Site configuration
docs/
├── index.md                    # Homepage
├── assets/
│   └── ael-logo.png            # Site logo and favicon
└── operator-manual/
    └── github-actions/
        ├── github-app-setup.md
        ├── actions-integration.md
        └── contributing-distribution.md
```

## Theme Configuration

- **Default mode**: System preference (dark/light), defaults to dark
- **Colors**: Blue primary, teal accent (matches logo)
- **Logo**: `docs/assets/ael-logo.png`

## Current Documentation

The operator manual covers GitHub Actions automation patterns:

- **GitHub Core Apps**: Organization-level GitHub Apps for centralized authentication
- **Token Generation**: Using `actions/create-github-app-token@v2` with `owner: adaptive-enforcement-lab`
- **Distribution Workflows**: Three-stage pattern (Discovery → Distribution → Summary) for cross-repo operations

## Documentation Standards

- Mermaid diagrams use Ghostty Hardcore theme colors
- Code examples use YAML for workflows, bash for scripts
- Tables document permissions, configuration options, and troubleshooting
