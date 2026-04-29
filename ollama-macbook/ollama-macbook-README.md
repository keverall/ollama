# Ollama Local Models Repository

This repository provides an optimized, local AI environment for a MacBook M4 Pro (24GB). It automates the setup of Ollama models, custom DevOps-tuned models, and a local Qdrant vector database for indexing and retrieval.

**Note: Run `scripts/eod.sh` when not used to save memory and cleanly shut down services.**

## Getting Started

Initialize the environment, pull required base models, create the custom DevOps model, and start the Qdrant vector database by running the startup script:

```bash
# From the repository root
./ollama-macbook/scripts/sod.sh
```

Or change into the directory first:

```bash
cd ollama-macbook
./scripts/sod.sh
```

Make sure the script is executable (`chmod +x scripts/sod.sh`) if needed.

### What the script does:

1. Stops any existing Ollama instances to ensure a clean start.
2. Starts the Ollama server directly (`$OLLAMA_BIN serve`) with memory optimizations for M4 Pro 24GB.
3. Pulls required base models: `nomic-embed-text` and `qwen2.5-coder:14b`.
4. Builds the custom DevOps model `qwen-devops` from `modfiles/modfile-qwen-devops`.
5. Preloads `qwen-devops` with a test query to warm it into memory.
6. Starts the Qdrant vector database using Docker Compose.
7. Verifies API connectivity on IPv4, IPv6, and localhost endpoints.

## Included Models

| Model | Purpose |
|-------|---------|
| **qwen-devops** | Custom DevOps-tuned model based on qwen2.5-coder:14b. Optimized for precise code generation (temperature 0.0), large context (64k), and efficient memory use on M4 Pro 24GB. |
| **qwen2.5-coder:14b** | Base model; state-of-the-art for local coding tasks, especially multi-file reasoning. Approx. 14B parameters (~9GB) with KV cache ~10-12GB, total ~21GB with quantization. |
| **nomic-embed-text** | Embedding model for indexing and retrieving local files. |

## Custom Modelfiles

The repository includes custom Modelfiles to maximize performance on the M4 Pro 24GB while leaving room for the Qdrant database and system overhead:

- **modfile-qwen-devops** (default): Creates `qwen-devops` from `qwen2.5-coder:14b`.  
  Parameters: 65536 context window, temperature 0.0, top_p 0.9, repeat_penalty 1.1, 10 threads.  
  System prompt focuses on production-grade DevOps code (Terraform, Kubernetes, CI/CD) with deterministic, low-verbosity style.

- **modfile-gemma4** (optional): Creates an alternative `gemma4-devops` model from `gemma4:e4b`.  
  Parameters: 32768 context window, temperature 0.0, top_p 0.9, repeat_penalty 1.1, 10 threads.  
  Suitable if you prefer the Gemma 4B family.

Choose which model to build by setting `DEVOPS_MODEL` in `scripts/.env` (e.g., `qwen-devops` or `gemma4-devops`).

## Configuration

Copy the example environment file and adjust as needed:

```bash
cd ollama-macbook
cp scripts/.envexample scripts/.env
# Edit scripts/.env to set your preferences
```

Key environment variables:

| Variable | Description |
|----------|-------------|
| `MODEL_LIST` | Comma-separated list of base models to ensure are present (default: `nomic-embed-text,qwen2.5-coder:14b`). |
| `DEVOPS_MODEL` | Name of the custom DevOps model to build (default: `qwen-devops`). |
| `OLLAMA_BIN` | Path to the Ollama binary (default: `/usr/local/bin/ollama`). |
| `OLLAMA_MODELS` | Path to Ollama models directory (default: `~/.ollama/models/`). |
| `OLLAMA_FLASH_ATTENTION` | Enable flash attention for memory efficiency (set to `1`). |
| `OLLAMA_KV_CACHE_TYPE` | KV cache quantization (default: `q4_0`). |
| `OLLAMA_HOST` | Bind address for Ollama server (default: `[::]:11434` for IPv6+IPv4 dual-stack). |

## Infrastructure

The environment relies on **Qdrant** for vector storage, managed via Docker Compose.

To start it manually:

```bash
docker-compose -f ollama-macbook/scripts/docker-compose.yml up -d
```

The startup script starts Qdrant automatically. Under the hood, this replaces the need for a manual `docker run` command like:

```bash
docker run -d \
  --name qdrant \
  --restart unless-stopped \
  -p 6333:6333 \
  -v qdrant_data:/qdrant/storage \
  qdrant/qdrant
```

## Cleanup

When finished, run the shutdown script to free memory:

```bash
./ollama-macbook/scripts/eod.sh
```

This stops the Ollama server (and Docker containers) gracefully.

## Notes

- The scripts assume Ollama is installed and available at the path specified in `.env`.
- Memory optimizations are tuned for a MacBook M4 Pro with 24GB RAM; adjust parameters for other hardware.
- Logs are stored in `logs/ollama-macbook-server.log` for troubleshooting.
