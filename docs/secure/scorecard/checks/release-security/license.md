---
description: >-
  Complete remediation guide for OpenSSF Scorecard License check.
  Add OSI-approved license for legal clarity and open source compliance.
tags:

  - scorecard
  - license
  - legal

---

# License Check

!!! tip "Key Insight"
    License declarations enable legal compliance and dependency auditing.

**Target**: 10/10 by adding LICENSE file

**What it checks**: Whether repository contains a LICENSE file with OSI-approved or FSF-recognized license.

**Why it matters**: Without a license, users have no legal right to use, modify, or distribute your code. Explicit licensing is required for open source adoption and enterprise procurement.

## Understanding the Score

Scorecard looks for:

- `LICENSE` file in repository root
- `LICENSE.md` or `LICENSE.txt` variants
- Recognized license text (MIT, Apache-2.0, GPL, BSD, etc.)

**Scoring**:

- **10/10**: LICENSE file detected with recognized license
- **0/10**: No LICENSE file found

**Note**: This check is binary (0 or 10).

### Before: No License

```bash
$ ls -la
README.md
src/
tests/

```bash
**Legal status**: All rights reserved. Users cannot legally use or distribute code.

**Scorecard result**: License 0/10

### After: License File Added

```bash
$ ls -la
README.md
LICENSE          ← OSI-approved license
src/
tests/

```bash
**Legal status**: Users have explicit rights defined by license.

**Scorecard result**: License 10/10

### Common License Choices

#### MIT License (Permissive)

**Best for**: Most open source projects, maximum adoption

**Permissions**: Commercial use, modification, distribution, private use

**Conditions**: Include copyright notice and license text

**File**: `LICENSE`

```text
MIT License

Copyright (c) 2025 Your Name

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```bash
#### Apache License 2.0 (Permissive with Patent Grant)

**Best for**: Projects where patent protection matters

**Permissions**: Same as MIT, plus explicit patent grant

**Conditions**: Include copyright notice, license text, and state changes

**Why Apache over MIT**: Includes explicit patent grant protecting users from patent claims.

#### GNU GPL v3 (Copyleft)

**Best for**: Projects requiring derivative works to remain open source

**Permissions**: Commercial use, modification, distribution

**Conditions**: Derivatives must use same license (copyleft)

**Trade-off**: Limits adoption in proprietary software.

#### BSD 3-Clause (Permissive)

**Best for**: Academic and research projects

**Permissions**: Similar to MIT

**Conditions**: Cannot use project name in endorsements without permission

### Adding a License

#### Via GitHub UI

1. Go to repository on github.com
2. Click "Add file" → "Create new file"
3. Type `LICENSE` as filename
4. GitHub shows "Choose a license template" button
5. Select license (MIT, Apache-2.0, GPL, etc.)
6. Fill in year and name
7. Commit directly to main

#### Via Command Line

```bash
# Download MIT license template

curl https://raw.githubusercontent.com/licenses/license-templates/master/templates/mit.txt \
  -o LICENSE

# Customize year and name

sed -i 's/\[year\]/2025/g' LICENSE
sed -i 's/\[fullname\]/Your Name/g' LICENSE

# Commit

git add LICENSE
git commit -m "Add MIT License"
git push

```bash
#### Via license CLI Tool

```bash
# Install license CLI

go install github.com/nishanths/license/v5@latest

# Generate MIT license

license -o LICENSE mit

# Or Apache-2.0

license -o LICENSE apache

```bash
### License in package.json (npm)

```json
{
  "name": "your-package",
  "version": "1.2.3",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/your-org/your-repo"
  }
}

```bash
### License in setup.py (Python)

```python
setup(
    name="your-package",
    version="1.2.3",
    license="MIT",
    classifiers=[
        "License :: OSI Approved :: MIT License",
    ],
)

```bash
### License in Cargo.toml (Rust)

```toml
[package]
name = "your-package"
version = "1.2.3"
license = "MIT OR Apache-2.0"

```bash
### License in go.mod (Go)

Go doesn't include license in `go.mod`, but package registries (pkg.go.dev) detect LICENSE file automatically.

### Troubleshooting

#### Issue: LICENSE file exists but Scorecard shows 0/10

**Cause**: License text not recognized.

**Fix**: Use standard license template from <https://choosealicense.com> or GitHub's license picker.

#### Issue: Custom license not detected

**Cause**: Scorecard only recognizes OSI-approved and FSF licenses.

**Fix**: Use standard license. If you need custom terms, use dual licensing:

```text
LICENSE          ← Standard license (MIT, Apache)
LICENSE.CUSTOM   ← Your custom terms

```bash
Reference both in README.md.

#### Issue: Multiple license files (LICENSE and COPYING)

**Cause**: Different naming conventions.

**Fix**: Pick one. Scorecard recognizes `LICENSE`, `LICENSE.md`, `LICENSE.txt`, `COPYING`.

### Remediation Steps

**Time estimate**: 15 minutes

**Step 1: Choose license** (5 minutes)

Visit <https://choosealicense.com>:

- **MIT**: Maximum freedom, minimal restrictions
- **Apache-2.0**: Patent protection for users
- **GPL-3.0**: Requires derivatives to stay open source

**Step 2: Add LICENSE file** (5 minutes)

Via GitHub UI or command line (see "Adding a License" section above).

**Step 3: Update package metadata** (5 minutes)

Add license field to `package.json`, `setup.py`, `Cargo.toml`, etc.

**Step 4: Validate Scorecard** (5 minutes)

Run Scorecard:

```bash
docker run -e GITHUB_TOKEN=$GITHUB_TOKEN gcr.io/openssf/scorecard:stable \
  --repo=github.com/your-org/your-repo --show-details | grep License

```bash
Expected: **License 10/10**

---

---

## Related Content

**Other Release Security checks**:

- [Signed-Releases](./signed-releases.md) - SLSA provenance and signatures
- [Packaging](./packaging.md) - Package registry publishing

**Related guides**:

- [Scorecard Index](../../index.md) - Overview of all 18 checks
- [Tier 1 Progression](../../score-progression/tier-1.md) - Quick wins

---

*License is a 5-minute quick win. Add LICENSE file with OSI-approved license for legal clarity.*
