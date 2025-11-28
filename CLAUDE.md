# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Brand Brief

### Mission

To turn secure development into an enforced standard, not an afterthought.

### Audience

- DevSecOps engineers and platform teams
- Security-conscious developers
- Organizations scaling secure CI/CD practices
- Teams building or managing GitHub-based automation

### Core Principles

1. **Security by Default** - Guardrails should be built-in, not bolted on
2. **Automation Over Documentation** - Enforce standards through pipelines, not policies
3. **Visibility and Accountability** - Every action should be traceable and auditable
4. **Minimal Friction, Maximum Control** - Balance developer velocity with security posture

### Differentiators

- Real-world operational knowledge, not theoretical frameworks
- Patterns tested in production across enterprise environments
- Focus on enforcement mechanisms, not just recommendations
- Open-source tooling and transparent methodology

### AI Tone Guidance

Use a tone that is:

- Tactical but intelligent
- Bold but not hostile
- Educational without being preachy
- Modern, with short sentences and real verbs
- Styled for DevSecOps culture, with light touches of hacker/special-forces ethos

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
├── about.md                    # About page
├── roadmap.md                  # Roadmap
├── assets/
│   └── ael-logo.png            # Site logo and favicon
├── stylesheets/
│   └── extra.css               # Mermaid dark mode fixes
└── operator-manual/
    └── github-actions/
        ├── github-app-setup/
        │   ├── index.md              # Overview
        │   ├── creating-the-app.md   # App creation guide
        │   ├── storing-credentials.md
        │   ├── permission-patterns.md
        │   ├── security-best-practices.md
        │   ├── installation-scopes.md
        │   ├── common-permissions.md
        │   ├── troubleshooting.md
        │   └── maintenance.md
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

## Blog Post Standards

See [CONTRIBUTING.md](CONTRIBUTING.md#blog-posts) for full details.

**Key rules:**

- **Frontmatter `description`** - Required for RSS feeds and social sharing
- **`<!-- more -->` marker** - Separates RSS excerpt from full content
- **Clean excerpts** - No admonitions or Mermaid above the `<!-- more -->` marker (RSS readers won't render them)
- **Excerpt-only feeds** - Industry standard; full content stays on the site

**Template:**

```yaml
---
date: YYYY-MM-DD
authors:
  - mark
categories:
  - DevSecOps
description: >-
  Concise summary for RSS and social. Under 160 chars.
slug: url-friendly-slug
---
```
