# Migration Guide: Systemd Integration

## Overview

Version 2.0 of Ollama DevOps introduces systemd-based service management on Linux. If you're upgrading from an earlier version that used direct process management (`ollama serve &`), follow this guide to migrate cleanly.

## What Changed

### Before (v1.x)
- `sod.sh` ran `ollama serve &` directly
- `eod.sh` used `pkill` to stop processes
- No systemd integration
- Process conflicts possible when multiple managers active

### After (v2.x)
- **Linux**: `sod.sh` configures and starts systemd service (`systemctl start ollama`)
- **Linux**: `eod.sh` stops and disables systemd service
- **macOS**: unchanged (still direct process management)
- Single authoritative process manager per platform
- Cleaner lifecycle, automatic restart on failure, proper logging via journald

## Migration Steps

### 1. Stop Existing Ollama Instances

First, shut down any running Ollama processes using the old method:

```bash
# Stop via eod.sh (old version) OR manually:
pkill -9 ollama
# Verify no ollama processes remain
pgrep ollama && echo "Still running!" || echo "Clear"
```

### 2. Update Scripts

Pull the latest changes:

```bash
cd ollama-devops
git pull origin main  # or your branch
chmod +x scripts/*.sh
```

### 3. Remove Old Systemd Service (if any)

If you previously created a systemd service manually, remove it to avoid conflicts:

```bash
sudo systemctl stop ollama 2>/dev/null || true
sudo systemctl disable ollama 2>/dev/null || true
sudo rm -f /etc/systemd/system/ollama.service
sudo systemctl daemon-reload
```

### 4. Run New sod.sh

Start with the new systemd-integrated version:

```bash
./scripts/sod.sh
```

**First run will:**
- Detect platform (Linux → systemd)
- Install new `ollama-devops/systemd/ollama.service` to `/etc/systemd/system/`
- Create/update `/etc/default/ollama` with platform env vars
- Run `systemctl daemon-reload`
- Enable and start the `ollama` service
- Pull and warm models as before

You may be prompted for sudo password to install the service file and write `/etc/default/ollama`.

### 5. Verify Systemd is Managing Ollama

```bash
# Check service status
sudo systemctl status ollama

# View logs (journald)
sudo journalctl -u ollama -f

# Compare with old process list
ps aux | grep ollama
# Should show: /usr/local/bin/ollama serve (as ollama user)
```

### 6. Test Normal Workflow

```bash
# API should work
curl http://localhost:11434/api/tags

# Models available?
ollama list

# Run a model
ollama run qwen2.5:7b-instruct "Hello"
```

### 7. Cleanup (Optional)

If you have old service files lingering:

```bash
# Old locations that might exist (safe to remove)
sudo rm -f /lib/systemd/system/ollama.service
sudo rm -f /usr/lib/systemd/system/ollama.service
sudo systemctl daemon-reload
```

## Rollback

If you need to revert to direct process management temporarily:

```bash
# Stop and disable systemd service
./scripts/eod.sh   # or: sudo systemctl disable --now ollama

# Remove systemd service (optional)
sudo rm /etc/systemd/system/ollama.service
sudo systemctl daemon-reload

# Force direct mode by overriding platform
PLATFORM_OVERRIDE=macos ./scripts/sod.sh
```

**Note**: This is not recommended for long-term use on Linux; systemd provides better supervision.

## Post-Migration Checklist

- [ ] Old `ollama` processes not running (only systemd-managed)
- [ ] `/etc/systemd/system/ollama.service` exists and is enabled
- [ ] `/etc/default/ollama` contains platform-specific settings
- [ ] Models accessible via API
- [ ] `sod.sh`/`eod.sh` work without errors
- [ ] Journalctl logs visible: `sudo journalctl -u ollama -n 20`

## Troubleshooting

### "Port 11434 already in use"

Old stray processes still running:

```bash
sudo pkill -9 ollama
sleep 1
# Verify free
sudo lsof -i :11434
```

Then restart via sod.sh.

### "Failed to install systemd service file"

`sod.sh` needs write access to `/etc/systemd/system/`:

```bash
# Run with sudo (not recommended for whole script but works)
sudo ./scripts/sod.sh

# OR pre-install service manually:
sudo cp ollama-devops/systemd/ollama.service /etc/systemd/system/
sudo systemctl daemon-reload
# Then run sod.sh without sudo (it will detect installed service)
```

### "Permission denied writing /etc/default/ollama"

Same as above: run with sudo or pre-create the file with appropriate permissions:

```bash
sudo touch /etc/default/ollama
sudo chown $USER /etc/default/ollama  # if running as non-root
```

### Service fails to start

Check logs:

```bash
sudo systemctl status ollama -l
sudo journalctl -u ollama -n 50 --no-pager
```

Common causes:
- Missing `/etc/default/ollama` permissions (should be readable by `ollama` user)
- GPU device permissions (if using NVIDIA, ensure `cachyos-nvidia.conf` drop-in installed)
- Incorrect `OLLAMA_BIN` path in service file (default `/usr/local/bin/ollama`)

### "systemctl: command not found"

You're on a system without systemd (e.g., container, WSL). Use direct mode:

```bash
PLATFORM_OVERRIDE=macos ./scripts/sod.sh
```

But this is not recommended for production Linux.

## New Features

After migration, you gain:

- **Journald logging**: `sudo journalctl -u ollama -f` for centralized logs
- **Automatic restart**: Service restarts on failure (configurable)
- **Boot persistence**: Service starts on boot (when enabled)
- **Resource control**: Can add MemoryLimit, CPUQuota in service overrides
- **GPU access**: Systemd grants device permissions cleanly

## Questions?

See `docs/SYSTEMD_INTEGRATION.md` for full technical details.
