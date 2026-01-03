---
description: >-
  Complete remediation guide for OpenSSF Scorecard Fuzzing check.
  Integrate continuous fuzz testing with OSS-Fuzz or ClusterFuzzLite.
tags:

  - scorecard
  - fuzzing
  - security-testing

---

# Fuzzing Check

!!! tip "Key Insight"
    Fuzzing automatically discovers edge cases that manual testing misses.

**Target**: 10/10 by integrating continuous fuzzing

**What it checks**: Whether project uses automated fuzz testing to discover vulnerabilities.

**Why it matters**: Fuzzing discovers edge cases and vulnerabilities that unit tests miss. Critical for parsing untrusted input (file formats, network protocols, user data).

## Understanding the Score

Scorecard looks for:

- OSS-Fuzz integration (Google's continuous fuzzing service)
- ClusterFuzzLite in CI/CD
- Language-specific fuzzing frameworks (libFuzzer, go-fuzz, etc.)

**Scoring**:

- 10/10: Active OSS-Fuzz integration or ClusterFuzzLite in CI
- 5/10: Fuzzing configuration exists but not active
- 0/10: No fuzzing detected

**Important**: This is one of the **hardest** checks to achieve because fuzzing requires:

1. Writing fuzz targets
2. Integrating fuzzing infrastructure
3. Continuous execution (not one-time)

### When Fuzzing Matters

**High value for**:

- Parsers (JSON, XML, YAML, binary formats)
- Network protocol implementations
- Cryptographic libraries
- Compilers and interpreters
- Image/video/audio processing
- Archive handlers (zip, tar, etc.)

**Low value for**:

- Business logic applications
- Simple CRUD APIs
- Thin wrappers around other libraries
- Projects with minimal untrusted input

**Reality check**: Many projects score 0/10 on Fuzzing and it's fine. Only implement if your project handles untrusted input in security-critical ways.

### OSS-Fuzz (Recommended for Eligible Projects)

**OSS-Fuzz** is Google's continuous fuzzing service for open source projects.

**Requirements**:

- Project is open source
- Project has significant user base or critical infrastructure role
- Maintainers commit to fixing fuzzing-discovered bugs

**Application process**:

1. Create fuzz targets for your project
2. Submit integration PR to google/oss-fuzz repository
3. Google reviews and accepts
4. Fuzzing runs continuously on Google infrastructure

**Benefits**:

- Free continuous fuzzing
- Automatic bug reporting (private security issues)
- Coverage-guided fuzzing with LibFuzzer/AFL
- Massive CPU resources

**Detailed guide**: [OSS-Fuzz documentation](https://google.github.io/oss-fuzz/)

### ClusterFuzzLite (Run in Your CI)

**ClusterFuzzLite** brings OSS-Fuzz capabilities to your own CI/CD.

**Advantages**:

- No application process needed
- Works for private repositories
- You control compute resources

**Setup** (GitHub Actions):

Create `.github/workflows/fuzz.yml`:

```yaml
name: ClusterFuzzLite

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:

    - cron: '0 0 * * *'  # Daily fuzzing

permissions:
  contents: read
  issues: write  # File issues for crashes

jobs:
  fuzz:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        sanitizer: [address, undefined, memory]
    steps:

      - name: Checkout

        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - name: Build Fuzz Targets

        id: build
        uses: google/clusterfuzzlite/actions/build_fuzzers@v1
        with:
          language: c++  # or go, python, rust, etc.
          sanitizer: ${{ matrix.sanitizer }}

      - name: Run Fuzz Targets

        id: run
        uses: google/clusterfuzzlite/actions/run_fuzzers@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          fuzz-seconds: 300  # 5 minutes per run
          mode: 'code-change'  # or 'batch' for scheduled runs
          sanitizer: ${{ matrix.sanitizer }}

```bash
**Result**: Fuzzing runs on every PR and daily schedule.

### Language-Specific Fuzzing

#### Go Fuzzing (Built-in since Go 1.18)

**Write fuzz test** in `mypackage_fuzz_test.go`:

```go
package mypackage

import "testing"

func FuzzParseInput(f *testing.F) {
    // Seed corpus
    f.Add("valid input")
    f.Add("edge case")

    f.Fuzz(func(t *testing.T, input string) {
        // Fuzz target - should not crash
        result, err := ParseInput(input)
        if err != nil {
            return  // Expected errors are fine
        }

        // Validate result properties
        if result == nil {
            t.Error("result should not be nil when err is nil")
        }
    })
}

```bash
**Run locally**:

```bash
# Run fuzzing for 30 seconds

go test -fuzz=FuzzParseInput -fuzztime=30s

```bash
**In CI**:

```yaml

- name: Fuzz test

  run: go test -fuzz=Fuzz -fuzztime=60s ./...

```bash
**Result**: Scorecard detects Go native fuzzing.

#### Rust Fuzzing (cargo-fuzz)

**Install**:

```bash
cargo install cargo-fuzz

```bash
**Initialize**:

```bash
cargo fuzz init

```bash
**Write fuzz target** in `fuzz/fuzz_targets/fuzz_target_1.rs`:

```rust
#![no_main]
use libfuzzer_sys::fuzz_target;
use my_crate::parse_input;

fuzz_target!(|data: &[u8]| {
    // Fuzz target - should not panic
    let _ = parse_input(data);
});

```bash
**Run**:

```bash
cargo fuzz run fuzz_target_1

```bash
**In CI**:

```yaml

- name: Fuzz test

  run: |
    cargo install cargo-fuzz
    cargo fuzz run fuzz_target_1 -- -max_total_time=60

```bash
#### Python Fuzzing (Atheris)

**Install**:

```bash
pip install atheris

```bash
**Write fuzz target** in `fuzz_parse.py`:

```python
import atheris
import sys
from mymodule import parse_input

@atheris.instrument_func
def TestOneInput(data):
    try:
        parse_input(data)
    except ValueError:
        pass  # Expected errors are fine

atheris.Setup(sys.argv, TestOneInput)
atheris.Fuzz()

```bash
**Run**:

```bash
python fuzz_parse.py

```bash
#### JavaScript Fuzzing (Jazzer.js)

**Install**:

```bash
npm install --save-dev @jazzer.js/core

```bash
**Write fuzz target** in `fuzz/parse.fuzz.js`:

```javascript
const { FuzzedDataProvider } = require('@jazzer.js/core');
const { parseInput } = require('../src/parser');

module.exports.fuzz = function(data) {
  const provider = new FuzzedDataProvider(data);
  const input = provider.consumeString(1000);

  try {
    parseInput(input);
  } catch (e) {
    // Expected errors are fine
  }
};

```bash
**In CI**:

```yaml

- name: Fuzz test

  run: npx jazzer fuzz/parse.fuzz.js --timeout=60

```bash
---

## Advanced Topics

For writing effective fuzz targets, corpus management, and continuous fuzzing strategies, see:

**[Advanced Fuzzing Techniques](./fuzzing-advanced.md)**

## Related Content

**Other Security Practices checks**:

- [Security-Policy](./security-policy.md) - Vulnerability disclosure process
- [CII-Best-Practices](./cii-best-practices.md) - OpenSSF Best Practices Badge
- [Vulnerabilities](./vulnerabilities.md) - Known CVE detection and remediation
- [Token-Permissions](./token-permissions.md) - GitHub Actions permission scoping

**Related guides**:

- [Scorecard Index](../../index.md) - Overview of all 18 checks

---

*Fuzzing is optional unless your project handles untrusted input. Most projects score 0/10 and that's acceptable.*
