#!/bin/bash
#============================================================================
# Title:            sod.sh
# Description:      Cross-platform Start of Day script for Ollama environment
#                   Supports macOS (MacBook) and Linux (CachyOS/Arch)
# Author:           Keverall
# Date:             2026-04-29
# Version:          1.0.0
# Usage:            ./scripts/sod.sh [--dry-run]
# Requirements:     bash, ollama (OLLAMA_BIN), docker, curl, nvidia-smi (GPU)
# Exit Codes:       0 - Success, 1 - Error
#============================================================================

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

#----------------------------------------------------------------------------
# Environment Variables & Configuration
#----------------------------------------------------------------------------
# Load .env if it exists
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/.env"
fi

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
LOG_FILE="${LOG_DIR}/ollama-${PLATFORM}-devops.log"
OLLAMA_SERVER_LOG="${LOG_DIR}/ollama-server.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "${LOG_DIR}"

log() {
    echo "[$TIMESTAMP] $1" | tee -a "${LOG_FILE}"
}

log "🚀 Starting Ollama DevOps Environment..."
log "Platform: $PLATFORM"
log "Project root: ${PROJECT_ROOT}"
log "Ollama bin: ${OLLAMA_BIN}"

if [[ "$DRY_RUN" == true ]]; then
    log "⚠️  DRY RUN MODE - No actual changes will be made"
fi

#----------------------------------------------------------------------------
# Pre-flight Checks
#----------------------------------------------------------------------------
log ""
log "🔍 Running pre-flight checks..."

# Check Ollama binary
if ! command -v "$OLLAMA_BIN" &>/dev/null; then
    if [[ "$DRY_RUN" == true ]]; then
        log "⚠️  (dry-run) Ollama binary not found at '$OLLAMA_BIN'. Skipping check."
    else
        log "❌ Error: Ollama binary not found at '$OLLAMA_BIN'. Please install Ollama first."
        exit 1
    fi
fi

# Check Docker (needed for Qdrant)
if ! command -v docker &>/dev/null; then
    if [[ "$DRY_RUN" == true ]]; then
        log "⚠️  (dry-run) Docker not found. Skipping Docker check."
    else
        log "❌ Error: Docker not found. Please install Docker to run Qdrant."
        exit 1
    fi
fi

# Platform-specific checks
case "$PLATFORM" in
    cachyos|linux)
        # Check for NVIDIA GPU (optional but recommended)
        if command -v nvidia-smi &>/dev/null; then
            log "GPU Status:"
            nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used,memory.free \
                --format=csv,noheader | tee -a "${LOG_FILE}" || true
        else
            log "⚠️  nvidia-smi not found. GPU optimizations may not be available."
        fi
        ;;
    *)
        # No special checks for other platforms
        ;;
esac

# Check if running with appropriate privileges
if [[ $EUID -ne 0 ]]; then
    log "ℹ️  Not running as root. Some operations may require sudo."
fi

#----------------------------------------------------------------------------
# Phase 1: Stop Existing Ollama Instances
#----------------------------------------------------------------------------
log ""
log "🛑 Phase 1: Resetting Ollama to apply optimizations..."

if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] Would stop existing Ollama processes"
else
    case "$PLATFORM" in
        macos)
            # macOS: Use osascript + killall
            if command -v osascript &>/dev/null; then
                osascript -e 'quit app "Ollama"' 2>/dev/null || true
            fi
            killall -9 "ollama" 2>/dev/null || true
            killall -9 "Ollama" 2>/dev/null || true
            sleep 2
            ;;
        cachyos|linux)
            # Linux: Use pkill for Ollama processes
            if pgrep -f "ollama" > /dev/null 2>&1; then
                log "Stopping existing Ollama processes..."
                pkill -f "ollama" 2>/dev/null || true
                sleep 2
                
                if pgrep -f "ollama" > /dev/null 2>&1; then
                    log "Force killing remaining Ollama processes..."
                    pkill -9 -f "ollama" 2>/dev/null || true
                fi
            fi
            ;;
    esac
    log "✅ Previous Ollama instances stopped."
fi

#----------------------------------------------------------------------------
# Phase 2: Start Ollama
#----------------------------------------------------------------------------
log ""
log "🚀 Phase 2: Starting Ollama server..."

if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] Would export OLLAMA_HOST=${OLLAMA_HOST}"
    log "[dry-run] Would export OLLAMA_PORT=${OLLAMA_PORT}"
    log "[dry-run] Would export OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL}"
    log "[dry-run] Would export OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS}"
    log "[dry-run] Would touch server log: ${OLLAMA_SERVER_LOG}"
    log "[dry-run] Would launch: ${OLLAMA_BIN} serve"
    log "[dry-run] Would sleep 3 seconds"
    touch "${OLLAMA_SERVER_LOG}"
else
    # Export environment variables for Ollama
    export OLLAMA_HOST="${OLLAMA_HOST}"
    export OLLAMA_PORT="${OLLAMA_PORT}"
    export OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL}"
    export OLLAMA_MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS}"
    
    # Additional platform-specific optimizations
    case "$PLATFORM" in
        macos)
            # Mac-specific memory optimizations
            export OLLAMA_FLASH_ATTENTION="${OLLAMA_FLASH_ATTENTION:-1}"
            export OLLAMA_KV_CACHE_TYPE="${OLLAMA_KV_CACHE_TYPE:-q4_0}"
            ;;
        cachyos)
            # GPU optimizations for NVIDIA
            export OLLAMA_GPU_LAYERS="${OLLAMA_GPU_LAYERS:-50}"
            export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
            ;;
    esac
    
    log "Environment variables set:"
    log "  OLLAMA_HOST=${OLLAMA_HOST}"
    log "  OLLAMA_PORT=${OLLAMA_PORT}"
    log "  OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL}"
    log "  OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS}"
    
    # Prepare server log
    touch "${OLLAMA_SERVER_LOG}"
    log "Ollama server log: ${OLLAMA_SERVER_LOG}"
    
    # Start Ollama in background
    log "Launching ollama serve..."
    "${OLLAMA_BIN}" serve > "${OLLAMA_SERVER_LOG}" 2>&1 &
    OLLAMA_PID=$!
    log "Ollama PID: ${OLLAMA_PID}"
    sleep 3
fi

#----------------------------------------------------------------------------
# Phase 3: Verify Ollama is Running
#----------------------------------------------------------------------------
log ""
log "🔍 Phase 3: Waiting for Ollama to become ready..."

if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] Would wait for Ollama readiness"
else
    MAX_RETRIES=15
    RETRY_COUNT=0
    
    while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
        if "${OLLAMA_BIN}" list > /dev/null 2>&1; then
            log "✅ Ollama is running (attempt $((RETRY_COUNT+1)))."
            break
        fi
        RETRY_COUNT=$((RETRY_COUNT+1))
        log "   Waiting for Ollama to start... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 2
    done
    
    if [[ $RETRY_COUNT -eq $MAX_RETRIES ]]; then
        log "❌ Error: Ollama failed to start after $MAX_RETRIES attempts."
        log "Last 15 lines of server log:"
        tail -n 15 "${OLLAMA_SERVER_LOG}" 2>/dev/null || echo "No log file."
        exit 1
    fi
fi

#----------------------------------------------------------------------------
# Phase 4: Ensure Models are Present
#----------------------------------------------------------------------------
log ""
log "📦 Phase 4: Checking models..."

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
        log "✅ Model $model_name already present."
        return 0
    fi
    
    log "📥 Ensuring model $model_name..."
    
    # Try to create from modfile first if provided
    if [[ -n "$modfile_name" && -f "${PROJECT_ROOT}/modfiles/${modfile_name}" ]]; then
        log "  Creating from modfile: $modfile_name"
        if "${OLLAMA_BIN}" create "$model_name" -f "${PROJECT_ROOT}/modfiles/${modfile_name}"; then
            log "✅ $model_name created successfully."
            return 0
        else
            log "❌ Failed to create $model_name from modfile."
            return 1
        fi
    fi
    
    # Fallback: try to pull from registry
    log "  Pulling from registry..."
    if "${OLLAMA_BIN}" pull "$model_name"; then
        log "✅ $model_name pulled successfully."
        return 0
    else
        log "❌ Failed to pull $model_name"
        return 1
    fi
}

#----------------------------------------------------------------------------
# Helper: Get modfile name for a model based on platform
#----------------------------------------------------------------------------
get_modfile_for_model() {
    local model_name="$1"
    local detected_platform="$2"
    
    case "$detected_platform" in
        macos)
            # MacBook: Check if this is the custom DevOps model
            if [[ -n "$DEVOPS_MODEL" && "$model_name" == "$DEVOPS_MODEL" ]]; then
                # Try platform-specific modfile names
                local candidates=("modfile-${DEVOPS_MODEL}" "modfile-qwen-devops" "modfile-gemma4")
                for candidate in "${candidates[@]}"; do
                    if [[ -f "${PROJECT_ROOT}/modfiles/${candidate}" ]]; then
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
                    if [[ -f "${PROJECT_ROOT}/modfiles/Qwen2.5-72B-instruct-GPU.modelfile" ]]; then
                        echo "Qwen2.5-72B-instruct-GPU.modelfile"
                        return 0
                    fi
                    ;;
                qwen2.5:7b-instruct)
                    if [[ -f "${PROJECT_ROOT}/modfiles/Qwen2.5-7B-instruct-GPU.modelfile" ]]; then
                        echo "Qwen2.5-7B-instruct-GPU.modelfile"
                        return 0
                    fi
                    ;;
                nomic-embed-text:latest)
                    if [[ -f "${PROJECT_ROOT}/modfiles/nomic-embed-text-GPU.modelfile" ]]; then
                        echo "nomic-embed-text-GPU.modelfile"
                        return 0
                    fi
                    ;;
            esac
            ;;
    esac
    
    # No modfile found or not applicable
    echo ""
    return 1
}

#----------------------------------------------------------------------------
# Phase 4: Ensure Models are Present
#----------------------------------------------------------------------------
log ""
log "📦 Phase 4: Checking models..."

# Ensure each model based on platform configuration
IFS=',' read -ra MODEL_ARRAY <<< "$DEFAULT_MODELS"
MODEL_CHECK_STATUS=0

for model in "${MODEL_ARRAY[@]}"; do
    model_trimmed="$(echo "$model" | xargs)"
    
    # Get appropriate modfile for this model and platform
    modfile_name="$(get_modfile_for_model "$model_trimmed" "$PLATFORM" || true)"
    
    ensure_model "$model_trimmed" "$modfile_name" || MODEL_CHECK_STATUS=1
done

unset IFS

# Handle DEVOPS_MODEL separately (if defined and not already in DEFAULT_MODELS)
if [[ -n "$DEVOPS_MODEL" ]]; then
    # Check if DEVOPS_MODEL is already in DEFAULT_MODELS to avoid duplication
    devops_already_handled=false
    for m in "${MODEL_ARRAY[@]}"; do
        if [[ "$(echo "$m" | xargs)" == "$DEVOPS_MODEL" ]]; then
            devops_already_handled=true
            break
        fi
    done
    
    if [[ "$devops_already_handled" == false ]]; then
        # Check if devops model already exists
        if ! "${OLLAMA_BIN}" list 2>/dev/null | grep -q "^${DEVOPS_MODEL}[[:space:]:]"; then
            log "📥 Checking DevOps model: ${DEVOPS_MODEL}"
            
            # Get modfile for DEVOPS_MODEL
            modfile_name="$(get_modfile_for_model "$DEVOPS_MODEL" "$PLATFORM" || true)"
            
            if [[ -n "$modfile_name" ]]; then
                log "  Creating ${DEVOPS_MODEL} from modfile: ${modfile_name}"
                if ensure_model "$DEVOPS_MODEL" "$modfile_name"; then
                    log "✅ DevOps model ${DEVOPS_MODEL} created."
                else
                    log "❌ Failed to create DevOps model ${DEVOPS_MODEL}"
                    MODEL_CHECK_STATUS=1
                fi
            else
                log "⚠️  No modfile found for DEVOPS_MODEL='${DEVOPS_MODEL}'. Skipping."
            fi
        else
            log "✅ DevOps model ${DEVOPS_MODEL} already present."
        fi
    fi
fi

if [[ $MODEL_CHECK_STATUS -ne 0 ]]; then
    log "❌ Some models failed to ensure."
    exit 1
fi

#----------------------------------------------------------------------------
# Phase 5: Warm Up Models
#----------------------------------------------------------------------------
log ""
log "🔥 Phase 5: Warming up models..."

if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] Would warm up selected models"
else
    # Warm up optimal models based on platform
    case "$PLATFORM" in
        macos)
            # Warm up the DevOps model on Mac
            if [[ -n "$DEVOPS_MODEL" ]] && "${OLLAMA_BIN}" list 2>/dev/null | grep -q "^${DEVOPS_MODEL}[[:space:]:]"; then
                log "Warming up ${DEVOPS_MODEL}..."
                if echo "hello testing" | "${OLLAMA_BIN}" run "$DEVOPS_MODEL" > /dev/null 2>&1; then
                    log "✅ ${DEVOPS_MODEL} preloaded successfully."
                else
                    log "⚠️  ${DEVOPS_MODEL} preload failed (model may still be usable)."
                fi
            fi
            ;;
        cachyos|linux)
            # Warm up 72B (quality) and 7B (speed) on Linux/GPU
            for warm_model in "qwen2.5:72b-instruct" "qwen2.5:7b-instruct"; do
                if "${OLLAMA_BIN}" list 2>/dev/null | grep -q "^${warm_model}[[:space:]:]"; then
                    log "Warming up ${warm_model}..."
                    echo "Hello" | "${OLLAMA_BIN}" run "$warm_model" > /dev/null 2>&1 || true
                    log "✅ ${warm_model} warmed up."
                fi
            done
            ;;
    esac
fi

#----------------------------------------------------------------------------
# Phase 6: API Connectivity Tests
#----------------------------------------------------------------------------
log ""
log "🔍 Phase 6: Testing API connectivity..."

if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] Would test API connectivity"
else
    # Test various endpoints
    if curl -s --fail "http://127.0.0.1:${OLLAMA_PORT}/api/tags" > /dev/null; then
        log "  IPv4 (127.0.0.1): ✅ OK"
    else
        log "  IPv4 (127.0.0.1): ❌ FAIL"
    fi
    
    if curl -s --fail "http://[::1]:${OLLAMA_PORT}/api/tags" > /dev/null; then
        log "  IPv6 ([::1]):     ✅ OK"
    else
        log "  IPv6 ([::1]):     ❌ FAIL"
    fi
    
    if curl -s --fail "http://localhost:${OLLAMA_PORT}/api/tags" > /dev/null; then
        log "  localhost:        ✅ OK"
    else
        log "  localhost:        ❌ FAIL"
    fi
fi

#----------------------------------------------------------------------------
# Phase 7: Start Qdrant Vector Database
#----------------------------------------------------------------------------
log ""
log "🐳 Phase 7: Starting Qdrant vector database..."

if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] Would start Qdrant via docker-compose"
else
    # Check common locations for docker-compose.yml
    DOCKER_COMPOSE_FILE=""
    if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        DOCKER_COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
    elif [[ -f "${SCRIPT_DIR}/docker-compose.yml" ]]; then
        DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
    fi
    
    if [[ -z "$DOCKER_COMPOSE_FILE" ]]; then
        log "⚠️  docker-compose.yml not found. Skipping Qdrant startup."
    else
        log "Starting Docker containers (${DOCKER_COMPOSE_FILE})..."
        cd "${PROJECT_ROOT}"
        if docker-compose -f "$DOCKER_COMPOSE_FILE" up -d 2>/dev/null || docker compose -f "$DOCKER_COMPOSE_FILE" up -d 2>/dev/null; then
            log "✅ Docker containers started!"
            
            # Wait for Qdrant to be ready
            log "Waiting for Qdrant to be ready..."
            ready=false
            for i in {1..30}; do
                if curl -s "http://localhost:${QDRANT_PORT}/ready" &>/dev/null; then
                    log "✅ Qdrant is ready (attempt $i)."
                    ready=true
                    break
                fi
                sleep 1
            done
            
            if [[ "$ready" != true ]]; then
                log "⚠️  Qdrant may not be ready yet. Continuing anyway."
            fi
        else
            log "❌ Failed to start Docker containers."
            log "Check: docker-compose config"
            # Non-fatal - continue even if Qdrant fails
        fi
    fi
fi

#----------------------------------------------------------------------------
# Phase 8: Display Status
#----------------------------------------------------------------------------
log ""
log "📊 Phase 8: Environment Status"

if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] Would display final status"
else
    log "Ollama API: ${OLLAMA_BASE_URL}"
    
    if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        log "Qdrant API: http://localhost:${QDRANT_PORT}"
        log "Qdrant Dashboard: http://localhost:${QDRANT_PORT}/dashboard"
    fi
    
    log "Available Models:"
    "${OLLAMA_BIN}" list | tee -a "${LOG_FILE}" || true
    
    log "Loaded Models:"
    "${OLLAMA_BIN}" ps | tee -a "${LOG_FILE}" || true
fi

#----------------------------------------------------------------------------
# Final Status
#----------------------------------------------------------------------------
log ""
log "✅✅✅ Environment Started Successfully ✅✅✅"
log "=== Start of Day Complete ==="
log "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
log ""
log "Next steps:"
log "  - Test your models: ollama run <model-name>"
log "  - Check API: curl http://localhost:${OLLAMA_PORT}/api/tags"
log "  - View logs: tail -f ${OLLAMA_SERVER_LOG}"
log "  - Stop environment: ./scripts/eod.sh"
log ""

exit 0
