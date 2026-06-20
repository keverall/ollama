# System Overview

This document provides an overview of the Ollama optimized environment architecture, supporting both MacBook M4 Pro and CachyOS RTX 4090 platforms.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Ollama Optimized Environment                     │
└─────────────────────────────────────────────────────────────────────┘
                                  ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  Hardware Layer  │    │  Software Layer  │    │  Service Layer   │
└──────────────────┘    └──────────────────┘    └──────────────────┘
         ▲                   ▲                   ▲
         │                   │                   │
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ MacBook M4 Pro   │    │     macOS        │    │   Ollama Server  │
│  (24GB unified)  │    │  OR CachyOS Linux│    │     (serve)      │
└──────────────────┘    └──────────────────┘    └──────────────────┘
         │                   │                   ▲
         │                   │                   │
         ▼                   ▼                   │
┌──────────────────┐    ┌──────────────────┐    │
│  Apple Silicon   │    │   Docker Engine  │    │
│    (M4 Pro)      │    │                  │    │
└──────────────────┘    └──────────────────┘    │
         │                   │                   │
         ▼                   ▼                   │
┌──────────────────┐    ┌──────────────────┐    │
│   NVIDIA RTX 4090│    │   Qdrant Server  │    │
│    (24GB VRAM)   │    │ (vector database)│    │
└──────────────────┘    └──────────────────┘    │
         │                   │                   │
         │                   │                   │
         └───────────────────┴───────────────────┘
                                  ▼
                     ┌─────────────────────┐
                     │    System Services  │
                     └─────────────────────┘
                                ▲
                                │
            ┌───────────────────┴───────────────────┐
            ▼                                       ▼
     ┌─────────────────┐                   ┌─────────────────┐
     │  Ollama Service │                   │  Qdrant Service │
     │ (systemd/ollama │                   │  (docker-compose)│
     │  .service)      │                   │                 │
     └─────────────────┘                   └─────────────────┘
            ▲                                       ▲
            │                                       │
            │                                       │
┌─────────────────┐                       ┌─────────────────┐
│   Model Files   │                       │   Storage       │
│(platform/*/modfiles)│                   │ (qdrant_storage)│
└─────────────────┘                       └─────────────────┘
            ▲                                       ▲
            │                                       │
            │                                       │
┌─────────────────┐                       ┌─────────────────┐
│  Control Scripts│                       │    Logs         │
│ (scripts/sod.sh,│                       │  (logs/*)       │
│  scripts/eod.sh)│                       │                 │
└─────────────────┘                       └─────────────────┘
```

## Component Descriptions

### Hardware Layer

#### MacBook M4 Pro 24GB
- **Apple M4 Pro**: 24GB unified memory with GPU and Neural Engine
- **Optimization**: Flash attention and KV cache quantization for memory efficiency

#### CachyOS RTX 4090
- **NVIDIA RTX 4090**: 24GB VRAM for accelerated LLM inference
- **Intel Core i9-13900KS**: 24-core CPU for concurrent request handling
- **32GB DDR5/6000MHz RAM**: High-speed memory for data transfer to GPU

### Software Layer

- **macOS**: Apple's operating system with Metal GPU acceleration
- **CachyOS**: Optimized Arch Linux distribution with performance kernels
- **Docker Engine**: Container runtime for Qdrant deployment

### Service Layer

- **Ollama Server**: Language model serving engine with cross-platform support
- **Qdrant Server**: Vector database for embedding storage and retrieval

### System Services

- **Ollama Service**: Managed by systemd on Linux, direct process on macOS
- **Qdrant Service**: Docker Compose managed service for vector database

### Storage

- **Model Files**: Hardware-optimized modfiles in `platform/*/modfiles/` directories
- **Vector Storage**: Persistent storage for Qdrant in `./qdrant_storage`

### Control & Monitoring

- **Control Scripts**: Unified `sod.sh` and `eod.sh` with platform auto-detection
  - Linux: configure systemd, then start/stop via `systemctl`
  - macOS: direct process management
- **Logs**: Application logs in `./logs`, systemd journal for Linux service

## Platform Architecture Differences

### Platform Detection

The scripts automatically detect the platform using:
- macOS: `uname -s` returns "Darwin"
- CachyOS: `/etc/os-release` contains "CachyOS" or "Arch"

Manual override: Set `PLATFORM_OVERRIDE` environment variable (`macos`, `cachyos`, `linux`)

### Configuration Loading

Scripts load platform-specific `.env` files:
- MacBook: `platform/macbook-m4-24gb-optimized/.env`
- CachyOS: `platform/cachyos-i9-32gb-nvidia-4090/.env`

### Model Management

**MacBook** loads from `platform/macbook-m4-24gb-optimized/modfiles/`:
- `modfile-qwen-devops` → builds `qwen-devops` custom model

**CachyOS** loads from `platform/cachyos-i9-32gb-nvidia-4090/modfiles/`:
- `qwen2.5-coder:32b-gpu.modelfile` → `qwen2.5-coder:32b-gpu`
- `Qwen2.5-7B-instruct-GPU.modelfile` → `qwen2.5:7b-instruct`
- `nomic-embed-text-GPU.modelfile` → `nomic-embed-text:latest`
- `snowflake-arctic-embed.modelfile` → `snowflake-arctic-embed`

## Data Flow

1. **Startup** (`sod.sh`):
   - Detects platform and loads appropriate configuration
   - Checks system requirements (Ollama, Docker, GPU if applicable)
   - Stops any existing Ollama instances
   - Starts Ollama with platform-specific optimizations
   - Ensures models are present (pulls or creates from modfiles)
   - Warms up optimal models for the platform
   - Starts Qdrant via Docker Compose
   - Verifies service health

2. **Inference Request**:
   - Client sends request to Ollama API (`http://localhost:11434`)
   - Ollama loads appropriate model into memory (GPU for CachyOS, unified memory for MacBook)
   - Model processes request using platform-specific optimizations
   - Response returned to client

3. **Embedding Workflow**:
   - Client requests embedding via Ollama embeddings API
   - Ollama generates vector representation using embedding model
   - Vector stored in Qdrant via API (`http://localhost:6333`)
   - Vectors can be searched/similarity queried in Qdrant

4. **Shutdown** (`eod.sh`):
   - Stops Qdrant service via Docker Compose
   - Stops Ollama service (systemctl on Linux, process kill on macOS)
   - Cleans up resources

## Cost & Performance Rationale

### Why Run LLMs Locally?

Cloud LLM APIs charge per token:
- **GPT-4**: ~$30–$60 per million output tokens
- **Claude 3.5 Sonnet**: ~$15 per million output tokens
- **Ollama local**: $0 per token after initial download

For teams processing 10M tokens/month:
- Cloud cost: $150–$600/month
- One-time RTX 4090 hardware: ~$2000
- Payback period: 4–12 months

### Hardware Performance Targets

| Hardware | Model | Layers Offloaded | VRAM Used | Throughput | Latency |
|---|---|---|---|---|---|
| RTX 4090 24GB | qwen2.5:7b (full) | All | ~6 GB | ~150 tok/s | ~50 ms/tok |
| RTX 4090 24GB | qwen2.5-coder:32b-gpu | 50 / 80 | ~22 GB | ~80 tok/s | ~100 ms/tok |
| MacBook M4 Pro 24GB | qwen2.5-coder:14b | N/A (unified) | ~10 GB* | ~40 tok/s | ~300 ms/tok |

*Unified memory shared between CPU+GPU; flash attention reduces footprint.

### Model Selection Strategy

- **CachyOS**: Uses GPU-optimized modfiles that offload as many layers as fit in 24GB VRAM (typically 50 out of 80 layers for 32B models; full GPU for 7B). This maximizes throughput while staying within VRAM budget.
- **MacBook**: Uses flash attention and KV cache quantization to fit 14B models within 24GB unified memory with acceptable quality.

Warm-up (`sod.sh` Phase 5) loads models once so subsequent requests are fast. Cost is amortized across many queries.

## Environment File Setup

Platform-specific `.env` files are **gitignored** (they may contain local paths). When cloning or re-provisioning a machine:

1. Copy the template to create your local config:
   ```bash
   cp platform/macbook-m4-24gb-optimized/.envexample platform/macbook-m4-24gb-optimized/.env
   cp platform/cachyos-i9-32gb-nvidia-4090/.envexample platform/cachyos-i9-32gb-nvidia-4090/.env
   ```

2. Edit `.env` files to match your installation paths:
   - `OLLAMA_BIN`: Path to `ollama` binary (run `which ollama` to find)
   - `OLLAMA_MODELS`: Directory for model storage (ensure ≥100GB free for 32B models)
   - `OLLAMA_HOST`/`PORT`: Network binding (defaults are safe for local dev)

3. For CachyOS, also ensure `$OLLAMA_MODELS` exists and is writeable by your user:
   ```bash
   sudo mkdir -p /home/ollama/models
   sudo chown $USER:$USER /home/ollama/models
   ```

See platform-specific READMEs (`platform/*/README.md`) for full variable explanations.

## Platform Architecture Differences

The unified scripts (`sod.sh`, `eod.sh`) abstract away platform differences:

| Feature                | MacBook M4 Pro                | CachyOS RTX 4090                 |
|------------------------|-------------------------------|----------------------------------|
| **Ollama control**     | Direct process (`ollama &`)   | systemd service (`systemctl`)    |
| **GPU acceleration**   | Metal via Ollama              | CUDA via NVIDIA drivers          |
| **Modfiles**           | Custom `modfile-qwen-devops`  | GPU-optimized modfiles           |
| **Memory tuning**      | Flash attention, KV cache     | GPU layers offloading            |
| **Service type**       | No system-level service       | systemd-managed, auto-restart    |
| **Logs**               | File-based (`logs/`)          | journald + file logs             |
| **Platform detection** | Automatic (Darwin)            | Automatic (CachyOS/Arch)         |

### Bash Compatibility

Scripts are designed to run on both **macOS (bash 3.2)** and modern Linux (bash ≥5):

- **No associative arrays**: `lib_logging.sh` uses function-based lookup (`log_level_priority()`) instead of `declare -A` (unsupported in bash 3.2)
- **Portable timeout**: `sod.sh` includes `run_with_timeout()` fallback for systems without GNU `timeout` (macOS)
- **Strict mode**: All scripts use `set -euo pipefail`; variables are defaulted to avoid unbound errors with `set -u`
- **ShellCheck compliance**: Linting uses `-x` flag to follow includes and catch portability issues

## Future Extensibility

The `platform/` directory structure allows easy addition of new platforms:
1. Create `platform/<new-platform>/` directory
2. Add `modfiles/` and `.env` configuration
3. Update `detect_platform()` in scripts if needed
4. Document in platform comparison matrix

---

**Last Updated:** 2026-04-30  
**Version:** 2.0.0
