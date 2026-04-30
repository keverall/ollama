#!/bin/bash
#============================================================================
# Title:            sod.sh
# Description:      Cross-platform Start of Day script for Ollama environment
#                   Supports macOS (MacBook) and Linux (CachyOS/Arch)
# Author:           Keverall
# Date:             2026-04-30
# Version:          1.1.0
# Usage:            ./scripts/sod.sh [--dry-run]
# Requirements:     bash, ollama (OLLAMA_BIN), docker, curl, nvidia-smi (GPU)
# Exit Codes:       0 - Success, 1 - Error
#============================================================================

# Don't exit on error - we handle errors gracefully
set -euo pipefail

#----------------------------------------------------------------------------
# Configuration & Arguments
#----------------------------------------------------------------------------
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --dry-run    Simulate actions without making changes"
            echo "  --help, -h   Show this help message"
            exit 0
            ;;
        *)
            echo "Warning: Unknown argument: $arg" >&2
            ;;
    esac
done

# Platform override (for testing or manual specification)
PLATFORM_OVERRIDE="${PLATFORM_OVERRIDE:-auto}"  # auto, macos, cachyos, linux

#----------------------------------------------------------------------------
# Platform Detection
#----------------------------------------------------------------------------
detect_platform() {
    # Check for manual platform override first
    if [[ "${PLATFORM_OVERRIDE}" != "auto" ]]; then
        echo "${PLATFORM_OVERRIDE}"
        return
    fi
    
    local os
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$os" in
        darwin*)
            echo "macos"
            ;;
        linux*)
            if [[ -f /etc/os-release ]] && grep -qiE "cachyos|arch" /etc/os-release; then
                echo "cachyos"
            else
                echo "linux"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

PLATFORM="$(detect_platform)"
echo "🎯 Detected platform: $PLATFORM"

#----------------------------------------------------------------------------
# Resolve Paths
#----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow PROJECT_ROOT override (useful for test harnesses)
if [[ -n "${PROJECT_ROOT:-}" ]]; then
    :
else
    if [[ "$SCRIPT_DIR" == */scripts ]]; then
        PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    else
        PROJECT_ROOT="$SCRIPT_DIR"
    fi
fi

# Set platform-specific modfile directory
case "$PLATFORM" in
    macos|macbook)
        MODFILE_DIR="${PROJECT_ROOT}/platform/macbook-m4-24gb-optimized/modfiles"
        ;;
    cachyos|linux)
        MODFILE_DIR="${PROJECT_ROOT}/platform/cachyos-i9-32gb-nvidia-4090/modfiles"
        ;;
    *)
        MODFILE_DIR="${PROJECT_ROOT}/platform/modfiles"  # fallback
        ;;
esac

#----------------------------------------------------------------------------
# Environment Variables & Configuration
#----------------------------------------------------------------------------
# Load platform-specific .env if it exists
PLATFORM_ENV_FILE=""
case "$PLATFORM" in
    macos|macbook)
        PLATFORM_ENV_FILE="${PROJECT_ROOT}/platform/macbook-m4-24gb-optimized/.env"
        ;;
    cachyos|linux)
        PLATFORM_ENV_FILE="${PROJECT_ROOT}/platform/cachyos-i9-32gb-nvidia-4090/.env"
        ;;
    *)
        PLATFORM_ENV_FILE="${SCRIPT_DIR}/.env"  # fallback
        ;;
esac

# Default configuration (can be overridden by .env or environment)
OLLAMA_HOST="${OLLAMA_HOST:-[::]:11434}"  # IPv6+IPv4 dual stack
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_BASE_URL="http://localhost:${OLLAMA_PORT}"

# Resolve OLLAMA_BIN to absolute path if possible
OLLAMA_BIN="${OLLAMA_BIN:-ollama}"
if command -v "$OLLAMA_BIN" &>/dev/null; then
    OLLAMA_BIN="$(command -v "$OLLAMA_BIN")"
fi

# Platform-specific defaults
case "$PLATFORM" in
    macos)
        # MacBook M4 Pro 24GB defaults
        OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL:-24}"
        OLLAMA_MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS:-2}"
        # Backward compatibility: use MODEL_LIST if DEFAULT_MODELS not set
        if [[ -z "${DEFAULT_MODELS:-}" && -n "${MODEL_LIST:-}" ]]; then
            DEFAULT_MODELS="$MODEL_LIST"
        fi
        DEFAULT_MODELS="${DEFAULT_MODELS:-nomic-embed-text,qwen2.5-coder:14b}"
        DEVOPS_MODEL="${DEVOPS_MODEL:-qwen-devops}"
        ;;
    cachyos|linux)
        # RTX 4090 / Linux defaults
        OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL:-24}"
        OLLAMA_MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS:-2}"
        DEFAULT_MODELS="${DEFAULT_MODELS:-qwen2.5:72b-instruct,qwen2.5:7b-instruct,nomic-embed-text:latest}"
        DEVOPS_MODEL="${DEVOPS_MODEL:-}"
        ;;
    *)
        # Generic defaults
        OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL:-4}"
        OLLAMA_MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS:-2}"
        DEFAULT_MODELS="${DEFAULT_MODELS:-llama3.2:3b}"
        DEVOPS_MODEL="${DEVOPS_MODEL:-}"
        ;;
esac

QDRANT_PORT="${QDRANT_PORT:-6333}"
QDRANT_GRPC_PORT="${QDRANT_GRPC_PORT:-6334}"

#----------------------------------------------------------------------------
# Logging Setup
#----------------------------------------------------------------------------
LOG_DIR="${LOG_DIR:-${PROJECT_ROOT}/logs}"
# Create log filename with script name and parameters
SCRIPT_NAME="$(basename "$0")"
SCRIPT_ARGS=""
if [[ $# -gt 0 ]]; then
    SCRIPT_ARGS="$(echo "$*" | tr ' ' '-')"
fi
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}${SCRIPT_ARGS}.log"
OLLAMA_SERVER_LOG="${LOG_DIR}/ollama-server.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "${LOG_DIR}"

log() {
    local msg="[$TIMESTAMP] $1"
    echo "$msg"
    echo "$msg" >> "${LOG_FILE}"
}

# Load platform-specific .env after logging is set up
if [[ -f "$PLATFORM_ENV_FILE" ]]; then
    log "Loading environment from: $PLATFORM_ENV_FILE"
    # shellcheck disable=SC1090  # Platform .env path is dynamic
    source "$PLATFORM_ENV_FILE"
else
    log "No platform-specific .env found, using defaults"
fi

log "🚀 Starting Ollama DevOps Environment..."
log "Platform: $PLATFORM"
log "Project root: ${PROJECT_ROOT}"
log "Ollama bin: ${OLLAMA_BIN}"
log "Modfile dir: ${MODFILE_DIR}"

if [[ "$DRY_RUN" == true ]]; then
    log "⚠️  DRY RUN MODE - No actual changes will be made"
fi

#----------------------------------------------------------------------------
# Helper Functions
#----------------------------------------------------------------------------

# Check if a command exists
check_command() {
    command -v "$1" &>/dev/null
}

# Wait for Ollama to be ready
wait_for_ollama() {
    local max_retries=15
    local retry_count=0
    
    log "Waiting for Ollama to start..."
    while [[ $retry_count -lt $max_retries ]]; do
        if "${OLLAMA_BIN}" list &>/dev/null; then
            log "Ollama is ready (attempt $((retry_count+1)))"
            return 0
        fi
        retry_count=$((retry_count+1))
        log "   Waiting... ($retry_count/$max_retries)"
        sleep 2
    done
    return 1
}

#----------------------------------------------------------------------------
# Pre-flight Checks
#----------------------------------------------------------------------------
log ""
log "🔍 Running pre-flight checks..."

# Check Ollama binary
if ! check_command "$OLLAMA_BIN"; then
    log "❌ Error: Ollama binary not found at '$OLLAMA_BIN'. Please install Ollama first."
    exit 1
fi
log "✅ Ollama binary found: ${OLLAMA_BIN}"

# Check Docker (needed for Qdrant)
if ! check_command docker; then
    log "⚠️  Docker not found. Qdrant will not be started."
else
    log "✅ Docker found"
fi

# Platform-specific checks
case "$PLATFORM" in
    cachyos|linux)
        # Check for NVIDIA GPU
        if check_command nvidia-smi; then
            log "GPU Status:"
            nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used,memory.free \
                --format=csv,noheader 2>/dev/null || log "   Could not query GPU"
        else
            log "⚠️  nvidia-smi not found. GPU optimizations may not be available."
        fi
        ;;
    *)
        ;;
esac

#----------------------------------------------------------------------------
# Phase 1: Stop Existing Ollama Instances
#----------------------------------------------------------------------------
log ""
log "🛑 Phase 1: Stopping existing Ollama processes..."

if [[ "$DRY_RUN" != true ]]; then
    # Get current script PID to exclude from killing
    SCRIPT_PID=$$
    
    case "$PLATFORM" in
        macos)
            # macOS: Use osascript + killall
            if check_command osascript; then
                osascript -e 'quit app "Ollama"' 2>/dev/null || true
            fi
            # Kill by exact process name, not pattern
            pkill -f "^.*/ollama$" 2>/dev/null || true
            sleep 2
            ;;
        cachyos|linux)
            # Linux: Use pkill for Ollama processes, but be specific
            # First try graceful shutdown
            log "Sending SIGTERM to Ollama processes..."
            # Use pgrep to find ollama processes, excluding our script
            pgrep -f "ollama" 2>/dev/null | while read -r pid; do
                if [[ "$pid" != "$SCRIPT_PID" ]]; then
                    # Check if this process is our script or a child
                    if ! ps -p "$pid" -o args= 2>/dev/null | grep -q "sod\.sh"; then
                        kill -TERM "$pid" 2>/dev/null || true
                    fi
                fi
            done
            sleep 2
            
            # Force kill any remaining
            log "Sending SIGKILL to remaining Ollama processes..."
            pgrep -f "ollama" 2>/dev/null | while read -r pid; do
                if [[ "$pid" != "$SCRIPT_PID" ]]; then
                    if ! ps -p "$pid" -o args= 2>/dev/null | grep -q "sod\.sh"; then
                        kill -9 "$pid" 2>/dev/null || true
                    fi
                fi
            done
            ;;
    esac
    log "✅ Previous Ollama instances stopped."
fi

#----------------------------------------------------------------------------
# Phase 2: Start Ollama Server
#----------------------------------------------------------------------------
log ""
log "🚀 Phase 2: Starting Ollama server..."

if [[ "$DRY_RUN" != true ]]; then
    # Export environment variables for Ollama
    export OLLAMA_HOST="${OLLAMA_HOST}"
    export OLLAMA_PORT="${OLLAMA_PORT}"
    export OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL}"
    export OLLAMA_MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS}"
    
    # Additional platform-specific optimizations
    case "$PLATFORM" in
        macos)
            export OLLAMA_FLASH_ATTENTION="${OLLAMA_FLASH_ATTENTION:-1}"
            export OLLAMA_KV_CACHE_TYPE="${OLLAMA_KV_CACHE_TYPE:-q4_0}"
            ;;
        cachyos)
            export OLLAMA_GPU_LAYERS="${OLLAMA_GPU_LAYERS:-50}"
            export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
            ;;
    esac
    
    log "Environment:"
    log "  OLLAMA_HOST=${OLLAMA_HOST}"
    log "  OLLAMA_PORT=${OLLAMA_PORT}"
    log "  OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL}"
    log "  OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS}"
    
    # Prepare server log
    touch "${OLLAMA_SERVER_LOG}"
    log "Ollama server log: ${OLLAMA_SERVER_LOG}"
    
    # Start Ollama in background
    log "Starting ollama serve..."
    "${OLLAMA_BIN}" serve >> "${OLLAMA_SERVER_LOG}" 2>&1 &
    OLLAMA_PID=$!
    log "Ollama started with PID: ${OLLAMA_PID}"
    
    # Wait for Ollama to be ready
    if wait_for_ollama; then
        log "✅ Ollama server is running."
    else
        log "❌ Error: Ollama failed to start."
        log "Server log contents:"
        tail -n 20 "${OLLAMA_SERVER_LOG}" 2>/dev/null || true
        exit 1
    fi
else
    log "[dry-run] Would export OLLAMA_HOST=${OLLAMA_HOST}"
    log "[dry-run] Would start: ${OLLAMA_BIN} serve"
fi

#----------------------------------------------------------------------------
# Phase 3: Verify Ollama API Connectivity
#----------------------------------------------------------------------------
log ""
log "🔍 Phase 3: Testing API connectivity..."

if [[ "$DRY_RUN" != true ]]; then
    # Test IPv4
    if curl -s --fail "http://127.0.0.1:${OLLAMA_PORT}/api/tags" &>/dev/null; then
        log "  IPv4 (127.0.0.1): ✅ OK"
    else
        log "  IPv4 (127.0.0.1): ❌ FAIL"
    fi
    
    # Test IPv6
    if curl -s --fail "http://[::1]:${OLLAMA_PORT}/api/tags" &>/dev/null; then
        log "  IPv6 ([::1]):     ✅ OK"
    else
        log "  IPv6 ([::1]):     ❌ FAIL"
    fi
    
    # Test localhost
    if curl -s --fail "http://localhost:${OLLAMA_PORT}/api/tags" &>/dev/null; then
        log "  localhost:        ✅ OK"
    else
        log "  localhost:        ❌ FAIL"
    fi
fi

#----------------------------------------------------------------------------
# Phase 4: Ensure Models are Present
#----------------------------------------------------------------------------
log ""
log "📦 Phase 4: Ensuring models are present..."

# Function to ensure a model exists
ensure_model() {
    local model_name="$1"
    local modfile_name="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] Would ensure model: $model_name (modfile: ${modfile_name:-none})"
        return 0
    fi
    
    # Check if model already exists
    if "${OLLAMA_BIN}" list 2>/dev/null | grep -q "^${model_name}[[:space:]:]"; then
        log "  ✅ Model $model_name already present."
        return 0
    fi
    
    log "  📥 Model $model_name not found, creating/pulling..."
    
    # Try to create from modfile first if provided
    if [[ -n "$modfile_name" && -f "${MODFILE_DIR}/${modfile_name}" ]]; then
        log "    Creating from modfile: $modfile_name"
        if "${OLLAMA_BIN}" create "$model_name" -f "${MODFILE_DIR}/${modfile_name}" &>/dev/null; then
            log "    ✅ $model_name created from modfile."
            return 0
        else
            log "    ⚠️  Failed to create from modfile, trying pull..."
        fi
    fi
    
    # Fallback: try to pull from registry
    log "    Pulling from registry..."
    if "${OLLAMA_BIN}" pull "$model_name" &>/dev/null; then
        log "    ✅ $model_name pulled successfully."
        return 0
    else
        log "    ❌ Failed to pull $model_name"
        return 1
    fi
}

# Helper: Get modfile name for a model based on platform
get_modfile_for_model() {
    local model_name="$1"
    local detected_platform="$2"
    
    case "$detected_platform" in
        macos)
            # MacBook: Check if this is the custom DevOps model
            if [[ -n "$DEVOPS_MODEL" && "$model_name" == "$DEVOPS_MODEL" ]]; then
                local candidates=("modfile-${DEVOPS_MODEL}" "modfile-qwen-devops" "modfile-gemma4")
                for candidate in "${candidates[@]}"; do
                    if [[ -f "${MODFILE_DIR}/${candidate}" ]]; then
                        echo "$candidate"
                        return 0
                    fi
                done
            fi
            ;;
        cachyos|linux)
            # CachyOS: GPU-optimized modfiles
            case "$model_name" in
                qwen2.5:72b-instruct)
                    [[ -f "${MODFILE_DIR}/Qwen2.5-72B-instruct-GPU.modelfile" ]] && echo "Qwen2.5-72B-instruct-GPU.modelfile" && return 0
                    ;;
                qwen2.5:7b-instruct)
                    [[ -f "${MODFILE_DIR}/Qwen2.5-7B-instruct-GPU.modelfile" ]] && echo "Qwen2.5-7B-instruct-GPU.modelfile" && return 0
                    ;;
                nomic-embed-text:latest|nomic-embed-text)
                    [[ -f "${MODFILE_DIR}/nomic-embed-text-GPU.modelfile" ]] && echo "nomic-embed-text-GPU.modelfile" && return 0
                    ;;
            esac
            ;;
    esac
    
    echo ""
    return 1
}

# Ensure each model in DEFAULT_MODELS
MODEL_CHECK_STATUS=0
IFS=',' read -ra MODEL_ARRAY <<< "$DEFAULT_MODELS"
for model in "${MODEL_ARRAY[@]}"; do
    model_trimmed="$(echo "$model" | xargs)"
    modfile_name="$(get_modfile_for_model "$model_trimmed" "$PLATFORM" || true)"
    ensure_model "$model_trimmed" "$modfile_name" || MODEL_CHECK_STATUS=1
done
unset IFS

# Handle DEVOPS_MODEL if defined and not already in DEFAULT_MODELS
if [[ -n "$DEVOPS_MODEL" ]]; then
    devops_already_handled=false
    for m in "${MODEL_ARRAY[@]}"; do
        [[ "$(echo "$m" | xargs)" == "$DEVOPS_MODEL" ]] && devops_already_handled=true && break
    done
    
    if [[ "$devops_already_handled" == false ]]; then
        log "📦 Checking DevOps model: ${DEVOPS_MODEL}"
        modfile_name="$(get_modfile_for_model "$DEVOPS_MODEL" "$PLATFORM" || true)"
        if [[ -n "$modfile_name" ]]; then
            ensure_model "$DEVOPS_MODEL" "$modfile_name" || MODEL_CHECK_STATUS=1
        else
            log "  ⚠️  No modfile found for DEVOPS_MODEL='${DEVOPS_MODEL}'. Skipping."
        fi
    fi
fi

if [[ $MODEL_CHECK_STATUS -ne 0 ]]; then
    log "⚠️  Some models failed to ensure, continuing..."
fi

#----------------------------------------------------------------------------
# Phase 5: Warm Up Models
#----------------------------------------------------------------------------
log ""
log "🔥 Phase 5: Warming up models..."

if [[ "$DRY_RUN" != true ]]; then
    case "$PLATFORM" in
        macos)
            # Warm up the DevOps model on Mac
            if [[ -n "$DEVOPS_MODEL" ]] && "${OLLAMA_BIN}" list 2>/dev/null | grep -q "^${DEVOPS_MODEL}[[:space:]:]"; then
                log "Warming up ${DEVOPS_MODEL}..."
                if echo "hello" | timeout 60 "${OLLAMA_BIN}" run "$DEVOPS_MODEL" &>/dev/null; then
                    log "  ✅ ${DEVOPS_MODEL} preloaded and ready."
                else
                    log "  ⚠️  ${DEVOPS_MODEL} preload timed out or failed."
                fi
            fi
            ;;
        cachyos|linux)
# Warm up 72B (quality) and 7B (speed) on Linux/GPU
             for warm_model in "qwen2.5:72b-instruct" "qwen2.5:7b-instruct"; do
                 if "${OLLAMA_BIN}" list 2>/dev/null | grep -q "^${warm_model}[[:space:]:]"; then
                     log "Warming up ${warm_model}..."
                     # Increase timeout for larger models
                     if [[ "$warm_model" == *"72b"* ]]; then
                         WARMUP_TIMEOUT=300  # 5 minutes for 72B model
                     else
                         WARMUP_TIMEOUT=120  # 2 minutes for 7B model
                     fi
                     if echo "Hello" | timeout "$WARMUP_TIMEOUT" "${OLLAMA_BIN}" run "$warm_model" 2>&1 | tee -a "${LOG_FILE}"; then
                         log "  ✅ ${warm_model} warmed up and ready."
                     else
                         log "  ⚠️  ${warm_model} warmup timed out or failed after ${WARMUP_TIMEOUT}s."
                         log "     Check ${LOG_FILE} for details."
                     fi
                 fi
             done
            ;;
    esac
fi

#----------------------------------------------------------------------------
# Phase 6: Start Qdrant Vector Database
#----------------------------------------------------------------------------
log ""
log "🐳 Phase 6: Starting Qdrant..."

if [[ "$DRY_RUN" != true ]] && check_command docker; then
    # Check common locations for docker-compose.yml
    DOCKER_COMPOSE_FILE=""
    if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        DOCKER_COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
    elif [[ -f "${SCRIPT_DIR}/docker-compose.yml" ]]; then
        DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
    fi
    
    if [[ -z "$DOCKER_COMPOSE_FILE" ]]; then
        log "⚠️  docker-compose.yml not found. Skipping Qdrant."
    else
        log "Starting Qdrant via docker-compose..."
        cd "${PROJECT_ROOT}" || exit 1
        if docker-compose -f "$DOCKER_COMPOSE_FILE" up -d 2>&1 | tee -a "${LOG_FILE}"; then
            log "✅ Qdrant containers started!"
            
            # Wait for Qdrant to be ready
            log "Waiting for Qdrant to be ready..."
            ready=0
            for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
                if curl -s "http://localhost:${QDRANT_PORT}/ready" &>/dev/null; then
                    log "✅ Qdrant is ready."
                    ready=1
                    break
                fi
                sleep 1
            done
        else
            log "⚠️  Qdrant startup had issues, continuing..."
        fi
    fi
fi

#----------------------------------------------------------------------------
# Phase 7: Display Final Status
#----------------------------------------------------------------------------
log ""
log "📊 Phase 7: Environment Status"
log "=========================="

if [[ "$DRY_RUN" != true ]]; then
    log "Ollama API: ${OLLAMA_BASE_URL}"
    log ""
    log "Available Models:"
    "${OLLAMA_BIN}" list 2>/dev/null | tee -a "${LOG_FILE}" || log "  Could not list models"
    log ""
    log "Loaded Models:"
    "${OLLAMA_BIN}" ps 2>/dev/null | tee -a "${LOG_FILE}" || log "  Could not list running models"
fi

#----------------------------------------------------------------------------
# Final
#----------------------------------------------------------------------------
log ""
log "✅✅✅ Environment Started Successfully ✅✅✅"
log "=== Start of Day Complete ==="
log "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
log ""
log "Next steps:"
log "  - Test models: ollama run <model-name>"
log "  - Check API: curl http://localhost:${OLLAMA_PORT}/api/tags"
log "  - View logs: tail -f ${OLLAMA_SERVER_LOG}"
log "  - Stop environment: ./scripts/eod.sh"
log ""

exit 0
