# Ollama Local Models Repository

This repository provides an optimized, local AI environment for a MacBook M4 Pro (24GB). It automates the setup of Ollama models, custom DevOps-tuned models, and a local Qdrant vector database for indexing and retrieval.

**Note: Run `brew services stop ollama` when not used to save memory**

## Getting Started

To initialize the environment, pull the required base models, create custom models, and start the Qdrant vector database, run the startup script:

```bash
/bin/bash scripts/start-models.sh
```

### What the script does:
1. Starts the Ollama service via Homebrew (`brew services start ollama`).
2. Pulls required base models (`nomic-embed-text`, `qwen2.5-coder:14b`, `qwen3.6`, `phi4`).
3. Compiles custom, optimized models (`qwen2.5-coder:14b-devops` and `phi4-devops`) using the provided Modelfiles.
4. Starts the Qdrant vector database using Docker Compose.

## Included Models

### Your Best Models for M4 Pro 24GB

| Model | Why Use |
|-------|---------|
| **qwen2.5-coder:14b-devops** | Your custom DevOps model (code-tuned). Optimized for precise code generation. |
| **qwen3.6** | Latest (April 2026), 256K context, excellent for agentic coding. |
| **phi4 / phi4-devops** | Best reasoning for debugging (84.8% MMLU). <br>**Note: Does not support tools!** Cannot automatically edit files or run commands. **Best for:** Pasting tricky code to find logical bugs, architecture planning, and manual code review in Ask/Chat mode. |
| **nomic-embed-text** | Used for embeddings and indexing local files. |

## Custom Modelfiles

The repository includes custom Modelfiles tailored to maximize performance on the M4 Pro 24GB while leaving room for the Qdrant database and system overhead:

- `modfile-qwen`: Creates `qwen2.5-coder:14b-devops` with an 8192 context window, lowered temperature (0.3) for precise coding, and adjusted repeat penalties.
- `modfile-phi4`: Creates `phi4-devops` with similar performance tweaks (8192 context, 0.3 temp).

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
