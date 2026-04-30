# Ollama DevOps Platform

A comprehensive project for managing and deploying Ollama AI models with DevOps best practices, including configuration management, automated deployment, and model lifecycle management across multiple platforms.

## Repository Structure

```text
.
├── ollama-devops/                   # Main unified project (active development)
│   ├── platform/                    # Platform-specific configurations
│   │   ├── macbook-m4-24gb-optimized/   # MacBook M4 Pro configuration
│   │   └── cachyos-i9-32gb-nvidia-4090/ # CachyOS RTX 4090 configuration
│   ├── scripts/                     # Cross-platform automation scripts
│   ├── tests/                       # Comprehensive test suite
│   ├── docs/                        # Documentation
│   ├── systemd/                     # systemd service definitions (Linux)
│   ├── docker-compose.yml           # Qdrant vector database
│   ├── Makefile                     # Build automation
│   ├── .envexample                  # Environment template
│   └── README.md                    # Project documentation
└── logs/                            # Runtime logs (created at runtime)
```

## Getting Started

The main project is in `ollama-devops/`. Start there:

```bash
cd ollama-devops
cat README.md
```

See the [project README](ollama-devops/README.md) for full documentation on:
- Platform setup (MacBook & CachyOS)
- Configuration management
- Test suite execution
- Systemd integration
- API endpoints

## Notes

This repository uses a unified, DRY architecture. All active development is in `ollama-devops/`. Legacy per-platform directories have been consolidated into the unified structure with platform auto-detection.
