# Test Suite Quick Start

## In 60 Seconds

```bash
cd ollama-cachyos

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

The sod.sh fix was validated:

```bash
# Script started Ollama successfully
$ ollama list
NAME    ID    SIZE    MODIFIED

# Server running on [::]:11434
$ curl http://localhost:11434/api/tags
{"version":"0.21.2", ...}

# GPU detected
$ nvidia-smi
NVIDIA GeForce RTX 4090, 23028 MiB total
```

✅ **Core fix confirmed working**

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
name: Test
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
          cd ollama-cachyos
          ./tests/run_all.sh --all
```

---

## Need Help?

- Full docs: `tests/README.md`
- Test plan: `tests/TEST_PLAN.md`  
- Architecture: `tests/ARCHITECTURE.txt`
- Summary: `tests/IMPLEMENTATION_SUMMARY.md`
