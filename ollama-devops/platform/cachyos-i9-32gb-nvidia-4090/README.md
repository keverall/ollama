# CachyOS RTX 4090 Platform Configuration

## Overview

This directory contains platform-specific configuration for **CachyOS/Arch Linux with NVIDIA RTX 4090 GPU (24GB VRAM) and 32GB system RAM**.

## Files

- `.env` — Your local environment overrides (gitignored). Copy from `.envexample`.
- `.envexample` — Template with all supported variables and documentation.
- `modfiles/` — GPU-optimized Ollama modfiles for NVIDIA CUDA.

## Quick Start (After Clone)

```bash
# 1. Create your .env from the template
cp .envexample .env

# 2. Adjust OLLAMA_MODELS path if desired (default: /home/ollama/models)
#    Ensure directory exists and is writable
nano .env

# 3. Ensure Docker is running for Qdrant
sudo systemctl enable --now docker

# 4. Run start-of-day script (requires sudo for systemd)
cd .. && sudo ./scripts/sod.sh
```

## Platform Optimizations

### NVIDIA RTX 4090 (24GB VRAM)

Ollama leverages CUDA for GPU acceleration. The key is **layer offloading**: transformer layers run on GPU until VRAM is full, remaining layers fall back to CPU.

**GPU Layer Configuration (`OLLAMA_GPU_LAYERS`):**

| Model | Total Layers | Layers Offloaded | VRAM Used | CPU Fallback |
|-------|-------------|-----------------|-----------|--------------|
| `qwen2.5:7b` (~4.5B) | 48 | 48 (all) | ~6 GB | None |
| `qwen2.5-coder:32b` | 80 | 50 | ~22 GB | 30 layers |
| `qwen2.5-coder:32b` | 80 | 80 (all) | ~32 GB | None (won't fit) |

Setting `num_gpu=999` in modfiles means "offload as many layers as fit in VRAM". The actual offload is determined at runtime by available VRAM.

**Tuning guide:**
- RTX 4090 24GB: Use `OLLAMA_GPU_LAYERS=50` for 32B models (leaves 2GB headroom)
- RTX 3090 24GB: Same settings work
- RTX 4080 16GB: Reduce to `OLLAMA_GPU_LAYERS=30` for 32B models, or use 14B models

### Parallelism

`OLLAMA_NUM_PARALLEL=24` matches the i9-13900KS 24-core CPU. For other CPUs, set to logical core count (including hyperthreading). Too high causes thrashing; too low underutilizes CPU.

### Systemd Service

On Linux, `sod.sh` installs `ollama.service` to `/etc/systemd/system/` and configures:
- `EnvironmentFile=/etc/default/ollama` → loads these variables
- `User=ollama` → runs as non-root service user
- `Restart=ondemand` → service restart only when needed (not always-on)
- `DeviceAllow=/dev/nvidia*` → GPU access via drop-in override

## Environment Variables Explained

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_BIN` | `ollama` | Path to ollama binary (usually `/usr/local/bin/ollama`) |
| `OLLAMA_HOST` | `[::]:11434` | Bind address (IPv6+IPv4) |
| `OLLAMA_PORT` | `11434` | API port |
| `OLLAMA_MODELS` | `/home/ollama/models` | Directory for model weights (must be on partition with ~100GB free per 32B model) |
| `OLLAMA_NUM_PARALLEL` | `24` | Number of parallel inference threads (match CPU cores) |
| `OLLAMA_MAX_LOADED_MODELS` | `2` | Max models kept in memory simultaneously (GPU+RAM budget) |
| `OLLAMA_GPU_LAYERS` | `50` | Number of transformer layers to run on GPU (0 = CPU only, higher = more GPU) |
| `CUDA_VISIBLE_DEVICES` | `0` | Which GPU to use (multi-GPU systems) |
| `DEFAULT_MODELS` | `qwen2.5-coder:32b-gpu,qwen2.5:7b-instruct,nomic-embed-text:latest` | Models to ensure at startup |
| `DEVOPS_MODEL` | *(empty)* | Not used on CachyOS (MacBook-specific custom model) |
| `QDRANT_PORT` | `6333` | Qdrant HTTP API |
| `QDRANT_GRPC_PORT` | `6334` | Qdrant gRPC API |

## Models

### GPU-Optimized 32B Coder
- **Modfile**: `qwen2.5-coder:32b-gpu.modelfile`
- **Base**: `qwen2.5-coder:32b` (~20GB download)
- **GPU layers**: 50 of 80 → ~22 GB VRAM + ~8 GB RAM
- **Performance**: ~80 tokens/sec, ~100ms/token latency
- **Use**: Heavy coding tasks, complex reasoning

### Fast 7B Instruct
- **Modfile**: `Qwen2.5-7B-instruct-GPU.modelfile`
- **Base**: `qwen2.5:7b-instruct` (~4.2 GB)
- **GPU layers**: all 48 → ~6 GB VRAM, negligible RAM
- **Performance**: ~150 tokens/sec, ~50ms/token
- **Use**: Quick queries, chat, simple tasks

### Embedding Model
- **Modfile**: `nomic-embed-text-GPU.modelfile`
- **Base**: `nomic-embed-text:latest` (~0.5 GB)
- **Use**: RAG pipelines, vector search in Qdrant

## Installation Notes

**Ollama on Arch/CachyOS**: Install from AUR: `yay -S ollama` or `paru -S ollama`. Binary is typically `/usr/local/bin/ollama`.

**Docker**: Required for Qdrant. Install: `sudo pacman -S docker`. Start: `sudo systemctl enable --now docker`.

**Passwordless sudo**: `sod.sh` manages systemd service. Configure once: `sudo ./scripts/initialisation/setup_passwordless_sudo.sh` or manually add to `/etc/sudoers`:
```
$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start ollama
$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop ollama
$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl disable ollama
```

**GPU Device Permissions**: Install NVIDIA drivers (nvidia, nvidia-utils, nvidia-container-toolkit). Deploy the CachyOS drop-in:
```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo cp platform-overrides/cachyos-nvidia.conf /etc/systemd/system/ollama.service.d/
sudo systemctl daemon-reload
```

This grants the `ollama` service user access to `/dev/nvidia*` devices.

## Performance Expectations

Latency is dominated by model size and GPU offload:

- **7B models**: 40–150 tok/s (fully GPU-resident → extremely fast)
- **32B models**: 60–90 tok/s (partial GPU, partial CPU)
- **First token latency**: 100–300ms (GPU kernel compilation on cold start)
- **Steady-state**: After warm-up, sequential generation is linear

During `sod.sh` warm-up (Phase 5), models are "primed" so kernel caches are warm. First real query may be slower; subsequent queries are fast.

## Troubleshooting

**"CUDA out of memory"**
Reduce `OLLAMA_GPU_LAYERS` in `.env` (try 40 or 30). Or switch to 14B models.

**"Failed to pull model"**
Ensure internet connectivity; large models (32B = ~20GB) require stable connection.

**Systemd service not starting**
Check: `journalctl -u ollama -n 50`. Common issues:
- `/etc/default/ollama` unreadable by `ollama` user (fix: `sudo chmod 644 /etc/default/ollama`)
- GPU device permissions missing (install `cachyos-nvidia.conf` override)
- `OLLAMA_BIN` path mismatch

**Docker permission denied**
Add user to docker group: `sudo usermod -aG docker $USER` and re-login.
