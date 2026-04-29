# Ollama DevOps Project

A comprehensive project for managing and deploying Ollama AI models with DevOps best practices, including configuration management, automated deployment, and model lifecycle management.

## Project Structure

```text
.
├── logs/
│   ├── ollama-macbook-server.log
│   └── ollama-server.log
└── ollama-macbook/
    ├── README.md
    ├── modfiles/
    │   ├── modfile-gemma4
    │   └── modfile-qwen-devops
    └── scripts/
        ├── .env              # local environment (gitignored)
        ├── .envexample
        ├── eod.sh
        ├── docker-compose.yml
        └── sod.sh
```

## Key Components

- **ollama-macbook/**: Main project directory containing scripts, modfiles, and documentation.
- **modfiles/**: Custom Modelfiles for building optimized Ollama models.
- **scripts/**: Automation scripts for starting/stopping models and managing Docker services.
- **.env** (in scripts/): Local environment configuration (not committed; copy from .envexample).
- **logs/**: Server logs for monitoring and troubleshooting.

## Project Features

### Configuration Management
- Environment variables defined in `.env` (with template `.envexample`) control model selection, paths, and memory optimizations.
- Modelfiles provide reproducible model builds with tailored parameters for the M4 Pro 24GB.

### Automated Model Lifecycle
- `sod.sh`: Ensures Ollama is running, pulls/base models, builds the custom DevOps model, preloads it, and starts Qdrant.
- `eod.sh`: Gracefully shuts down Ollama and Docker containers to free system resources.

### Containerized Services
- Qdrant vector database is managed with Docker Compose for local RAG/embeddings indexing.

### Memory Optimizations
- Flash attention (`OLLAMA_FLASH_ATTENTION=1`) and KV cache quantization (`OLLAMA_KV_CACHE_TYPE=q4_0`) are enabled by default to fit 14B models within 24GB RAM.

### Models
- Base models: `nomic-embed-text` (embeddings), `qwen2.5-coder:14b` (code generation).
- Custom model: `qwen-devops` (DevOps-tuned, built from modfile-qwen-devops).
- Optional: `gemma4-devops` (alternative custom model via modfile-gemma4).

### Logging
- Ollama server logs are written to `logs/ollama-macbook-server.log`.
