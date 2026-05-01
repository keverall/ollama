# Ollama DevOps

**Version 2.0** — Cross-platform (macOS + Linux) lifecycle management for Ollama AI models.

A comprehensive project for managing and deploying Ollama AI models with DevOps best practices, including configuration management, automated deployment, and model lifecycle management across multiple platforms.

## Cross-Platform Compatibility

Scripts are designed to run on both macOS (bash 3.2) and modern Linux (bash ≥5):

- **bash 3.2 compatibility**: `lib_logging.sh` uses function-based lookups instead of associative arrays for log level priority
- **Portable timeout**: `sod.sh` provides `run_with_timeout()` fallback for systems without GNU `timeout` (macOS)
- **Platform abstraction**: Unified scripts auto-detect OS and apply appropriate service management (systemd vs direct process)

## Supported Platforms

- **MacBook M4 Pro 24GB** — Optimized for Apple Silicon with unified memory
- **CachyOS i9-13900KS 32GB + RTX 4090** — Optimized for NVIDIA GPU acceleration

## Project Structure

```text
ollama-devops/
├── platform/                         # Platform-specific configurations
│   ├── macbook-m4-24gb-optimized/
│   │   ├── modfiles/                 # MacBook-specific modfiles
│   │   │   ├── modfile-gemma4
│   │   │   └── modfile-qwen-devops
│   │   └── .env                      # MacBook-specific config
│   └── cachyos-i9-32gb-nvidia-4090/
│       ├── modfiles/                 # CachyOS-specific modfiles
│       │   ├── qwen2.5-coder:32b-gpu.modelfile
│       │   ├── Qwen2.5-7B-instruct-GPU.modelfile
│       │   ├── nomic-embed-text-GPU.modelfile
│       │   └── snowflake-arctic-embed.modfile
│       └── .env                      # CachyOS-specific config
├── scripts/                          # Unified cross-platform scripts
│   ├── sod.sh                       # Start of Day script
│   ├── eod.sh                       # End of Day script
│   ├── lib_logging.sh               # Shared logging library
│   └── initialisation/
│       └── setup_passwordless_sudo.sh   # Sudo configuration utility
├── systemd/                          # systemd service definitions (Linux)
│   ├── ollama.service               # Main service unit
│   ├── platform-overrides/          # Drop-in configuration overrides
│   │   └── cachyos-nvidia.conf      # NVIDIA GPU device permissions
│   └── README.md                    # systemd usage documentation
├── docs/                             # Documentation
│   ├── SYSTEM_OVERVIEW.md
│   ├── API_ENDPOINTS.md
│   ├── SYSTEMD_INTEGRATION.md
│   ├── MIGRATION_SYSTEMD.md
│   ├── DOCUMENTATION_STANDARD.md
│   └── tests/                       # Test suite documentation
│       ├── README.md
│       ├── QUICKSTART.md
│       ├── TEST_PLAN.md
│       ├── TEST_SUMMARY.md
│       ├── IMPLEMENTATION_SUMMARY.md
│       └── ARCHITECTURE.txt
├── tests/                            # Test suites
│   ├── unit/                         # Unit tests (~30s)
│   │   ├── run_all.sh
│   │   ├── test_configuration.bats
│   │   ├── test_validation.bats
│   │   ├── test_ensure_model.bats
│   │   ├── test_readiness_loop.bats
│   │   └── test_warmup.bats
│   ├── integration/                  # Integration tests (~5 min)
│   │   ├── run_all.sh
│   │   ├── test_sod_integration.bats
│   │   └── test_eod_integration.bats
│   ├── smoke/                        # Smoke tests (~1 min)
│   │   ├── run_all.sh
│   │   └── test_basic_smoke.bats
│   ├── e2e/                          # End-to-end tests (~30 min)
│   │   ├── run_all.sh
│   │   └── test_full_workflow.bats
│   ├── fixtures/                     # Static test data
│   │   ├── nvidia-smi-output.csv
│   │   └── model-list-sample.txt
│   ├── mocks/                        # Mock binaries for offline testing
│   │   ├── install.sh
│   │   ├── ollama
│   │   ├── docker-compose
│   │   ├── docker
│   │   ├── nvidia-smi
│   │   ├── curl
│   │   ├── pgrep
│   │   └── pkill
│   ├── test_utils/                   # Shared test utilities
│   │   └── common.sh
│   ├── run_all.sh                    # Master test runner
│   ├── run_lint.sh                   # Static analysis (ShellCheck)
│   ├── run_coverage.sh               # Coverage report generator
│   └── setup.sh                      # Test environment setup
├── docker-compose.yml                # Qdrant vector database deployment
├── Makefile                          # Build automation and tasks
└── logs/                            # Runtime logs (created at runtime)
```

## Quick Start

1. **Navigate to project directory:**
   ```bash
   cd ollama-devops
   ```

2. **Make scripts executable:**
   ```bash
   chmod +x scripts/*.sh tests/*.sh
   ```

3. **Start the environment:**
   ```bash
   ./scripts/sod.sh
   ```
   - **Linux**: Installs/configures systemd service, may prompt for sudo
   - **macOS**: Direct process management (no sudo needed)

4. **Stop the environment:**
   ```bash
   ./scripts/eod.sh
   ```

> **Note**: Upgrading from v1.x? See [MIGRATION_SYSTEMD.md](docs/MIGRATION_SYSTEMD.md) for one-time migration steps.

## Platform Management

### MacBook M4 Pro 24GB

- **Memory Optimizations**: Flash attention and KV cache quantization for 24GB unified memory
- **Models**: `qwen-devops` (custom DevOps fine-tuned model built from qwen2.5-coder:14b) and `nomic-embed-text`
- **GPU**: Apple Neural Engine via Metal
- **Control**: Direct process (no systemd)

See `platform/macbook-m4-24gb-optimized/README.md` for platform configuration.

### CachyOS RTX 4090

- **GPU Acceleration**: Full NVIDIA GPU offloading with CUDA via systemd-managed service
- **Models**: Large language models (`qwen2.5-coder:32b-gpu`, `qwen2.5:7b-instruct`, `nomic-embed-text:latest`, `snowflake-arctic-embed`) with GPU-optimized modfiles
- **Performance**: Optimized for high-throughput inference with systemd service management
- **Service**: systemd unit with GPU device permissions

See `platform/cachyos-i9-32gb-nvidia-4090/README.md` for platform configuration.

## Configuration Management

- **Platform Detection**: Scripts auto-detect macOS/Linux and apply settings
- **Environment Variables**: Set in platform `.env` files and propagated to systemd on Linux
- **Modfiles**: Hardware-optimized model configurations for reproducible builds

## Automated Model Lifecycle

- **`sod.sh`**: Starts systemd service (Linux) or direct process (macOS), ensures models, warms up optimal models, starts Qdrant
- **`eod.sh`**: Stops service/process, cleans up resources

## Testing

### Quick Commands

```bash
# Run full test suite (lint + unit + smoke + integration)
./tests/run_all.sh              # ~10 minutes

# Run specific suites (faster feedback)
./tests/run_all.sh --lint        # ShellCheck + syntax (~5s)
./tests/run_all.sh --unit        # Unit tests only (~30s)
./tests/run_all.sh --smoke       # Smoke tests only (~1 min)
./tests/run_all.sh --integration # Integration tests (~5 min)

# Run a single test file
bats tests/unit/test_configuration.bats

# From project root (one level up), use make:
cd .. && make test-unit           # Same as above, from anywhere
make test-all                     # Full suite from root
make coverage                     # Generate coverage report
```

### Test Pyramid

```
    E2E Tests      (few, slow, full hardware, ~30 min)
    Integration    (moderate, mocks, ~5 min)
    Smoke Tests    (fast, basic health, ~1 min)
    Unit Tests     (many, isolated, ~30s)
```

- **Unit** — Individual functions in isolation (mocked dependencies)
- **Smoke** — Basic script execution, environment detection
- **Integration** — Full `sod.sh`/`eod.sh` workflows with mock binaries
- **E2E** — Real hardware, actual Ollama server, model downloads

See [docs/tests/README.md](docs/tests/README.md) for the complete test guide.

### Coverage

**What it measures:** Fraction of production script lines actually executed during tests. Only scripts under `scripts/` are measured — test scripts and mocks are excluded.

**Generate report:**
```bash
# From project root (recommended)
make coverage

# Or directly
cd ollama-devops && ./tests/run_coverage.sh
```

Report writes to `ollama-devops/coverage/index.html` (gitignored). Open in browser to see line-by-line coverage:
- Green — executed
- Red — never run (missing test case)

**Prerequisites:** `bashcov` Ruby gem. Install: `gem install bashcov`.

**Goals:** Lines > 80%, Functions > 75%, Branches > 70%. Coverage is checked on CI; failing thresholds breaks the build.

**Configuration:** Exclusions are defined in `.simplecov` at project root (filters `/tests/`, `/mocks/`, `/fixtures/`).

See [docs/tests/README.md#test-coverage](docs/tests/README.md#test-coverage) for full details on interpreting results and troubleshooting.

### Dry-Run

Test script changes without affecting your system:
```bash
./scripts/sod.sh --dry-run
./scripts/eod.sh --dry-run
```

## Requirements

- **macOS**: macOS 13+, bash 3.2 (bundled), Ollama 0.21.2+
- **Linux**: CachyOS/Arch, bash ≥5, Ollama 0.21.2+, NVIDIA drivers with CUDA, systemd
- **Docker**: 20.10+ for Qdrant
- **Hardware**: See platform-specific requirements

## Setup

### Linux (CachyOS) — First Time Setup

```bash
# 1. Install dependencies
sudo pacman -S --needed ollama docker nvidia-container-toolkit

# 2. Enable and start Docker
sudo systemctl enable --now docker

# 3. Run passwordless sudo setup (required for systemd management)
chmod +x scripts/initialisation/setup_passwordless_sudo.sh
sudo scripts/initialisation/setup_passwordless_sudo.sh

# 4. Initialize environment
chmod +x scripts/*.sh tests/*.sh
./scripts/sod.sh
```

### macOS — First Time Setup

```bash
# 1. Install Ollama from ollama.com
# 2. Initialize environment
chmod +x scripts/*.sh
./scripts/sod.sh
```

## Environment Variables

Key variables used throughout the system:

**Platform Configuration:**
- `PLATFORM_OVERRIDE`: Manual platform override (`auto`, `macos`, `cachyos`, `linux`)

**Ollama Configuration:**
- `OLLAMA_HOST`: Host interface for Ollama (default: `[::]:11434` for dual-stack)
- `OLLAMA_PORT`: Port for Ollama API (default: `11434`)
- `OLLAMA_BIN`: Path to Ollama binary (default: `ollama`)

**Performance Tuning:**
- `OLLAMA_NUM_PARALLEL`: Number of parallel workers (default: `24`)
- `OLLAMA_MAX_LOADED_MODELS`: Max models in memory (default: `2`)
- `OLLAMA_FLASH_ATTENTION`: MacBook GPU optimization (default: `1`)
- `OLLAMA_KV_CACHE_TYPE`: MacBook memory optimization (default: `q4_0`)
- `OLLAMA_GPU_LAYERS`: CachyOS GPU offloading (default: `50`)

**Storage Configuration:**
- `OLLAMA_MODELS`: Custom model storage path (CachyOS: `/home/ollama/models`)

**Model Configuration:**
- `DEFAULT_MODELS`: Comma-separated model list (platform-specific defaults)
- `DEVOPS_MODEL`: Custom DevOps model name (MacBook only: `qwen-devops`)

**Qdrant Configuration:**
- `QDRANT_PORT`: Port for Qdrant HTTP API (default: `6333`)
- `QDRANT_GRPC_PORT`: Port for Qdrant gRPC API (default: `6334`)

## Development

### Prerequisites

To develop and test the scripts, install these tools **in addition** to the runtime requirements above:

| Tool | Purpose | Install (Ubuntu/Debian) | Install (Arch/CachyOS) | Install (macOS) |
|------|---------|------------------------|------------------------|-----------------|
| `bats` | Test framework | `sudo apt install bats` | `sudo pacman -S bats` | `brew install bats-core` |
| `shellcheck` | Linter | `sudo apt install shellcheck` | `sudo pacman -S shellcheck` | `brew install shellcheck` |
| `bashcov` | Coverage (optional) | `gem install bashcov` | `gem install bashcov` | `gem install bashcov` |
| `make` | Build automation | `sudo apt install make` | `sudo pacman -S make` | `brew install make` |

Only `bats` and `shellcheck` are required to run tests. `bashcov` is needed only for coverage reports (enforced on CI).

**Quick install all test dependencies:**
```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y bats shellcheck

# Arch/CachyOS
sudo pacman -S --needed bats shellcheck

# macOS
brew install bats-core shellcheck

# Coverage (any platform with Ruby)
gem install bashcov
```

### Workflow

```bash
# From ollama-devops directory:
cd ollama-devops

# Lint only (~5s)
make lint

# Run unit tests (~30s)
make test-unit

# Run full test suite (~10 min)
make test-all

# Generate coverage report (~3 min)
make coverage    # opens ollama-devops/coverage/index.html

# Or run scripts directly:
./tests/run_all.sh --lint --unit --smoke --integration
```

**Before committing:**
1. `make lint` — zero warnings required
2. `make test-unit` — all tests must pass
3. `make coverage` — stay above thresholds (lines >80%)

See [docs/tests/README.md](docs/tests/README.md) for the complete testing guide.

## Cost Savings

This project is designed for **local LLM inference** to eliminate cloud API costs.

- **No per-token fees**: After models download once (~20–80 GB), inference is free.
- **No network latency**: Requests processed locally; on RTX 4090 expect sub-500ms responses for 32B models.
- **No data egress**: All queries stay on your machine.
- **Hardware pays for itself**: Processing 5–10M tokens/month on GPT-4 costs $150–$600; a $2000 RTX 4090 breaks even in 4–12 months.

See [Platform Environments](platform/) for hardware-specific performance targets.

### Hardware ROI Table

| Hardware | Model Size | Tokens/sec | Break-even Monthly Tokens | Approx. Cloud Cost Saved/mo |
|---|---|---|---|---|
| MacBook M4 Pro 24GB | 14B | ~40 | ~2M | $60 (GPT-4) / $30 (Claude) |
| RTX 4090 24GB | 32B (50 layers) | ~80 | ~5M | $150 (GPT-4) / $75 (Claude) |
| RTX 4090 24GB | 7B (full GPU) | ~150 | ~10M | $300 (GPT-4) / $150 (Claude) |

## Environment Files

Platform `.env` files are **gitignored** (contain local paths). After cloning:

```bash
# MacBook
cp platform/macbook-m4-24gb-optimized/.envexample platform/macbook-m4-24gb-optimized/.env
nano platform/macbook-m4-24gb-optimized/.env   # adjust OLLAMA_BIN if needed

# CachyOS
cp platform/cachyos-i9-32gb-nvidia-4090/.envexample platform/cachyos-i9-32gb-nvidia-4090/.env
# Edit paths to match your system (OLLAMA_MODELS, OLLAMA_BIN)
```

Each platform directory includes a `README.md` explaining every variable.

## License

MIT
