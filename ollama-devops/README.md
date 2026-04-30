# Ollama DevOps

**Version 2.0** — Systemd-integrated lifecycle management for Ollama AI models across MacBook and Linux (CachyOS) platforms.

A comprehensive project for managing and deploying Ollama AI models with DevOps best practices, including configuration management, automated deployment, and model lifecycle management across multiple platforms.

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
│   └── setup_passwordless_sudo.sh   # Sudo configuration utility
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

### CachyOS RTX 4090
- **GPU Acceleration**: Full NVIDIA GPU offloading with CUDA via systemd-managed service
- **Models**: Large language models (`qwen2.5-coder:32b-gpu`, `qwen2.5:7b-instruct`, `nomic-embed-text:latest`, `snowflake-arctic-embed`) with GPU-optimized modfiles
- **Performance**: Optimized for high-throughput inference with systemd service management
- **Service**: systemd unit with GPU device permissions

## Configuration Management

- **Platform Detection**: Scripts auto-detect macOS/Linux and apply settings
- **Environment Variables**: Set in platform `.env` files and propagated to systemd on Linux
- **Modfiles**: Hardware-optimized model configurations for reproducible builds

## Automated Model Lifecycle

- **`sod.sh`**: Starts systemd service (Linux) or direct process (macOS), ensures models, warms up optimal models, starts Qdrant
- **`eod.sh`**: Stops service/process, cleans up resources

## Testing

```bash
# Run all tests (unit + smoke + integration + lint)
./tests/run_all.sh

# Run specific test suites
./tests/run_all.sh --lint        # ShellCheck only (~5s)
./tests/run_all.sh --unit        # Unit tests only (~30s)
./tests/run_all.sh --smoke       # Smoke tests only (~1min)
./tests/run_all.sh --integration # Integration tests (~5min)

# Run a specific test file
bats tests/unit/test_configuration.bats

# Dry-run (no changes)
./scripts/sod.sh --dry-run
./scripts/eod.sh --dry-run
```

## Requirements

- **macOS**: macOS 13+, Ollama 0.21.2+
- **Linux**: CachyOS/Arch, Ollama 0.21.2+, NVIDIA drivers with CUDA, systemd
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
chmod +x scripts/setup_passwordless_sudo.sh
sudo scripts/setup_passwordless_sudo.sh

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

- **Makefile**: Build automation and development tasks (`make test-unit`, `make test-all`, `make lint`)
- **ShellCheck**: All scripts pass shellcheck validation
- **Bats**: Comprehensive test suite using Bash Automated Testing System

## License

MIT
