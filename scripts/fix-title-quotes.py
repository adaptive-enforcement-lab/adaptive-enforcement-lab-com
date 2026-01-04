#!/usr/bin/env python3
"""
Fix YAML frontmatter titles that contain colons by adding quotes.
"""

import re
from pathlib import Path


def fix_title_in_file(file_path: Path):
    """Add quotes around titles that contain colons."""
    content = file_path.read_text()
    lines = content.split('\n')

    modified = False
    for i, line in enumerate(lines):
        # Match unquoted title with colon
        if re.match(r'^title:\s+[^"\'].*:.*[^"\']$', line):
            # Extract the title value
            match = re.match(r'^title:\s+(.+)$', line)
            if match:
                title_value = match.group(1)
                # Only quote if not already quoted
                if not (title_value.startswith('"') or title_value.startswith("'")):
                    lines[i] = f'title: "{title_value}"'
                    modified = True
                    print(f"✅ Quoted title in {file_path}")
                    break

    if modified:
        file_path.write_text('\n'.join(lines))


def main():
    """Fix all blog post titles."""
    blog_dir = Path('docs/blog/posts')

    for md_file in blog_dir.glob('*.md'):
        fix_title_in_file(md_file)

    print("\n✨ Title quoting complete!")


if __name__ == '__main__':
    main()
