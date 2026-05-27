# Systemd Integration Guide

## Overview

The Ollama DevOps project uses **systemd for Linux service management** (CachyOS, Arch, etc.) while **macOS uses direct process management**. This document explains the architecture, setup, and troubleshooting for the unified cross-platform scripts.

**Cross-platform compatibility**:
- Scripts run on both macOS (bash 3.2) and Linux (bash ≥5)
- `lib_logging.sh` avoids bash 4+ features (associative arrays) for macOS support
- `sod.sh` includes portable `timeout` fallback for systems without GNU coreutils
- Automatic platform detection selects appropriate service management strategy

## Architecture

### Two Management Models

| Platform | Management | Start Command | Stop Command |
|----------|------------|---------------|--------------|
| **Linux (systemd)** | systemd service | `systemctl start ollama` | `systemctl stop ollama` |
| **macOS** | Direct process | `ollama serve &` | `pkill ollama` |

### Key Principle

**Systemd is the single source of truth on Linux**:
- `sod.sh` configures and starts the systemd service (not direct process)
- `eod.sh` stops and disables the systemd service (not direct kill)
- systemd handles automatic restarts based on `Restart=ondemand` policy

## Systemd Service Details

### Service File Location

```
/etc/systemd/system/ollama.service
```

This file is installed/updated by `sod.sh` from:
```
ollama-devops/systemd/ollama.service
```

### Environment Configuration

The service loads environment from:
- `/etc/default/ollama` (Debian/Ubuntu style) or
- `/etc/sysconfig/ollama` (Red Hat style)

`sod.sh` writes platform-specific values to the appropriate file, sourced from `platform/<platform>/.env`.

**Setting up the platform `.env` first** (needed on fresh clone):

```bash
# From project root, copy the template for your platform:
cp platform/macbook-m4-24gb-optimized/.envexample platform/macbook-m4-24gb-optimized/.env
# or for CachyOS:
cp platform/cachyos-i9-32gb-nvidia-4090/.envexample platform/cachyos-i9-32gb-nvidia-4090/.env

# Edit .env to set OLLAMA_BIN and OLLAMA_MODELS paths if needed
nano platform/cachyos-i9-32gb-nvidia-4090/.env
```

Then run `./scripts/sod.sh` (or `sudo ./scripts/sod.sh`) and it will populate `/etc/default/ollama` from your platform `.env`.

**Manual edit** (after automatic write):
```bash
sudo nano /etc/default/ollama
```

After editing:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Typical contents (Linux/CachyOS):
```bash
OLLAMA_HOST=::
OLLAMA_PORT=11434
OLLAMA_NUM_PARALLEL=24
OLLAMA_MAX_LOADED_MODELS=2
OLLAMA_GPU_LAYERS=50
CUDA_VISIBLE_DEVICES=0
```

### GPU Device Access (CachyOS/NVIDIA)

A drop-in override provides GPU device permissions:
```
/etc/systemd/system/ollama.service.d/cachyos-nvidia.conf
```

Create this directory and file manually or via deployment script:
```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo cp ollama-devops/systemd/platform-overrides/cachyos-nvidia.conf /etc/systemd/system/ollama.service.d/
```

After adding drop-in, reload:
```bash
sudo systemctl daemon-reload
```

### Restart Policy

- `Restart=ondemand`: Service restarts only when explicitly started or after failure (not always-on)
- Controlled by sod/eod scripts for predictable lifecycle
- Prevents respawning during maintenance

## Setup and Deployment

### First-Time Installation

**Prerequisites:**
- Install Ollama (from AUR: `yay -S ollama` or download from ollama.ai)
- Ensure `.env` exists for your platform (copy from `.envexample`):
  ```bash
  cp platform/cachyos-i9-32gb-nvidia-4090/.envexample platform/cachyos-i9-32gb-nvidia-4090/.env
  # Edit if needed: nano platform/cachyos-i9-32gb-nvidia-4090/.env
  ```

1. **Install systemd service** (auto-done by sod.sh):
   ```bash
   ./scripts/sod.sh
   ```
   This copies `ollama-devops/systemd/ollama.service` to `/etc/systemd/system/ollama.service`

2. **Enable service** (auto-done by sod.sh):
   ```bash
   sudo systemctl enable ollama
   ```

3. **Configure environment** (auto-done by sod.sh):
   - sod.sh writes platform-specific settings to `/etc/default/ollama`
   - Re-run sod.sh to regenerate after changes

### Manual Installation

If auto-install fails:

```bash
# Copy service file
sudo cp ollama-devops/systemd/ollama.service /etc/systemd/system/

# (Optional) Add GPU overrides for NVIDIA
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo cp ollama-devops/systemd/platform-overrides/cachyos-nvidia.conf /etc/systemd/system/ollama.service.d/

# Reload systemd
sudo systemctl daemon-reload

# Enable service
sudo systemctl enable ollama
```

### Environment Configuration

Edit `/etc/default/ollama` (or `/etc/sysconfig/ollama`) for persistent settings:

```bash
# /etc/default/ollama
OLLAMA_HOST=::
OLLAMA_PORT=11434
OLLAMA_NUM_PARALLEL=24
OLLAMA_MAX_LOADED_MODELS=2
OLLAMA_GPU_LAYERS=50
CUDA_VISIBLE_DEVICES=0
```

After editing, reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

## operational Workflow

### Starting (sod.sh)

1. Detect platform (CachyOS → systemd)
2. Stop any stray Ollama processes
3. Install/update systemd service file (if changed)
4. `systemctl daemon-reload`
5. `systemctl enable ollama` (ensure auto-start on boot)
6. Write `/etc/default/ollama` with platform settings
7. `systemctl daemon-reload` (pick up env changes)
8. `systemctl start ollama`
9. Wait for API readiness
10. Pull/warm models, start Qdrant

### Stopping (eod.sh)

1. Disable auto-restart: `systemctl disable ollama`
2. Stop service: `systemctl stop ollama`
3. Kill any remaining processes (fallback)
4. Stop Qdrant containers

## Troubleshooting

### Port Already in Use

**Symptom**: `Error: listen tcp 0.0.0.0:11434: bind: address already in use`

**Cause**: Stray `ollama serve` processes not managed by systemd.

**Fix**:
```bash
# Check processes
ps aux | grep ollama

# Kill stray processes
sudo pkill -9 ollama

# Then restart via sod.sh
./scripts/sod.sh
```

### Service Won't Start

**Check status**:
```bash
sudo systemctl status ollama
```

**View logs**:
```bash
sudo journalctl -u ollama -n 50 --no-pager
```

**Common issues**:
- Permissions on `/etc/default/ollama` should be readable by `ollama` user
- GPU devices accessible: `/dev/nvidia0`, `/dev/nvidiactl`, etc.
- Correct `OLLAMA_BIN` path (default `/usr/local/bin/ollama`)

### Permission Denied Writing Env File

**Symptom**: sod.sh warns "Cannot write to /etc/default/ollama (requires root)"

**Fix**: Run sod.sh with sudo or as root:
```bash
sudo ./scripts/sod.sh
```

Or pre-create the file:
```bash
sudo touch /etc/default/ollama
sudo chown $USER /etc/default/ollama  # then run sod.sh as current user
```

### systemd Not Available

**Symptom**: `systemctl: command not found`

**Cause**: Container environment or non-standard init system.

**Fix**: Ensure you're on a standard Linux installation with systemd. For containers, you may need to run Ollama manually; set `PLATFORM_OVERRIDE=macos` to force direct process management (not recommended for production).

## Maintenance

### Updating Service File

When `ollama-devops/systemd/ollama.service` changes, re-run `sod.sh` to propagate. sod.sh detects differences and copies the new file automatically.

### Disabling Systemd Management

To fall back to direct process management (not recommended):

```bash
# Disable and stop service
sudo systemctl disable ollama
sudo systemctl stop ollama

# Remove service file
sudo rm /etc/systemd/system/ollama.service
sudo systemctl daemon-reload

# Use direct start
PLATFORM_OVERRIDE=macos ./scripts/sod.sh
```

## Security Notes

- Service runs as `ollama` user (created by package manager or manually)
- GPU device access granted to `ollama` user via systemd `DeviceAllow`
- Environment file `/etc/default/ollama` should be owned by root, mode 644
- No authentication on API by default; suitable for local/dev only

## Future Improvements

- Create systemd-tmpfiles configuration for /etc/default/ollama with correct permissions
- Add systemd watchdog for health monitoring
- Integrate with logrotate for journald
- Provide Ansible/Packer scripts for automated deployment
