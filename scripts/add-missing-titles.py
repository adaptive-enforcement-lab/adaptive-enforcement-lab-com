#!/usr/bin/env python3
"""
Add missing title frontmatter to documentation files.
Extracts title from first H1 heading or generates from file path.
"""

import re
import sys
from pathlib import Path


def extract_h1(content: str) -> str | None:
    """Extract first H1 heading from markdown content."""
    for line in content.split('\n'):
        match = re.match(r'^#\s+(.+)$', line)
        if match:
            return match.group(1).strip()
    return None


def generate_title_from_path(file_path: Path) -> str:
    """Generate title from file path."""
    basename = file_path.stem
    if basename == 'index':
        # Use parent directory name for index files
        basename = file_path.parent.name

    # Convert kebab-case and snake_case to Title Case
    words = re.split(r'[-_]', basename)
    return ' '.join(word.capitalize() for word in words)


def has_frontmatter(content: str) -> bool:
    """Check if content has YAML frontmatter."""
    return content.startswith('---\n')


def extract_frontmatter(content: str) -> tuple[str, str]:
    """Extract frontmatter and body from content."""
    if not has_frontmatter(content):
        return '', content

    # Find the end of frontmatter
    lines = content.split('\n')
    end_idx = None
    for i, line in enumerate(lines[1:], 1):
        if line.strip() == '---':
            end_idx = i
            break

    if end_idx is None:
        return '', content

    frontmatter = '\n'.join(lines[1:end_idx])
    body = '\n'.join(lines[end_idx + 1:])
    return frontmatter, body


def add_title_to_file(file_path: Path):
    """Add title frontmatter to a file."""
    content = file_path.read_text()

    # Determine the title
    title = extract_h1(content)
    if not title:
        title = generate_title_from_path(file_path)

    # Parse frontmatter
    frontmatter, body = extract_frontmatter(content)

    # Check if title already exists
    if re.search(r'^title:', frontmatter, re.MULTILINE):
        print(f"⏭️  Skipping {file_path} (title already exists)")
        return

    # Add title to frontmatter
    if frontmatter:
        new_frontmatter = f"title: {title}\n{frontmatter}"
    else:
        new_frontmatter = f"title: {title}"

    # Reconstruct file
    new_content = f"---\n{new_frontmatter}\n---\n{body.lstrip()}"

    file_path.write_text(new_content)
    print(f"✅ Added title to {file_path}: {title}")


def main():
    """Process all markdown files in docs/."""
    docs_dir = Path('docs')

    # Get all markdown files
    md_files = list(docs_dir.rglob('*.md'))

    # Exclusions
    exclusions = [
        'docs/tags.md',
        'docs/includes/',
    ]

    processed = 0
    for md_file in md_files:
        # Check exclusions
        if any(str(md_file).startswith(exc) for exc in exclusions):
            continue

        add_title_to_file(md_file)
        processed += 1

    print(f"\n✨ Processed {processed} files")


if __name__ == '__main__':
    main()
