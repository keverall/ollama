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

- **Ollama Service**: Managed by systemd (Linux) or manual process (macOS)
- **Qdrant Service**: Docker Compose managed service for vector database

### Storage

- **Model Files**: Hardware-optimized modfiles in `platform/*/modfiles/` directories
- **Vector Storage**: Persistent storage for Qdrant in `./qdrant_storage`

### Control & Monitoring

- **Control Scripts**: Unified `sod.sh` and `eod.sh` scripts with platform auto-detection
- **Logs**: Application and system logs in `./logs` directory

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
- `Qwen2.5-72B-instruct-GPU.modelfile` → `qwen2.5:72b-instruct`
- `Qwen2.5-7B-instruct-GPU.modelfile` → `qwen2.5:7b-instruct`
- `nomic-embed-text-GPU.modelfile` → `nomic-embed-text:latest`

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

## Environment Variables

Key environment variables used throughout the system:

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

**Model Configuration:**
- `DEFAULT_MODELS`: Comma-separated model list (platform-specific defaults)
- `DEVOPS_MODEL`: Custom DevOps model name (MacBook only)

**Qdrant Configuration:**
- `QDRANT_PORT`: Port for Qdrant HTTP API (default: `6333`)
- `QDRANT_GRPC_PORT`: Port for Qdrant gRPC API (default: `6334`)

## Security Considerations

- Services bind to all interfaces (`0.0.0.0` or `::`) for accessibility
- No authentication enabled by default (suitable for local/dev environments)
- For production, consider:
  - Reverse proxy with authentication
  - Firewall rules to limit access
  - API keys or token-based authentication
  - TLS encryption for API endpoints

## Scalability

- **Vertical Scaling**: Increase GPU/VRAM for larger models
- **Horizontal Scaling**: Multiple instances behind load balancer
- **Model Parallelism**: Distribute large models across multiple GPUs
- **Caching Layers**: Add Redis or similar for frequent query caching

## Maintenance

- Regular updates to Ollama, Docker, and NVIDIA drivers (CachyOS)
- Monitor disk usage for vector storage growth
- Periodic log rotation and cleanup
- Backup strategies for persistent storage (Qdrant data)

## Cross-Platform Compatibility

The unified scripts (`sod.sh`, `eod.sh`) abstract away platform differences:

| Feature | MacBook M4 Pro | CachyOS RTX 4090 |
|---------|----------------|------------------|
| **Ollama control** | Process kill | systemctl + pkill |
| **GPU acceleration** | Metal via Ollama | CUDA via NVIDIA drivers |
- **Modfiles** | Custom modfile-qwen-devops | GPU-optimized modfiles |
| **Memory tuning** | Flash attention, KV cache | GPU layers offloading |
- **Platform detection** | Automatic (Darwin) | Automatic (CachyOS/Arch) |

## Future Extensibility

The `platform/` directory structure allows easy addition of new platforms:
1. Create `platform/<new-platform>/` directory
2. Add `modfiles/` and `.env` configuration
3. Update `detect_platform()` in scripts if needed
4. Document in platform comparison matrix

---
**Last Updated:** 2026-04-30  
**Version:** 1.0.0
