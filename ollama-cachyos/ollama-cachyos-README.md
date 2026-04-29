# Ollama Optimized Environment for RTX 4090 on CachyOS

This repository provides a DevOps-optimized setup for running Ollama with high-performance hardware:

- GPU: NVIDIA GeForce RTX 4090 (24GB VRAM)
- CPU: Intel Core i9-13900KS (24 cores)
- RAM: 32GB DDR5/6000MHz
- OS: CachyOS

## Features

- Hardware-tuned modfiles for Qwen and embedding models
- Start of Day (sod.sh) and End of Day (eod.sh) scripts
- Systemd service configuration for Ollama
- Docker Compose for Qdrant vector database
- Environment optimized for GPU acceleration

## Directory Structure

- `modfiles/` - Hardware-optimized Ollama modfiles
- `scripts/` - SOD and EOD scripts
- `systemd/` - Systemd service files
- `docker-compose.yml` - Qdrant deployment

## Quick Start

1. Make scripts executable:

```bash
    chmod +x scripts/*.sh
    ```

3. Start the environment:
    ```bash
    ./scripts/sod.sh
    ```

4. Stop the environment:
    ```bash
    ./scripts/eod.sh
    ```

## Models Available

- `qwen2.5:72b-instruct` - High-quality model, GPU-optimized for RTX 4090
- `qwen2.5:7b-instruct` - Fast inference model, GPU-optimized for RTX 4090
- `nomic-embed-text:latest` - GPU-optimized embedding model

## Configuration

### Ollama Service

The systemd service file (`systemd/ollama.service`) is configured with:
- GPU device access
- 24 parallel workers (based on CPU cores)
- Maximum 2 loaded models (VRAM constrained)
- Automatic restart on failure

To install the systemd service:
```bash
sudo cp systemd/ollama.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl start ollama
```

### Qdrant

Qdrant is deployed via Docker Compose. The storage is persisted in `./qdrant_storage`.

To manually start Qdrant:

```bash
docker-compose up -d
```

To stop Qdrant:

```bash
docker-compose down
```

## Performance Notes

- The RTX 4090's 24GB VRAM allows for substantial GPU layer offloading
- The i9-13900KS provides excellent CPU performance for concurrent requests
- DDR5/6000MHz memory ensures fast data transfer to GPU
- Adjust `OLLAMA_NUM_PARALLEL` and `OLLAMA_MAX_LOADED_MODELS` based on workload

## Monitoring

Check GPU utilization during inference:

```bash
watch -n 1 nvidia-smi
```

View logs:

```bash
journalctl -u ollama.service -f
```

## Customization

- Adjust modfiles in `modfiles/` for different model requirements
- Modify environment variables in `sod.sh` and `eod.sh` as needed
- Update Docker Compose for different Qdrant versions or configurations

## Requirements

- Ollama 0.21.2+
- Docker 20.10+
- NVIDIA drivers with CUDA support
- CachyOS (or any Linux distribution with systemd)

## License

MIT
