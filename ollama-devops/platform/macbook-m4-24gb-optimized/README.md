# MacBook M4 Pro 24GB Platform Configuration

## Overview

This directory contains platform-specific configuration for **Apple Silicon MacBook Pro with M4 chip and 24GB unified memory**.

## Files

- `.env` — Your local environment overrides (gitignored). Copy from `.envexample`.
- `.envexample` — Template with all supported variables and documentation.
- `modfiles/` — Hardware-optimized Ollama modfiles for MacBook.

## Quick Start (After Clone)

```bash
# 1. Create your .env from the template
cp .envexample .env

# 2. Verify OLLAMA_BIN path (find with: which ollama)
#    Typically /usr/local/bin/ollama or /opt/homebrew/bin/ollama
nano .env   # adjust as needed

# 3. Run start-of-day script
cd .. && ./scripts/sod.sh
```

## Platform Optimizations

### Apple Silicon (M4 Pro)

Unlike x86 CPUs, Apple Silicon uses **unified memory** — both CPU and GPU share the same 24GB pool. This eliminates PCIe transfers, so inference is faster than discrete GPU for smaller models, but limited by total memory.

**Key parameters:**

| Variable | Value | Purpose |
|----------|-------|---------|
| `OLLAMA_FLASH_ATTENTION=1` | Enabled | Reduces KV cache memory for attention layers by ~50%. Critical for fitting 14B models in 24GB. |
| `OLLAMA_KV_CACHE_TYPE=q4_0` | Quantized | 4-bit KV cache quantization. Slight quality trade-off, large memory savings. |
| `OLLAMA_NUM_PARALLEL` | Inherited from top-level | Number of parallel inference threads. M4 Pro has 10 CPU cores; use ~10–16 for optimal throughput. |

### Models

**DEVOPS_MODEL: `qwen-devops`**
- Built from `modfile-qwen-devops` (base: `qwen2.5-coder:14b`)
- Fine-tuned for DevOps tasks (Terraform, K8s, Python, Go)
- Optimized with flash attention → fits in ~12GB (leaves room for other apps)
- Warm-up: ~30 seconds at startup (loaded into unified memory)

**Embedding model: `nomic-embed-text`**
- Used for vector embeddings (RAG via Qdrant)
- Lightweight (~1GB), fast inference
- Cached in memory after first use

**Default list:** `nomic-embed-text, qwen2.5-coder:14b`

## Environment Variables Explained

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_LIST` | `nomic-embed-text,qwen2.5-coder:14b` | Models to ensure at startup (comma-separated) |
| `DEVOPS_MODEL` | `qwen-devops` | Custom DevOps model; used for warm-up |
| `OLLAMA_BIN` | `/usr/local/bin/ollama` | Full path to ollama binary |
| `OLLAMA_MODELS` | `~/.ollama/models` | Where model weights are stored (~40–80GB total) |
| `OLLAMA_HOST` | `[::]:11434` | Bind address (IPv6+IPv4 dual-stack) |
| `OLLAMA_FLASH_ATTENTION` | `1` | Enable flash attention (M-series GPU optimization) |
| `OLLAMA_KV_CACHE_TYPE` | `q4_0` | KV cache quantization (options: q4_0, q4_1, q5_0, q8_0) |
| `QDRANT_PORT` | `6333` | Qdrant HTTP API port |

## Notes

- **No sudo required**: macOS uses direct process management (`ollama serve &`), not systemd.
- **Logs**: Written to `../logs/` directory (created automatically).
- **GPU**: Apple Neural Engine via Metal; Ollama handles it transparently.
- **Cold start**: First model load takes 30–60 seconds (GPU kernels compile). Warm-up mitigates this.
- **Context size**: `num_ctx=65536` set in modfile for long-context code reviews.

## Performance Expectations

- **qwen2.5-coder:14b**: ~40 tokens/sec, ~300ms/token latency
- **nomic-embed-text**: >100 tokens/sec

These are stable on MacBook M4 Pro; no swap usage expected if only 1–2 models loaded.

## Customization

To use different models:
1. Edit `.env`: change `MODEL_LIST` and create corresponding `modfiles/` entries
2. Run `./scripts/sod.sh` to pull/create models
3. Update warm-up logic in `sod.sh` (Phase 5) if you want different models preloaded

## Troubleshooting

**"ollama: command not found"**
Update `OLLAMA_BIN` in `.env` to your installation path: `which ollama`

**Out of memory errors**
Reduce `MODEL_LIST` to smaller models; `qwen2.5-coder:7b` is available if 14B doesn't fit.

**Slow inference**
Ensure `OLLAMA_FLASH_ATTENTION=1` and `OLLAMA_KV_CACHE_TYPE=q4_0` are set. Check `log` output for warnings.
