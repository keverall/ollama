# ollama-cachyos DevOps Test Plan

## Test Strategy Overview

This test plan follows DevOps principles with a **shift-left** approach, testing early and often across multiple levels. Tests are automated, modular, and integrate into CI/CD pipelines.

**Test Pyramid:**
```
    /------------------\
    |     E2E Tests    |  (Few - critical user journeys)
    |------------------|
    | Integration Tests|  (Some - component interactions)
    |------------------|
    |   Unit Tests     |  (Many - individual functions)
    \------------------/
```

## Test Levels

### 1. Unit Tests
- **Scope:** Individual functions and logic units
- **Location:** `tests/unit/`
- **Framework:** BATS (Bash Automated Testing System) + shellcheck
- **Isolation:** Mocks for external dependencies (ollama, docker, nvidia-smi)
- **Coverage Target:** >80%

### 2. Integration Tests
- **Scope:** Script interactions with real binaries in controlled environments
- **Location:** `tests/integration/`
- **Dependencies:** Docker containers, mock Ollama server
- **Focus:** Configuration, environment validation, dependency checking

### 3. Smoke Tests
- **Scope:** Basic script functionality and environment readiness
- **Location:** `tests/smoke/`
- **Runtime:** < 30 seconds
- **Purpose:** Quick validation that scripts can start and basic checks pass

### 4. End-to-End (E2E) Tests
- **Scope:** Full workflow: start services, pull models, warmup, stop services
- **Location:** `tests/e2e/`
- **Dependencies:** Real GPU, Docker, network access
- **Runtime:** Variable (may be long due to model downloads)

## Test Categories

### A. Functional Tests
| Test ID | Test Name | Level | Description |
|---------|-----------|-------|-------------|
| FT-01 | Environment variable defaults | Unit | Verify correct OLLAMA_HOST, PORT, etc |
| FT-02 | Custom environment overrides | Unit | Verify custom OLLAMA_HOST binding |
| FT-03 | Binary detection (ollama, docker) | Unit | Check binary presence validation |
| FT-04 | GPU detection logic | Unit | nvidia-smi output parsing |
| FT-05 | Process cleanup before start | Unit | pgrep/pkill functionality |
| FT-06 | Ollama server readiness loop | Unit | Retry logic with timeout |
| FT-07 | Model existence check | Unit | grep pattern matching for models |
| FT-08 | Modfile path resolution | Unit | Path construction logic |
| FT-09 | Log rotation/size checks | Unit | Log file management |
| FT-10 | Qdrant docker-compose validation | Unit | docker-compose.yml existence check |

### B. Error Handling Tests
| Test ID | Test Name | Level | Description |
|---------|-----------|-------|-------------|
| EH-01 | Missing ollama binary | Unit | Exit code 1, clear error message |
| EH-02 | Missing docker binary | Unit | Exit code 1, clear error message |
| EH-03 | Ollama fails to start | Unit | Log tail displayed, exit code 1 |
| EH-04 | Model pull failure | Unit | Retry logic, exit code 1 |
| EH-05 | Modfile not found | Unit | Clear error with path shown |
| EH-06 | Port conflict (EADDRINUSE) | Unit | Proper cleanup and retry |
| EH-07 | Permission denied (non-root) | Unit | Warning logged but continues |
| EH-08 | Qdrant fails to start | Integration | Warning logged, script continues |
| EH-09 | Log directory unwritable | Unit | Exit code 1, clear error |

### C. Security Tests
| Test ID | Test Name | Level | Description |
|---------|-----------|-------|-------------|
| SEC-01 | No hardcoded secrets | Unit | Static analysis of script |
| SEC-02 | Input sanitization | Unit | Ensure no shell injection vectors |
| SEC-03 | Least privilege | Integration | Verify non-root execution works |
| SEC-04 | Log file permissions | Unit | Check secure log permissions |
| SEC-05 | Environment variable injection | Unit | Validate variable expansion safety |

### D. Performance Tests
| Test ID | Test Name | Level | Description |
|---------|-----------|-------|-------------|
| PF-01 | Startup time < 60s | Smoke | Time from launch to ready |
| PF-02 | Memory usage < 2GB | Smoke | Peak memory during startup |
| PF-03 | GPU detection overhead | Unit | nvidia-smi query time |
| PF-04 | Process cleanup time | Unit | Time to kill existing ollama |
| PF-05 | Concurrent model warmup | Performance | Run warmups in parallel (if safe) |

### E. Idempotency Tests
| Test ID | Test Name | Level | Description |
|---------|-----------|-------|-------------|
| ID-01 | Multiple consecutive runs | Integration | Script should succeed each time |
| ID-02 | Already running scenario | Integration | Detects existing server, skips start |
| ID-03 | Model already exists | Integration | Skips pull/create, uses existing |
| ID-04 | Partial state recovery | Integration | Handle interrupted previous run |

### F. Recovery/Resilience Tests
| Test ID | Test Name | Level | Description |
|---------|-----------|-------|-------------|
| RC-01 | Server crash during startup | E2E | Script detects and reports |
| RC-02 | Network failure (model pull) | E2E | Retry with exponential backoff |
| RC-03 | Disk full scenario | E2E | Graceful error message |
| RC-04 | GPU driver reset | E2E | Handle nvidia-smi failures |

### G. Compatibility Tests
| Test ID | Test Name | Level | Description |
|---------|-----------|-------|-------------|
| COMP-01 | bash 3.2+ (macOS) | Unit | POSIX compliance |
| COMP-02 | bash 5.x (Linux) | Unit | Modern features used |
| COMP-03 | IPv6-only network | Integration | OLLAMA_HOST=[::] binding |
| COMP-04 | IPv4-only network | Integration | Fallback to 0.0.0.0 |
| COMP-05 | Docker not installed | Unit | Clean error message |
| COMP-06 | NVIDIA driver versions | Integration | Test with various driver versions |

### H. Observability Tests
| Test ID | Test Name | Level | Description |
|---------|-----------|-------|-------------|
| OBS-01 | Log format validation | Unit | Timestamps, structured format |
| OBS-02 | Log level filtering | Unit | INFO vs WARNING vs ERROR |
| OBS-03 | Server log capture | Integration | ollama-server.log populated |
| OBS-04 | PID tracking | Unit | OLLAMA_PID recorded correctly |
| OBS-05 | Metrics emission | Integration | Script emits exit codes |

## Test Environments

### dev (Local Development)
- Docker containers for dependencies
- Mock ollama binary
- Fast feedback (< 5 min)

### staging (CI Pipeline)
- GitHub Actions runner (ubuntu-latest)
- Real Docker daemon
- No GPU available (skip GPU tests or use mock)
- Full test suite excluding GPU-specific tests

### prod (Integration Testing)
- Real CachyOS system with RTX 4090
- Full model downloads
- End-to-end validation

## Test Data Management

- **Fixtures:** `tests/fixtures/` - Mock outputs, sample modelfiles
- **Mock Binaries:** `tests/mocks/` - Fake ollama, docker, nvidia-smi
- **Expected States:** `tests/fixtures/expected/` - Known-good outputs

## Test Execution Matrix

| Script | Unit | Integration | Smoke | E2E |
|--------|------|-------------|-------|-----|
| sod.sh | ✅ | ✅ | ✅ | ✅ |
| eod.sh | ✅ | ✅ | ✅ | ✅ |

## Acceptance Criteria

- **Pass rate:** 100% of tests must pass for production deployment
- **Critical tests:** All E2E tests must pass
- **Code coverage:** >80% line coverage (measured by kcov or similar)
- **Shellcheck:** Zero warnings/errors
- **Security scan:** No high/critical vulnerabilities (Gitleaks, Trivy)
- **Performance:** Startup time < 60s on reference hardware (RTX 4090)

## CI/CD Integration

### Pre-commit Hook (local)
```bash
# Run fast unit tests
make test-unit
# Run shellcheck
make lint
```

### CI Pipeline (GitHub Actions)
```
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - checkout
      - setup-bats
      - run: make test-all
      - run: make test-coverage
```

### Nightly (Scheduled)
- Full E2E suite on dedicated hardware
- Performance regression tests
- Model pull speed tests

## Test Reporting

- **JUnit XML** for CI integration
- **HTML coverage reports**
- **Log aggregation** for failed runs
- **Slack notifications** for test failures

## Troubleshooting Failed Tests

1. Check logs in `tests/logs/`
2. Run with `DEBUG=1` for verbose output
3. Validate mocks match real binary outputs
4. Check for network/Docker issues in integration tests

## Maintenance

- Update tests when scripts change
- Review and update mock data quarterly
- Audit shellcheck warnings monthly
- Refresh test fixtures when models update
