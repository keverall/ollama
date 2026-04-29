# Test Suite Quick Start

## In 60 Seconds

```bash
cd ollama-devops

# 1. Setup (only once)
./tests/setup.sh --quick

# 2. Run fast tests (every commit)
./tests/run_all.sh

# 3. Run full suite with coverage
make test-all
```

---

## What Each Command Does

| Command | What it runs | Time |
|---------|--------------|------|
| `./tests/setup.sh` | Installs bats, shellcheck, mocks | ~2 min |
| `./tests/run_all.sh` | lint + unit + smoke | ~2 min |
| `make test-all` | lint + unit + integration + smoke | ~7 min |
| `./tests/run_all.sh --lint` | Only shellcheck | ~5 sec |
| `./tests/run_all.sh --unit` | Only unit tests | ~30 sec |
| `./tests/run_all.sh --e2e` | **Not implemented** (placeholder) | N/A |
| `./tests/e2e/run_all.sh` | Full hardware test | ~30 min |

---

## Live Test Example (Current Session)

The unified scripts were validated:

```bash
# Platform detection works
$ PLATFORM_OVERRIDE=macos ./scripts/sod.sh --dry-run
🎯 Detected platform: macos
[Loading environment from: platform/macbook-m4-24gb-optimized/.env]
[Ensuring models from: platform/macbook-m4-24gb-optimized/modfiles/]

$ PLATFORM_OVERRIDE=cachyos ./scripts/sod.sh --dry-run  
🎯 Detected platform: cachyos
[Loading environment from: platform/cachyos-i9-32gb-nvidia-4090/.env]
[Ensuring models from: platform/cachyos-i9-32gb-nvidia-4090/modfiles/]
```

✅ **Cross-platform compatibility confirmed**

---

## Writing Your First Test

Create `tests/unit/test_myfeature.bats`:

```bash
#!/usr/bin/env bats
@test "My feature works" {
    run bash -c 'echo "hello"
    [ "$status" -eq 0 ]
    [ "$output" = "hello" ]
}
```

Then run:

```bash
cd tests/unit
./run_all.sh   # auto-discovers your new test
```

---

## Troubleshooting

**"command not found: bats"**
```bash
./tests/setup.sh --quick   # installs bats + shellcheck
```

**"tests/run_all.sh: Permission denied"**
```bash
chmod +x tests/*.sh tests/*/run_all.sh
```

**"Test hangs"**
```bash
# Increase timeout multiplier
export BATSLIB_TIMEOUT_MULTIPLIER=3
./tests/run_all.sh
```

**"Want to see what's failing"**
```bash
# Verbose mode
DEBUG=1 bats tests/unit/test_configuration.bats
```

---

## CI Example (GitHub Actions)

```yaml
name: Tests
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup
        run: |
          sudo apt-get update
          sudo apt-get install -y bats shellcheck
      - name: Run tests
        run: |
          cd ollama-devops
          ./tests/run_all.sh --all
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
- Architecture: `docs/SYSTEM_OVERVIEW.md`
- Quick reference: `docs/API_ENDPOINTS.md`

