# System Overview

This document provides an overview of the Ollama optimized environment architecture.

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
│  NVIDIA RTX 4090 │    │     CachyOS      │    │   Ollama Server  │
│   (24GB VRAM)    │    │   Linux Distro   │    │     (serve)      │
└──────────────────┘    └──────────────────┘    └──────────────────┘
        │                   │                   ▲
        │                   │                   │
        ▼                   ▼                   │
┌──────────────────┐    ┌──────────────────┐    │
│   Intel Core i9-13900KS │    │   Docker Engine  │    │
│    (24 cores)     │    │                  │    │
└──────────────────┘    └──────────────────┘    │
        │                   │                   │
        ▼                   ▼                   │
┌──────────────────┐    ┌──────────────────┐    │
│    32GB DDR5     │    │   Qdrant Server  │    │
│   RAM @6000MHz   │    │ (vector database)│    │
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
│ (modfiles/*)    │                       │ (qdrant_storage)│
└─────────────────┘                       └─────────────────┘
           ▲                                       ▲
           │                                       │
           │                                       │
┌─────────────────┐                       ┌─────────────────┐
│  Control Scripts│                       │    Logs         │
│ (sod.sh, eod.sh)│                       │  (logs/*)       │
└─────────────────┘                       └─────────────────┘
```

## Component Descriptions

### Hardware Layer
- **NVIDIA RTX 4090**: GPU with 24GB VRAM for accelerated LLM inference
- **Intel Core i9-13900KS**: 24-core CPU for concurrent request handling
- **32GB DDR5/6000MHz RAM**: High-speed memory for data transfer to GPU

### Software Layer
- **CachyOS**: Optimized Linux distribution providing the base OS
- **Docker Engine**: Container runtime for Qdrant deployment

### Service Layer
- **Ollama Server**: Language model serving engine
- **Qdrant Server**: Vector database for embedding storage and retrieval

### System Services
- **Ollama Service**: Systemd service managing Ollama server lifecycle
- **Qdrant Service**: Docker Compose managed service for vector database

### Storage
- **Model Files**: Hardware-optimized modfiles in `modfiles/` directory
- **Vector Storage**: Persistent storage for Qdrant in `./qdrant_storage`

### Control & Monitoring
- **Control Scripts**: `sod.sh` (start) and `eod.sh` (stop) scripts
- **Logs**: Application and system logs in `./logs` directory

## Data Flow

1. **Startup** (`sod.sh`):
   - Checks system requirements (Ollama, Docker, GPU)
   - Starts Ollama service with GPU optimizations
   - Loads/creates optimized models (Qwen, embedding models)
   - Starts Qdrant via Docker Compose
   - Verifies service health

2. **Inference Request**:
   - Client sends request to Ollama API (`http://localhost:11434`)
   - Ollama loads appropriate model into GPU memory
   - Model processes request using GPU acceleration
   - Response returned to client

3. **Embedding Workflow**:
   - Client requests embedding via Ollama embeddings API
   - Ollama generates vector representation using embedding model
   - Vector stored in Qdrant via API (`http://localhost:6333`)
   - Vectors can be searched/similarity queried in Qdrant

4. **Shutdown** (`eod.sh`):
   - Stops Qdrant service via Docker Compose
   - Stops Ollama service via systemctl or process termination
   - Cleans up resources

## Environment Variables

Key environment variables used throughout the system:

- `OLLAMA_HOST`: Host interface for Ollama (default: `::`)
- `OLLAMA_PORT`: Port for Ollama API (default: `11434`)
- `OLLAMA_NUM_PARALLEL`: Number of parallel workers (default: `24`)
- `OLLAMA_MAX_LOADED_MODELS`: Max models in memory (default: `2`)
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

- Regular updates to Ollama, Docker, and NVIDIA drivers
- Monitor disk usage for vector storage growth
- Periodic log rotation and cleanup
- Backup strategies for persistent storage (Qdrant data)
