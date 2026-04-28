# Ollama Local Models Repository

This repository provides an optimized, local AI environment for a MacBook M4 Pro (24GB). It automates the setup of Ollama models, custom DevOps-tuned models, and a local Qdrant vector database for indexing and retrieval.

**Note: Run `scripts/EOD-Stop-models.sh` when not used to save memory and cleanly shut down services.**

## Getting Started

To initialize the environment, pull the required base models, create custom models, and start the Qdrant vector database, run the startup script:

```bash
/bin/bash scripts/start-models.sh
```

### What the script does:

1. Starts the Ollama service via Homebrew (`brew services start ollama`).
2. Pulls required base models (`nomic-embed-text`, `gemma4:26b`).
3. Compiles custom, optimized model (`gemma4-devops`) using the provided Modelfile.
4. Starts the Qdrant vector database using Docker Compose.
5. Preloads the `gemma4-devops` model with a test query by running `SOD-Start-models.sh`.

## Included Models

### Your Best Models for M4 Pro 24GB

| Model | Why Use |
|-------|---------|
| **gemma4-devops** | Your custom DevOps model. Optimized for precise code generation and reasoning, leaving room for Qdrant and system overhead. |
| **gemma4:26b** | Base model, optimized for coding and reasoning. |
| **nomic-embed-text** | Used for embeddings and indexing local files. |

## Custom Modelfiles

The repository includes custom Modelfiles tailored to maximize performance on the M4 Pro 24GB while leaving room for the Qdrant database and system overhead:

- `modfile-gemma4`: Creates `gemma4-devops` with an 8192 context window, lowered temperature (0.3) for precise coding, top P at 0.9 for diversity, and adjusted repeat penalties (1.1).

## Infrastructure

The environment relies on **Qdrant** for vector storage, managed via Docker Compose. 

To start it manually:

```bash
docker-compose -f docker-compose.yml up -d
```

Under the hood, this replaces the need for a manual docker run command like:

```bash
docker run -d \
  --name qdrant \
  --restart unless-stopped \
  -p 6333:6333 \
  -v qdrant_data:/qdrant/storage \
  qdrant/qdrant
```
