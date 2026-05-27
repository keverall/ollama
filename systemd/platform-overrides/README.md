# Platform Overrides

Optional systemd drop-in configurations for Ollama service.

## Purpose

Drop-in fragments modify the main `ollama.service` without editing it directly. Use these for platform-specific tweaks like GPU device permissions.

## Usage

Place `.conf` files in `/etc/systemd/system/ollama.service.d/`:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo cp ollama-devops/systemd/platform-overrides/<override>.conf /etc/systemd/system/ollama.service.d/
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

## Available Overrides

### `cachyos-nvidia.conf`

For systems with NVIDIA GPUs (RTX 4090, etc.). Adds:

- `DeviceAllow=/dev/nvidia0 rw`
- `DeviceAllow=/dev/nvidiactl rw`
- `DeviceAllow=/dev/nvidia-uvm rw`
- `DeviceAllow=/dev/nvidia-uvm-tools rw`
- Optional GPU-specific environment variables

### `linux-nonvidia.conf`

For CPU-only Linux systems. No special device access; conservative parallelism.

### `macos.conf`

Informational reference (macOS uses launchd, not systemd).

## Custom Overrides

Create your own `10-custom.conf`:

```ini
[Service]
# Example: limit memory
# MemoryLimit=20G

# Example: increase file descriptor limit
# LimitNOFILE=65536
```

Files are loaded in lexical order (prefix with numbers).

## Notes

- Overrides augment the main service file; they do not replace it.
- After adding/removing overrides, always run `systemctl daemon-reload`.
- `sod.sh` does not install these automatically; manual deployment required.
