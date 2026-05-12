# Test Suite Quick Start

## In 60 Seconds

```bash
cd ollama-devops

# 1. Setup (only once)
./tests/setup.sh --quick

# 2. Run fast tests (every commit)
./tests/run_all.sh

# 3. Run full suite with coverage
make coverage                      # from ollama-devops/ or project root
# Open: ollama-devops/coverage/index.html
```

---

## What Each Command Does

| Command | What it runs | Time |
|---------|--------------|------|
| `./tests/setup.sh` | Installs bats, shellcheck, mocks | ~2 min |
| `./tests/run_all.sh` | lint + unit + smoke | ~2 min |
| `make test-all` | lint + unit + integration + smoke | ~7 min |
| `make coverage` | Generate coverage report (production code only) | ~3 min |
| `./tests/run_all.sh --lint` | Only shellcheck | ~5 sec |
| `./tests/run_all.sh --unit` | Only unit tests | ~30 sec |
| `./tests/run_all.sh --smoke` | Only smoke tests | ~1 min |
| `./tests/run_all.sh --integration` | Integration tests | ~5 min |
| `./tests/run_all.sh --all` | All suites except E2E | ~10 min |
| `./tests/e2e/run_all.sh` | Full hardware test (separate) | ~30 min |

**Note:** `make` commands work from the **project root** (one directory above `ollama-devops/`). This lets you run tests from anywhere without `cd`-ing into the subdirectory. For example:
```bash
# From anywhere in the repo
make test-unit        # → runs tests in ollama-devops/tests/unit/
make coverage         # → generates ollama-devops/coverage/
```

---

## Platform-Specific Testing

### Testing MacBook Configuration
```bash
cd ollama-devops
PLATFORM_OVERRIDE=macos ./tests/run_all.sh --unit
```

### Testing CachyOS Configuration
```bash
cd ollama-devops
PLATFORM_OVERRIDE=cachyos ./tests/run_all.sh --unit
```

### Testing with Mock GPU (no hardware)
```bash
export TEST_MOCK_GPU=absent
./tests/run_all.sh --smoke
```

---

## Need Help?

- Full docs: `docs/tests/README.md`
- Test plan: `docs/tests/TEST_PLAN.md`
- Architecture: `docs/tests/ARCHITECTURE.txt`
- Quick ref: `docs/tests/TEST_SUMMARY.md`
