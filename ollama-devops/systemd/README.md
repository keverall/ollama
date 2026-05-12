# Systemd Service Files

This directory contains systemd service definitions for Ollama. `sod.sh` automatically installs and configures these on **Linux** (CachyOS/Arch). On **macOS**, scripts use direct process management and do not use systemd.

## Cross-Platform Note

- `ollama.service` - Main service unit (installed to `/etc/systemd/system/`)
- `platform-overrides/` - Drop-in overrides for specific platforms (optional)

## Installation

`sod.sh` handles installation automatically:

```bash
./scripts/sod.sh
```

It copies `ollama.service` to `/etc/systemd/system/` and runs `systemctl daemon-reload`.

## Manual Installation

```bash
sudo cp systemd/ollama.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ollama
```

## Platform Overrides

### NVIDIA GPU (CachyOS)

For GPU acceleration, create a drop-in:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo cp systemd/platform-overrides/cachyos-nvidia.conf /etc/systemd/system/ollama.service.d/
sudo systemctl daemon-reload
```

This adds `DeviceAllow` directives for `/dev/nvidia*` devices.

### CPU-Only

Use the default service or apply `linux-nonvidia.conf` override.

## Environment Configuration

The service loads environment from `/etc/default/ollama` (or `/etc/sysconfig/ollama` on Red Hat derived). `sod.sh` writes platform-specific values automatically. To customize manually:

```bash
sudo nano /etc/default/ollama
```

Typical contents:
```bash
OLLAMA_HOST=::
OLLAMA_PORT=11434
OLLAMA_NUM_PARALLEL=24
OLLAMA_MAX_LOADED_MODELS=2
OLLAMA_GPU_LAYERS=50
CUDA_VISIBLE_DEVICES=0
```

After editing:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

## Lifecycle

- **Start**: `sudo systemctl start ollama` (or `./scripts/sod.sh`)
- **Stop**: `sudo systemctl stop ollama` (or `./scripts/eod.sh`)
- **Status**: `sudo systemctl status ollama`
- **Logs**: `sudo journalctl -u ollama -f`

## Notes

- Service user: `ollama` (created by Ollama package)
- GPU access: Only added with `cachyos-nvidia.conf` override
- Restart policy: `on-failure` (restarts after crashes, not on clean stop)
- Service is disabled during `eod.sh` to prevent respawns, re-enabled by `sod.sh`
