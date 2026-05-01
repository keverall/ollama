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

### For All Tests
- `bash` (>= 3.2) — scripts are compatible with macOS's default bash 3.2 and modern Linux (bash ≥5)
- `bats` (Bash Automated Testing System)
- `shellcheck`

> **Cross-platform note**: Scripts avoid bash 4+ features (associative arrays, `timeout` command) to ensure compatibility with macOS. Unit tests include mocks to simulate different platforms and shells without requiring multiple OSes.

### Install Test Dependencies (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install -y bats shellcheck
```

### Install Test Dependencies (Arch/CachyOS)
```bash
sudo pacman -S --needed bats shellcheck
```

### Install Mocks (optional, for offline testing)
```bash
cd tests/mocks
./install.sh
# Use by: export PATH="$PWD:$PATH"
```

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

To measure coverage:
```bash
# Install kcov
cargo install kcov   # or apt-get install kcov

# Generate coverage report
./tests/run_coverage.sh   # creates tests/coverage/index.html
```

Coverage goals:
- **Lines:** > 80%
- **Functions:** > 75%
- **Branches:** > 70%

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
