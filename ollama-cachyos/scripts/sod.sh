#!/bin/bash
#============================================================================
# Title:            sod.sh
# Description:      Start of Day script for Ollama optimized environment
# Author:           Keverall
# Date:             2026-04-28
# Version:          1.0.0
# Usage:            ./scripts/sod.sh
# Requirements:     bash, ollama (OLLAMA_BIN), docker, nvidia-smi (optional), curl
# Exit Codes:       0 - Success, 1 - Error
#============================================================================

set -euo pipefail

# Configuration
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        *) ;;
    esac
done

OLLAMA_HOST="${OLLAMA_HOST:-[::]:11434}"  # IPv6+IPv4 dual stack
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_BASE_URL="http://localhost:${OLLAMA_PORT}"
# Resolve OLLAMA_BIN to absolute path
OLLAMA_BIN="${OLLAMA_BIN:-ollama}"
# Resolve to absolute path for display (if found in PATH)
OLLAMA_BIN_RESOLVED="$(command -v "$OLLAMA_BIN" 2>/dev/null || true)"
if [[ -n "$OLLAMA_BIN_RESOLVED" ]]; then
    OLLAMA_BIN="$OLLAMA_BIN_RESOLVED"
fi
echo "Ollama bin: ${OLLAMA_BIN}"
echo ""

QDRANT_PORT="${QDRANT_PORT:-6333}"
QDRANT_GRPC_PORT="${QDRANT_GRPC_PORT:-6334}"

# Resolve script and project directories
if [[ -n "${PROJECT_ROOT:-}" ]]; then
    # Use PROJECT_ROOT from environment (e.g., test harness)
    :
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "$SCRIPT_DIR" == */scripts ]]; then
        PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    else
        PROJECT_ROOT="$SCRIPT_DIR"
    fi
fi

# Logging
LOG_DIR="${LOG_DIR:-${PROJECT_ROOT}/logs}"
LOG_FILE="${LOG_DIR}/ollama-cachyos-devops.log"
OLLAMA_SERVER_LOG="${LOG_DIR}/ollama-server.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
echo "log directory: ${LOG_DIR}"
echo "log file: ${LOG_FILE}"
echo

# Create logs directory if it doesn't exist
mkdir -p "${LOG_DIR}"

log() {
    echo "[$TIMESTAMP] $1" | tee -a "${LOG_FILE}"
}

log "Starting Ollama DevOps environment..."

# Check if running as root (needed for some operations)
if [[ $EUID -ne 0 ]]; then
    log "Warning: Not running as root. Some optimizations may not be available."
fi

# Check Ollama binary
if ! command -v "$OLLAMA_BIN" &> /dev/null; then
    if [ "$DRY_RUN" = true ]; then
        log "Warning (dry-run): Ollama binary not found at '$OLLAMA_BIN'. Skipping check."
    else
        log "Error: Ollama binary not found at '$OLLAMA_BIN'. Please install Ollama first."
        exit 1
    fi
fi

# Check Docker (for Qdrant)
if ! command -v docker &> /dev/null; then
    if [ "$DRY_RUN" = true ]; then
        log "Warning (dry-run): Docker not found. Skipping Docker check."
    else
        log "Error: Docker not found. Please install Docker first."
        exit 1
    fi
fi

# Check NVIDIA GPU
if ! command -v nvidia-smi &> /dev/null; then
    log "Warning: nvidia-smi not found. GPU optimizations may not be available."
else
    log "GPU Status:"
    nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used,memory.free --format=csv,noheader | tee -a "${LOG_FILE}"
fi

# --- Phase 1: Stop any existing Ollama instances ---
log "Resetting Ollama to apply optimizations..."
if [ "$DRY_RUN" = true ]; then
    log "[dry-run] Would check for and stop existing Ollama processes"
else
    if pgrep -f "ollama" > /dev/null; then
        log "Stopping existing Ollama processes..."
        pkill -f "ollama" 2>/dev/null || true
        sleep 2
    fi
fi

# --- Phase 2: Start Ollama ---
log "Starting Ollama server..."
if [ "$DRY_RUN" = true ]; then
    log "[dry-run] Would export OLLAMA_HOST=${OLLAMA_HOST}, OLLAMA_PORT=${OLLAMA_PORT}"
    log "[dry-run] Would export OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL:-24}"
    log "[dry-run] Would export OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS:-2}"
    log "[dry-run] Would touch server log: $OLLAMA_SERVER_LOG"
    log "[dry-run] Would launch: $OLLAMA_BIN serve"
    log "[dry-run] Would sleep 3 seconds"
    touch "$OLLAMA_SERVER_LOG"
else
    # Ensure OLLAMA_HOST is exported (with port if using [::] format)
    export OLLAMA_HOST="${OLLAMA_HOST}"
    export OLLAMA_PORT="${OLLAMA_PORT}"
    # Optional: Set number of parallel workers (based on CPU cores)
    export OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL:-24}
    # Optional: Set max loaded models (VRAM constrained)
    export OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS:-2}

    # Prepare server log
    touch "$OLLAMA_SERVER_LOG"
    log "Ollama server log: $OLLAMA_SERVER_LOG"

    # Start Ollama in background
    log "Launching ollama serve..."
    "$OLLAMA_BIN" serve > "$OLLAMA_SERVER_LOG" 2>&1 &
    OLLAMA_PID=$!
    log "Ollama PID: $OLLAMA_PID"
    sleep 3
fi

# --- Phase 3: Verify Ollama is running (with retries) ---
log "Waiting for Ollama to become ready..."
if [ "$DRY_RUN" = true ]; then
    log "[dry-run] Would wait for Ollama to be ready (max 15 retries)"
else
    MAX_RETRIES=15
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if "$OLLAMA_BIN" list > /dev/null 2>&1; then
            log "Ollama is running (attempt $((RETRY_COUNT+1)))."
            break
        fi
        RETRY_COUNT=$((RETRY_COUNT+1))
        log "   Waiting for Ollama to start... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 2
    done

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        log "Error: Ollama failed to start after $MAX_RETRIES attempts."
        log "Last 15 lines of server log:"
        tail -n 15 "$OLLAMA_SERVER_LOG" 2>/dev/null || echo "No log file."
        exit 1
    fi
fi

# --- Phase 4: Ensure base models are present ---
log "Checking Base Models..."

ensure_model() {
    local model_name="$1"
    local modfile_name="$2"
    local modfile_path="./modfiles/${modfile_name}"

    if [ "$DRY_RUN" = true ]; then
        log "[dry-run] Would ensure model $model_name (modfile: ${modfile_name})"
        return 0
    fi

    if "$OLLAMA_BIN" list 2>/dev/null | grep -q "^${model_name}[[:space:]:]"; then
        log "Model $model_name already present."
    else
        log "Pulling/creating model $model_name..."
        if [[ -f "$modfile_path" ]]; then
            if "$OLLAMA_BIN" create "$model_name" -f "$modfile_path"; then
                log "Model $model_name created successfully."
            else
                log "Failed to create $model_name"
                return 1
            fi
        else
            if "$OLLAMA_BIN" pull "$model_name"; then
                log "Model $model_name pulled successfully."
            else
                log "Failed to pull $model_name"
                return 1
            fi
        fi
    fi
    return 0
}

ensure_model "qwen2.5:72b-instruct" "Qwen2.5-72B-instruct-GPU.modelfile" || exit 1
ensure_model "qwen2.5:7b-instruct" "Qwen2.5-7B-instruct-GPU.modelfile" || exit 1
ensure_model "nomic-embed-text:latest" "nomic-embed-text-GPU.modelfile" || exit 1

# --- Phase 5: Warm up optimal models ---
log "Warming up optimal models..."
if [ "$DRY_RUN" = true ]; then
    log "[dry-run] Would warm up qwen2.5:72b-instruct and qwen2.5:7b-instruct"
else
    if "$OLLAMA_BIN" list 2>/dev/null | grep -q "^qwen2.5:72b-instruct[[:space:]:]"; then
        log "Warming up qwen2.5:72b-instruct (optimal for quality)..."
        echo "Hello" | "$OLLAMA_BIN" run qwen2.5:72b-instruct > /dev/null 2>&1 || true
        log "qwen2.5:72b-instruct warmed up."
    fi

    if "$OLLAMA_BIN" list 2>/dev/null | grep -q "^qwen2.5:7b-instruct[[:space:]:]"; then
        log "Warming up qwen2.5:7b-instruct (optimal for speed)..."
        echo "Hello" | "$OLLAMA_BIN" run qwen2.5:7b-instruct > /dev/null 2>&1 || true
        log "qwen2.5:7b-instruct warmed up."
    fi
fi

# --- Phase 6: API connectivity tests ---
log "Testing API connectivity..."
if [ "$DRY_RUN" = true ]; then
    log "[dry-run] Would test API connectivity (IPv4, IPv6, localhost)"
else
    if curl -s --fail http://127.0.0.1:11434/api/tags > /dev/null; then
        log "  IPv4 (127.0.0.1): OK"
    else
        log "  IPv4 (127.0.0.1): FAIL"
    fi
    if curl -s --fail 'http://[::1]:11434/api/tags' > /dev/null; then
        log "  IPv6 ([::1]):     OK"
    else
        log "  IPv6 ([::1]):     FAIL"
    fi
    if curl -s --fail http://localhost:11434/api/tags > /dev/null; then
        log "  localhost:        OK"
    else
        log "  localhost:        FAIL"
    fi
fi

# Start Qdrant using Docker Compose
log "Starting Qdrant vector database..."
if [ "$DRY_RUN" = true ]; then
    log "[dry-run] Would start Qdrant via docker-compose"
else
    cd "$PROJECT_ROOT"
    if [[ ! -f "docker-compose.yml" ]]; then
        log "Warning: docker-compose.yml not found. Skipping Qdrant startup."
    else
        docker-compose up -d

        # Wait for Qdrant to be ready
        log "Waiting for Qdrant to be ready..."
        for i in {1..30}; do
            if curl -s "http://localhost:${QDRANT_PORT}/ready" &> /dev/null; then
                log "Qdrant is ready."
                break
            fi
            sleep 1
            if [[ $i -eq 30 ]]; then
                log "Warning: Qdrant may not be ready yet. Continuing anyway."
                break
            fi
        done
    fi
fi

# Final status
log "=== Environment Started Successfully ==="
log "Ollama API: $OLLAMA_BASE_URL"
if [ "$DRY_RUN" = true ]; then
    log "[dry-run] Would start Qdrant on http://localhost:${QDRANT_PORT}"
    log "[dry-run] Would show models: qwen2.5:72b-instruct, qwen2.5:7b-instruct, nomic-embed-text:latest"
    log "[dry-run] Would show loaded models via 'ollama ps'"
else
    log "Qdrant API: http://localhost:${QDRANT_PORT}"
    log "Qdrant Dashboard: http://localhost:${QDRANT_PORT}/dashboard"
    log "Available Models:"
    "$OLLAMA_BIN" list | tee -a "${LOG_FILE}"
    log "Loaded Models:"
    "$OLLAMA_BIN" ps | tee -a "${LOG_FILE}"
fi
exit 0
