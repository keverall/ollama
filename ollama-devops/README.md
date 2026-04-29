# Ollama DevOps

A comprehensive project for managing and deploying Ollama AI models with DevOps best practices, including configuration management, automated deployment, and model lifecycle management across multiple platforms.

## Supported Platforms

- **MacBook M4 Pro 24GB** - Optimized for Apple Silicon with unified memory
- **CachyOS i9-13900KS 32GB + RTX 4090** - Optimized for NVIDIA GPU acceleration

## Project Structure

```text
ollama-devops/
├── platform/                         # platform-specific configurations
│   ├── macbook-m4-24gb-optimized/
│   │   ├── modfiles/                 # MacBook-specific modfiles
│   │   │   ├── modfile-gemma4
│   │   │   └── modfile-qwen-devops
│   │   └── .env                      # MacBook-specific config
│   └── cachyos-i9-32gb-nvidia-4090/
│       ├── modfiles/                 # CachyOS-specific modfiles
│       │   ├── Qwen2.5-72B-instruct-GPU.modelfile
│       │   ├── Qwen2.5-7B-instruct-GPU.modelfile
│       │   └── nomic-embed-text-GPU.modelfile
│       └── .env                      # CachyOS-specific config
├── scripts/                          # unified cross-platform scripts
│   ├── sod.sh                       # Start of Day script
│   ├── eod.sh                       # End of Day script
│   └── .envexample                  # configuration template
├── docs/                             # documentation
├── tests/                            # test suites
├── systemd/                          # systemd service files (Linux)
├── docker-compose.yml               # Qdrant deployment
├── Makefile                         # build automation
└── logs/                            # runtime logs
```

## Quick Start

1. **Clone and navigate to platform directory:**
   ```bash
   cd ollama-devops
   ```

2. **Configure environment:**
   ```bash
   # Copy the appropriate .env file for your platform
   cp platform/macbook-m4-24gb-optimized/.env scripts/.env    # for MacBook
   # OR
   cp platform/cachyos-i9-32gb-nvidia-4090/.env scripts/.env  # for CachyOS
   ```

3. **Make scripts executable:**
   ```bash
   chmod +x scripts/*.sh
   ```

4. **Start the environment:**
   ```bash
   ./scripts/sod.sh
   ```

5. **Stop the environment:**
   ```bash
   ./scripts/eod.sh
   ```

## Key Components

- **scripts/**: Unified automation scripts that auto-detect your platform and apply appropriate optimizations
- **Platform-specific directories**: Contain hardware-tuned modfiles and configuration
- **tests/**: Comprehensive test suite with unit, integration, and smoke tests
- **docs/**: Detailed documentation and API references

## Platform-Specific Features

### MacBook M4 Pro 24GB
- **Memory Optimizations**: Flash attention and KV cache quantization for 24GB unified memory
- **Models**: `qwen2.5-coder:14b` with custom DevOps fine-tuning
- **GPU**: Apple Neural Engine optimizations

### CachyOS RTX 4090
- **GPU Acceleration**: Full NVIDIA GPU offloading with CUDA
- **Models**: Large language models (`qwen2.5:72b-instruct`, `qwen2.5:7b-instruct`) with GPU-optimized modfiles
- **Performance**: Optimized for high-throughput inference

## Configuration Management

- **Platform Detection**: Scripts automatically detect your platform (macOS/Linux) and apply appropriate settings
- **Environment Variables**: Configurable via `.env` files in platform-specific directories
- **Modfiles**: Hardware-optimized model configurations for reproducible builds

## Automated Model Lifecycle

- **`sod.sh`**: Start of Day - Launches Ollama, ensures models are available, warms up optimal models, starts Qdrant
- **`eod.sh`**: End of Day - Gracefully shuts down services and cleans up resources

## Testing

```bash
# Run all tests
./tests/run_all.sh

# Run specific test suites
./tests/run_all.sh --unit    # Unit tests
./tests/run_all.sh --smoke   # Smoke tests
./tests/run_all.sh --lint    # ShellCheck linting

# Run E2E tests (requires full hardware)
./tests/e2e/run_all.sh
```

## Development

- **Makefile**: Build automation and development tasks
- **ShellCheck**: All scripts pass shellcheck validation
- **Bats**: Comprehensive test suite using Bash Automated Testing System

## Requirements

- **macOS**: macOS 13+, Ollama 0.21.2+
- **Linux**: CachyOS/Arch Linux, Ollama 0.21.2+, NVIDIA drivers with CUDA
- **Docker**: 20.10+ for Qdrant vector database
- **Hardware**: See platform-specific requirements above

## License

MIT