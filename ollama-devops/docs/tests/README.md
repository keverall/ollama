# Ollama-DevOps Test Suite

## Overview

This is a comprehensive, DevOps-standard test framework for the ollama-devops scripts. It follows the **test pyramid** approach with multiple levels of testing:

```
    E2E Tests     (few, slow, full integration)
    Integration   (moderate, realistic components)
    Smoke Tests   (fast, basic health)
    Unit Tests    (many, isolated, fast)
```

## Quick Start

### Run All Tests (recommended for CI)
```bash
cd ollama-devops
./tests/run_all.sh --all
```

### Run Specific Suites
```bash
# Fast feedback (unit + smoke + lint)
./tests/run_all.sh

# only unit tests
./tests/run_all.sh --unit

# only smoke tests
./tests/run_all.sh --smoke

# linting only
./tests/run_all.sh --lint

# Full integration (requires Docker + Ollama)
./tests/run_all.sh --integration

# End-to-end on real hardware (very slow, downloads models)
./tests/run_all.sh --all
```

## Test Suite Structure

```
tests/
├── .batsrc                    # Bats configuration
├── .env.example               # Test environment template
├── README.md                  # This file
├── TEST_PLAN.md               # Detailed test plan
├── TEST_SUMMARY.md            # Quick reference
├── IMPLEMENTATION_SUMMARY.md  # Implementation details
├── ARCHITECTURE.txt           # Architecture diagrams
├── run_all.sh                 # Master test runner
├── run_lint.sh                # Static analysis
├── run_coverage.sh            # Coverage reports
├── setup.sh                   # Environment setup wizard
├── unit/                      # Unit tests (~30s)
│   ├── run_all.sh
│   ├── test_configuration.bats
│   ├── test_validation.bats
│   ├── test_ensure_model.bats
│   ├── test_readiness_loop.bats
│   └── test_warmup.bats
├── integration/               # Integration tests (~5 min)
│   ├── run_all.sh
│   ├── test_sod_integration.bats
│   └── test_eod_integration.bats
├── smoke/                     # Smoke tests (~1 min)
│   ├── run_all.sh
│   └── test_basic_smoke.bats
├── e2e/                       # End-to-end (~30 min)
│   ├── run_all.sh
│   └── test_full_workflow.bats
├── fixtures/                  # Static test data
│   ├── nvidia-smi-output.csv
│   └── model-list-sample.txt
├── mocks/                     # Mock binaries (offline testing)
│   ├── install.sh
│   ├── ollama
│   ├── docker-compose
│   ├── docker
│   ├── nvidia-smi
│   ├── curl
│   ├── pgrep
│   └── pkill
└── test_utils/                # Shared test utilities
    └── common.sh              # Assertion helpers
```

## Prerequisites

### A. Runtime Dependencies (to run the scripts themselves)

These are required to actually execute `sod.sh`/`eod.sh` (not just tests):

| Tool | Purpose | Install |
|------|---------|---------|
| `bash` | Script interpreter (≥3.2 on macOS, ≥5 on Linux) | Built-in on macOS/Linux |
| `ollama` | LLM server and model management | [ollama.com](https://ollama.com) |
| `docker` | Qdrant vector database (optional) | Docker Desktop / apt/pacman |
| `curl` | API connectivity checks | Built-in on macOS/Linux |
| `nvidia-smi` | GPU detection (Linux only) | NVIDIA driver package |
| `systemd` | Service management (Linux only) | Built-in on most Linux |

Platform-specific setup scripts handle these:
```bash
# Linux (CachyOS/Arch)
sudo pacman -S --needed ollama docker nvidia-container-toolkit

# macOS
# Download Ollama from ollama.com
```

### B. Test Dependencies (to run the test suite)

Required for developing and testing the scripts:

| Tool | Purpose | Install |
|------|---------|---------|
| `bats` | Test framework (runs `.bats` files) | `apt install bats` / `pacman -S bats` / `brew install bats-core` |
| `shellcheck` | Static analysis (linting) | `apt install shellcheck` / `pacman -S shellcheck` / `brew install shellcheck` |
| `bashcov` | Code coverage (optional, CI uses it) | `gem install bashcov` (requires Ruby) |
| `ruby` | Ruby runtime (required for bashcov) | Usually preinstalled on macOS; Linux: `apt install ruby` / `pacman -S ruby` |

**Install all test dependencies at once:**

Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install -y bats shellcheck ruby
gem install bashcov
```

Arch/CachyOS:
```bash
sudo pacman -S --needed bats shellcheck ruby
gem install bashcov
```

macOS:
```bash
brew install bats-core shellcheck ruby
gem install bashcov
```

> **Note:** `bats` and `shellcheck` are required to run tests locally. `bashcov` is only needed for generating coverage reports (enforced on CI). The `setup.sh` script installs `bats` and `shellcheck` automatically; `bashcov` must be installed separately.

## Running Tests

### 1. Linting (Fastest, ~5 seconds)
```bash
./tests/run_all.sh --lint
# or directly:
./tests/run_lint.sh
```
Checks:
- Shellcheck compliance (zero warnings target)
- Bash syntax validity
- Hardcoded paths
- Security issues
- Line ending format (LF)

### 2. Unit Tests (~30 seconds)
```bash
./tests/run_all.sh --unit
```
Tests individual functions:
- Configuration variable defaults
- Binary detection logic
- Model existence patterns
- Readiness retry loop
- Warmup suppression of errors

### 3. Smoke Tests (~60 seconds)
```bash
./tests/run_all.sh --smoke
```
Tests that the script:
- Starts without syntax errors
- Creates log directories
- Writes logs correctly
- Detects dependencies
- Sets environment variables

### 4. Integration Tests (~5 minutes)
```bash
./tests/run_all.sh --integration
```
Tests with mocked binaries:
- Full sod.sh workflow
- Full eod.sh workflow
- Log file outputs
- Process management
- Docker interactions

### 5. E2E Tests (~15-30 minutes)
```bash
./tests/run_all.sh --all
```
Tests on real hardware:
- Actual Ollama server startup
- Real model downloads
- GPU detection with nvidia-smi (CachyOS)
- Qdrant container startup
- Full teardown

**Warning:** E2E tests download models. Ensure you have:
- Sufficient disk space
- Stable internet connection
- NVIDIA GPU with drivers installed (CachyOS)

## Test Fixtures

Fixtures are static data files used by tests:

- `fixtures/nvidia-smi-output.csv` — sample GPU detection output
- `fixtures/model-list-sample.txt` — typical `ollama list` output
- `fixtures/expected/` — golden files for comparison

## Mock Binaries

The `tests/mocks/` directory contains replacements for real binaries that:
- Are fast (no network/model downloads)
- Are deterministic (no flaky network)
- Can simulate errors

### Using Mocks
```bash
export PATH="/path/to/ollama-devops/tests/mocks:$PATH"
export TEST_MOCK_ollama=always-fail  # optional: control behavior
./scripts/sod.sh  # will use mocks
```

### Available Mock Modes

**ollama mock:**
- `default` — succeeds, returns fake model list
- `always-fail` — exits 1 (test error handling)
- `start-fail-2` — fails first 2 calls, then succeeds (test retry)

**nvidia-smi mock:**
- `present` (default) — returns GPU info
- `absent` — exit 127 (not found)
- `error` — returns error message (driver failure)

**curl mock:**
- `success` (default) — returns 200 with JSON
- `fail` — exits 1 (test connectivity failures)

## Continuous Integration

### GitHub Actions Workflow

Create `.github/workflows/test.yml`:
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y bats shellcheck
      - name: Run full test suite
        run: |
          chmod +x tests/run_all.sh
          ./tests/run_all.sh --all
```

### Pre-Commit Hook

Add to `.git/hooks/pre-commit`:
```bash
#!/bin/bash
./tests/run_all.sh --lint --unit
```

## Writing New Tests

### Unit Test Template
```bash
#!/usr/bin/env bats
# Description of what's being tested

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "Description of test case" {
    # Arrange
    # Act
    # Assert
    [ expected condition ]
}
```

### Integration Test Template
```bash
#!/usr/bin/env bats
# Integration test using actual script with mocks

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
    PATH="$(pwd)/../mocks:$PATH"
    export PATH
    cp /path/to/real/script.sh .
}

@test "Full script behavior" {
    run ./script.sh
    [ "$status" -eq 0 ]
    # Assert on log files, outputs
}
```

## Test Coverage

**Coverage measures which lines of your production scripts are actually executed during tests.** It helps identify untested code paths and gauge test effectiveness.

### What Gets Measured

Coverage **excludes**:
- Test scripts (`tests/*.bats`, `tests/*.sh`)
- Mock binaries (`tests/mocks/`)
- Fixtures and test utilities

Coverage **includes only**:
- Production scripts under `scripts/` (e.g., `sod.sh`, `eod.sh`, `lib_logging.sh`)

### Prerequisites

```bash
# Install bashcov (Ruby gem)
gem install bashcov

# Or system package (if available)
# Ubuntu: apt install ruby-bashcov
# Arch: pacman -S ruby-bashcov
```

### Generate Coverage Report

**Preferred method (via Makefile from project root):**
```bash
cd /path/to/ollama   # project root, not ollama-devops/
make coverage        # generates ollama-devops/coverage/index.html
```

**Direct script invocation:**
```bash
cd ollama-devops
./tests/run_coverage.sh   # generates coverage/index.html
```

### View the Report

```bash
# Open in browser (from project root)
open ollama-devops/coverage/index.html     # macOS
xdg-open ollama-devops/coverage/index.html # Linux
```

The HTML report shows:
- **Line coverage** percentage per file
- Color-coded line highlighting (green = covered, red = missing)
- Summary across all production scripts

### Coverage Goals

Target thresholds (enforced in CI):
- **Lines:** > 80%
- **Functions:** > 75%
- **Branches:** > 70%

Current coverage is measured on each CI run. Falling below thresholds fails the build.

### How It Works

`bashcov` instruments Bash execution using `set -x` (debug mode) and records which lines run. SimpleCov (Ruby) aggregates results and applies filters from `.simplecov`:

- Excludes all paths matching `/tests/`, `/test/`, `/spec/`
- Excludes `/mocks/` and `/fixtures/`
- Reports only on `scripts/*.sh`

Coverage data is written to `ollama-devops/coverage/` (gitignored).

### Interpreting Results

**Low coverage on a script means:**
- Some code paths are untested by the current test suite
- Consider adding unit or integration tests for the missing lines
- Review branches (if/else, case statements) that may lack test cases

**Example:** If `sod.sh` shows 60% line coverage, look for:
- Untested error handling branches
- Platform-specific code paths (macOS vs Linux) not exercised
- Uncalled functions or configuration options

### Updating Coverage Configuration

The `.simplecov` file at project root controls exclusions. To include additional files or adjust filters, edit it and re-run:

```bash
make coverage
```

### Troubleshooting

**"bashcov: command not found"**
```bash
gem install bashcov
# Ensure ~/.local/share/gem/ruby/*/bin is in PATH
export PATH="$HOME/.local/share/gem/ruby/$(ruby -e 'print RUBY_VERSION')/bin:$PATH"
```

**"Coverage report shows 0%"**
- Ensure `.simplecov` exists at project root
- Verify tests actually execute production code (run with `DEBUG=1`)
- Check that `PROJECT_ROOT` is correctly set

**Coverage includes test files**
- Confirm `.simplecov` has proper `add_filter` rules
- Regenerate: `make clean && make coverage`

**Report shows deleted temp files (warnings)**
These are harmless — bashcov tracks scripts from temp locations during bats execution.

## Debugging Failing Tests

### 1. Run test in verbose mode
```bash
bats -d tests/unit/test_configuration.bats
```

### 2. Set DEBUG logging
```bash
DEBUG=1 bats tests/unit/test_configuration.bats
```

### 3. Check test logs
All test logs are in `tests/logs/`:
- `unit-<timestamp>.log`
- `integration-<timestamp>.log`
- `smoke-<timestamp>.log`

### 4. Re-run failed test in isolation
```bash
bats tests/unit/test_readiness_loop.bats::test_name
```

## Test Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TEST_ENV` | Test environment (unit/integration/smoke/e2e) | auto-detected |
| `TEST_MOCK_ollama` | Mock ollama behavior | default |
| `TEST_MOCK_GPU` | Mock GPU presence | present |
| `TEST_MOCK_curl` | Mock curl response | success |
| `DEBUG` | Enable verbose debug logging | 0 |
| `PLATFORM_OVERRIDE` | Override platform detection | auto |

## Common Issues

### "bats: command not found"
Install bats: `sudo apt-get install bats` or `sudo pacman -S bats`

### "shellcheck: command not found"
Install shellcheck: `sudo apt-get install shellcheck`

### "Tests fail due to permissions"
Ensure scripts are executable: `chmod +x tests/*.sh tests/*/run_all.sh`

### "E2E tests timeout"
E2E tests download large models. Either:
- Skip E2E: `./tests/run_all.sh --unit --smoke --integration`
- Increase timeout: `export BATSLIB_TIMEOUT_MULTIPLIER=3`

## Contributing

When adding new scripts or modifying existing ones:

1. Update the corresponding unit tests
2. Run `./tests/run_all.sh --lint --unit` before committing
3. If functionality changed, update integration tests
4. For major changes, add new E2E test scenarios

## Test Standards

All tests must:
1. ✅ Have descriptive names (`@test "sod.sh: handles missing ollama binary"`)
2. ✅ Include `setup()` and `teardown()` for isolation
3. ✅ Use temporary directories (mktemp)
4. ✅ Clean up after themselves
5. ✅ Not depend on external services (unit tests) or use mocks
6. ✅ Have assertions for both success and failure cases

## Further Reading

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [Shellcheck Wiki](https://github.com/koalaman/shellcheck/wiki)
- [DevOps Test Strategies](https://devops.com/test-automation-strategies/)

---

**Maintainer:** Keverall  
**Last Updated:** 2026-04-30  
**Version:** 1.0.0
