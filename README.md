# Ollama DevOps Platform

A comprehensive project for managing and deploying Ollama AI models with DevOps best practices, including configuration management, automated deployment, and model lifecycle management across multiple platforms.

## Directory Structure

```text
.
├── ollama-devops/                   # Main unified project (see README.md inside)
│   ├── platform/                    # Platform-specific configurations
│   │   ├── macbook-m4-24gb-optimized/   # MacBook-specific configuration
│   │   └── cachyos-i9-32gb-nvidia-4090/ # CachyOS-specific configuration
│   ├── scripts/                     # Cross-platform automation scripts
│   ├── tests/                       # Comprehensive test suite
│   ├── docs/                        # Documentation
│   └── README.md                    # Platform-specific documentation
├── ollama-cachyos/                  # Legacy CachyOS directory (deprecated)
├── ollama-macbook/                  # Legacy MacBook directory (deprecated)
├── logs/                            # Runtime logs
```

## Migration Notice

This repository has been restructured for better maintainability. The main project is now in `ollama-devops/` with a DRY (Don't Repeat Yourself) architecture that eliminates code duplication.

### For New Users
Start here: `cd ollama-devops && cat README.md`

### For Existing Users
The legacy directories (`ollama-cachyos/` and `ollama-macbook/`) are deprecated but remain functional. Migrate to `ollama-devops/` for ongoing development and support.

## Quick Start (New Structure)

```bash
cd ollama-devops

# Configure for your platform
cp platform/macbook-m4-24gb-optimized/.env scripts/.env    # MacBook
# OR
cp platform/cachyos-i9-32gb-nvidia-4090/.env scripts/.env  # CachyOS

# Start the environment
chmod +x scripts/*.sh
./scripts/sod.sh
```

## Supported Platforms

- **MacBook M4 Pro 24GB**: Apple Silicon optimized with unified memory management
- **CachyOS i9-13900KS + RTX 4090**: NVIDIA GPU accelerated with high-performance optimizations

## Key Features

- **Cross-platform**: Single codebase supporting multiple hardware configurations
- **Auto-detection**: Scripts automatically detect and configure for your platform
- **Hardware optimization**: Platform-specific modfiles and configurations
- **Comprehensive testing**: Full test suite with unit, integration, and smoke tests
- **Containerized services**: Docker Compose for Qdrant vector database

See `ollama-devops/README.md` for detailed documentation.
