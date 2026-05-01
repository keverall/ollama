#!/bin/bash
#============================================================================
# Title:            sod.sh
# Description:      Cross-platform Start of Day script for Ollama environment
#                   Supports macOS (MacBook) and Linux (CachyOS/Arch) with systemd
# Author:           Keverall
# Date:             2026-04-30
# Version:          2.0.0
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

# Resolve SCRIPT_DIR early for library sourcing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize Logging Early (must be before any log calls)
# lib_logging.sh provides detect_platform and PLATFORM
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib_logging.sh"

# Initialize logging (LOG_DIR comes from PROJECT_ROOT or env, set below)
log_init "$(basename "${BASH_SOURCE[0]}" .sh)" "run" "$PLATFORM"

# Script-specific log file
OLLAMA_SERVER_LOG="${LOG_DIR}/ollama-server.log"

# Now safe to use log function
log INFO "Detected platform: $PLATFORM" "🎯 "

#----------------------------------------------------------------------------
# Resolve Paths & Configuration
#----------------------------------------------------------------------------

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
# Load Platform-Specific Environment
#----------------------------------------------------------------------------
# Load platform-specific .env FIRST, then apply fallback defaults
# This ensures .env values take precedence over hardcoded defaults

# Determine which .env file to load
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

if [[ -f "$PLATFORM_ENV_FILE" ]]; then
    log INFO "Loading environment from: $PLATFORM_ENV_FILE"
    # shellcheck disable=SC1090  # Platform .env path is dynamic
    source "$PLATFORM_ENV_FILE"
else
    log INFO "No platform-specific .env found, using defaults"
fi

#----------------------------------------------------------------------------
# Default Configuration (applied only if not set by .env or environment)
#----------------------------------------------------------------------------
# Basic infrastructure settings (not platform-specific, rarely need override)
OLLAMA_HOST="${OLLAMA_HOST:-[::]:11434}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_BASE_URL="http://localhost:${OLLAMA_PORT}"
[ -z "${DEVOPS_MODEL:-}" ] && DEVOPS_MODEL=""
[ -z "${DEFAULT_MODELS:-}" ] && DEFAULT_MODELS=""
[ -z "${OLLAMA_NUM_PARALLEL:-}" ] && OLLAMA_NUM_PARALLEL="24"
[ -z "${OLLAMA_MAX_LOADED_MODELS:-}" ] && OLLAMA_MAX_LOADED_MODELS="2"
[ -z "${QDRANT_PORT:-}" ] && QDRANT_PORT="6333"

# Resolve OLLAMA_BIN to absolute path if possible
OLLAMA_BIN="${OLLAMA_BIN:-ollama}"
if command -v "$OLLAMA_BIN" &>/dev/null; then
    OLLAMA_BIN="$(command -v "$OLLAMA_BIN")"
fi

# All other values (DEFAULT_MODELS, DEVOPS_MODEL, OLLAMA_NUM_PARALLEL,
# OLLAMA_MAX_LOADED_MODELS, QDRANT_PORT, etc.) come from the platform .env file.
# Do not hardcode them here — each platform's .env is the source of truth.

log INFO "🚀 Starting Ollama DevOps Environment..."
log INFO "Platform: $PLATFORM"
log INFO "Project root: ${PROJECT_ROOT}"
 log INFO "Ollama bin: ${OLLAMA_BIN}"
 log INFO "Modfile dir: ${MODFILE_DIR}"
 
 # Backward compatibility: if DEFAULT_MODELS not set but MODEL_LIST is, use it
 if [[ -z "${DEFAULT_MODELS:-}" && -n "${MODEL_LIST:-}" ]]; then
     DEFAULT_MODELS="$MODEL_LIST"
     log INFO "Using MODEL_LIST as DEFAULT_MODELS: $DEFAULT_MODELS"
 fi
 
 if [[ "$DRY_RUN" == true ]]; then
     log WARN "DRY RUN MODE - No actual changes will be made"
 fi

#----------------------------------------------------------------------------
# Helper Functions
#----------------------------------------------------------------------------

# Check if a command exists
check_command() {
    command -v "$1" &>/dev/null
}

# Check if passwordless sudo is configured for ollama service management
check_passwordless_sudo() {
    # Skip check if running as root
    [[ $EUID -eq 0 ]] && return 0
    
    # Skip check on macOS (no systemd/sudo needed)
    [[ "$PLATFORM" == "macos" ]] && return 0
    
    # Skip check if systemctl not available
    command -v systemctl &>/dev/null || return 0
    
    # Test if passwordless sudo works for at least one systemctl command
    if sudo -n systemctl is-active --quiet ollama 2>/dev/null || \
       sudo -n systemctl daemon-reload 2>/dev/null; then
        return 0  # Passwordless sudo is working
    fi
    
    # Passwordless sudo not configured - warn but don't block
    log WARN "Passwordless sudo not configured for systemctl commands"
    log WARN "Service operations will be skipped unless run as root"
    log WARN "Run: sudo $SCRIPT_DIR/setup_passwordless_sudo.sh"
    log WARN "Or run this script as root: sudo $0"
    return 1  # Return non-zero to indicate issue
}

# Helper: run systemctl with sudo fallback
# Usage: run_systemctl <command> [additional args...]
# Examples: run_systemctl stop ollama
#           run_systemctl daemon-reload
run_systemctl() {
    local cmd="$1"
    shift 2>/dev/null || true  # Drop cmd, keep rest as service name if present

    if [[ "$DRY_RUN" == true ]]; then
        if [[ "$cmd" == "daemon-reload" ]]; then
            log INFO "[dry-run] Would run: systemctl $cmd"
        else
            local service="${1:-ollama}"
            log INFO "[dry-run] Would run: systemctl $cmd $service"
        fi
        return 0
    fi

    # Determine service name (if applicable)
    local service=""
    if [[ "$cmd" != "daemon-reload" ]]; then
        service="${1:-ollama}"
    fi

    if [[ $EUID -eq 0 ]]; then
        # Running as root, no sudo needed
        if [[ -n "$service" ]]; then
            systemctl "$cmd" "$service" 2>&1 | tee -a "${LOG_FILE}" || true
        else
            systemctl "$cmd" 2>&1 | tee -a "${LOG_FILE}" || true
        fi
    elif command -v sudo &>/dev/null; then
        # Use sudo -n to avoid password prompts; fail gracefully if not allowed
        if [[ -n "$service" ]]; then
            sudo -n systemctl "$cmd" "$service" 2>&1 | tee -a "${LOG_FILE}" || {
                log WARN "Skipping 'systemctl $cmd $service' (requires passwordless sudo)"
                log INFO "Run manually: sudo systemctl $cmd $service"
                return 0
            }
        else
            sudo -n systemctl "$cmd" 2>&1 | tee -a "${LOG_FILE}" || {
                log WARN "Skipping 'systemctl $cmd' (requires passwordless sudo)"
                log INFO "Run manually: sudo systemctl $cmd"
                return 0
            }
        fi
    else
        log WARN "sudo not available, skipping 'systemctl $cmd ${service:-}'"
        return 0
    fi
}

run_with_timeout() {
    local timeout_sec="$1"
    shift
    if command -v timeout &>/dev/null; then
        timeout "$timeout_sec" "$@"
        return $?
    fi
    "$@" &
    local child=$!
    ( sleep "$timeout_sec" && kill -9 "$child" 2>/dev/null ) &
    local timer_pid=$!
    wait "$child" 2>/dev/null
    local rc=$?
    kill "$timer_pid" 2>/dev/null 2>&1
    wait "$timer_pid" 2>/dev/null 2>&1
    return $rc
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

# Write systemd environment file for Ollama service
# This configures /etc/default/ollama or /etc/sysconfig/ollama based on platform
configure_systemd_env() {
    local env_file=""
    local distro_id=""
    
    # Determine which env file to use based on platform
    case "$PLATFORM" in
        cachyos|linux)
            # Prefer /etc/default/ollama (Debian/Ubuntu style); CachyOS may use this
            if [[ -f /etc/os-release ]]; then
                # shellcheck disable=SC1091
                distro_id="$(. /etc/os-release && echo "$ID")"
                case "$distro_id" in
                    arch|cachyos)
                        env_file="/etc/sysconfig/ollama"  # Red Hat style
                        ;;
                    *)
                        env_file="/etc/default/ollama"   # Debian style
                        ;;
                esac
            else
                env_file="/etc/default/ollama"
            fi
            ;;
        macos)
            # macOS doesn't use systemd
            log "Systemd environment configuration skipped (macOS uses direct process management)"
            return 0
            ;;
        *)
            log "Unknown platform for systemd configuration: $PLATFORM"
            return 1
            ;;
    esac
    
    # Check if we can write to the env file location (requires sudo)
    local env_dir
    env_dir="$(dirname "$env_file")"
    if [[ ! -w "$env_dir" && $EUID -ne 0 ]]; then
        log "⚠️  Cannot write to $env_file (requires root). Skipping systemd configuration."
        log "   Ollama service will use existing configuration."
        return 1
    fi
    
    log "Configuring systemd environment file: $env_file"
    
    # Backup existing file if present
    if [[ -f "$env_file" ]]; then
        local backup_file
        backup_file="${env_file}.bak.$(date +%Y%m%d_%H%M%S)"
        log "Backing up existing $env_file to $backup_file"
        cp "$env_file" "$backup_file" 2>/dev/null || true
    fi
    
    # Write new environment file
    # Note: This will likely require sudo
    local env_content=""
    env_content+="# Ollama environment configuration\n"
    env_content+="# Generated by sod.sh on $(date)\n"
    env_content+="# Platform: $PLATFORM\n\n"
    env_content+="OLLAMA_HOST=${OLLAMA_HOST}\n"
    env_content+="OLLAMA_PORT=${OLLAMA_PORT}\n"
    env_content+="OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL}\n"
    env_content+="OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS}\n"
    
    # OLLAMA_MODELS: override model storage location (e.g., move to home partition)
    if [[ -n "${OLLAMA_MODELS:-}" ]]; then
        env_content+="OLLAMA_MODELS=${OLLAMA_MODELS}\n"
    fi
    
    # Platform-specific additions
    case "$PLATFORM" in
        cachyos|linux)
            env_content+="OLLAMA_GPU_LAYERS=${OLLAMA_GPU_LAYERS:-50}\n"
            env_content+="CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}\n"
            ;;
        macos)
            env_content+="OLLAMA_FLASH_ATTENTION=${OLLAMA_FLASH_ATTENTION:-1}\n"
            env_content+="OLLAMA_KV_CACHE_TYPE=${OLLAMA_KV_CACHE_TYPE:-q4_0}\n"
            ;;
    esac
    
    # Write with sudo if not root
    if [[ $EUID -eq 0 ]]; then
        printf "%s" "$env_content" > "$env_file" 2>/dev/null || {
            log "❌ Failed to write $env_file"
            return 1
        }
    else
        printf "%s" "$env_content" | tee "$env_file" >/dev/null 2>&1 || {
            log "❌ Failed to write $env_file (may need sudo)"
            return 1
        }
    fi
    
    log "✅ Systemd environment configured: $env_file"
    return 0
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

# Verify passwordless sudo configuration (warns if not set up)
check_passwordless_sudo || true

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
        # Linux: Stop any systemd-managed Ollama first, then kill stray processes
        log "Stopping existing Ollama service (if running)..."
        
        # Try systemctl stop first (if service exists and we have access)
        if command -v systemctl &>/dev/null; then
            run_systemctl stop ollama || true
            run_systemctl disable ollama || true
            sleep 2
        fi
        
        # Also kill any lingering Ollama processes
        log "Cleaning up stray Ollama processes..."
         pgrep -f "ollama" 2>/dev/null | while read -r pid; do
             if [[ "$pid" != "$SCRIPT_PID" ]]; then
                 if ! ps -p "$pid" -o args= 2>/dev/null | grep -q "sod\.sh"; then
                     kill -TERM "$pid" 2>/dev/null || true
                 fi
             fi
         done || true
        sleep 2
        
        # Force kill any remaining
        log "Sending SIGKILL to remaining Ollama processes..."
         pgrep -f "ollama" 2>/dev/null | while read -r pid; do
             if [[ "$pid" != "$SCRIPT_PID" ]]; then
                 if ! ps -p "$pid" -o args= 2>/dev/null | grep -q "sod\.sh"; then
                     kill -9 "$pid" 2>/dev/null || true
                 fi
             fi
         done || true
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
    # Export environment variables for Ollama (used by both systemd and direct start)
    export OLLAMA_HOST="${OLLAMA_HOST}"
    export OLLAMA_PORT="${OLLAMA_PORT}"
    export OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL}"
    export OLLAMA_MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS}"
    export OLLAMA_MODELS="${OLLAMA_MODELS:-}"
    
    # Platform-specific optimizations (also exported for systemd)
    case "$PLATFORM" in
        macos)
            export OLLAMA_FLASH_ATTENTION="${OLLAMA_FLASH_ATTENTION:-1}"
            export OLLAMA_KV_CACHE_TYPE="${OLLAMA_KV_CACHE_TYPE:-q4_0}"
            ;;
        cachyos|linux)
            export OLLAMA_GPU_LAYERS="${OLLAMA_GPU_LAYERS:-50}"
            export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
            ;;
    esac
    
    # If OLLAMA_MODELS is set, ensure the directory exists and has correct permissions
    if [[ -n "${OLLAMA_MODELS:-}" ]]; then
        log "OLLAMA_MODELS directory: ${OLLAMA_MODELS}"
        if [[ ! -d "${OLLAMA_MODELS}" ]]; then
            log "  Creating directory: ${OLLAMA_MODELS}"
            if ! sudo -n mkdir -p "${OLLAMA_MODELS}" 2>/dev/null; then
                log "  ⚠️  Failed to create ${OLLAMA_MODELS} (permission issue?)"
            fi
        fi
        # Make it world-writable to allow both 'ollama' service user and current user to write
        # (Acceptable for single-user dev environment)
        if [[ -d "${OLLAMA_MODELS}" ]]; then
            sudo -n chmod a+rwx "${OLLAMA_MODELS}" 2>/dev/null || true
            # Also ensure the full path is accessible
            for parent in "${OLLAMA_MODELS}" "${OLLAMA_MODELS%/*}" "${OLLAMA_MODELS%/*/*}"; do
                [[ -d "$parent" ]] && sudo -n chmod 755 "$parent" 2>/dev/null || true
            done
            log "  Set permissions: world-writable (shared access)"
        fi
    fi
    
    # Prepare server log
    touch "${OLLAMA_SERVER_LOG}"
    log "Ollama server log: ${OLLAMA_SERVER_LOG}"
    
    # Platform-specific startup method
    case "$PLATFORM" in
        cachyos|linux)
            log "Linux platform detected: using systemd service management"
            
            # Check for systemctl availability
            if ! check_command systemctl; then
                log "⚠️  systemctl not found. Skipping systemd management; will use direct start fallback."
            fi
            
            # Install/update systemd service file if needed
            SCRIPT_SYSTEMD_SERVICE="${PROJECT_ROOT}/systemd/ollama.service"
            SYSTEM_SYSTEMD_SERVICE="/etc/systemd/system/ollama.service"
            
            if [[ -f "$SCRIPT_SYSTEMD_SERVICE" ]]; then
                # Check if service file differs or doesn't exist
                need_install=false
                if [[ ! -f "$SYSTEM_SYSTEMD_SERVICE" ]]; then
                    need_install=true
                    log "Installing systemd service file..."
                else
                    # Compare files (simple check)
                    if ! diff -q "$SCRIPT_SYSTEMD_SERVICE" "$SYSTEM_SYSTEMD_SERVICE" >/dev/null 2>&1; then
                        need_install=true
                        log "Updating systemd service file..."
                    fi
                fi
                
                if [[ "$need_install" == true ]]; then
                    log "Copying $SCRIPT_SYSTEMD_SERVICE to $SYSTEM_SYSTEMD_SERVICE"
                    if command -v sudo &>/dev/null && [[ $EUID -ne 0 ]]; then
                        if ! sudo -n cp "$SCRIPT_SYSTEMD_SERVICE" "$SYSTEM_SYSTEMD_SERVICE" 2>&1 | tee -a "${LOG_FILE}"; then
                            log "⚠️  Failed to install systemd service file (permission denied). Skipping systemd management."
                            log "   Run manually: sudo cp $SCRIPT_SYSTEMD_SERVICE $SYSTEM_SYSTEMD_SERVICE"
                        fi
                    else
                        if ! cp "$SCRIPT_SYSTEMD_SERVICE" "$SYSTEM_SYSTEMD_SERVICE" 2>&1 | tee -a "${LOG_FILE}"; then
                            log "⚠️  Failed to install systemd service file (permission denied). Skipping systemd management."
                        fi
                    fi
                fi
            else
                log "⚠️  Systemd service file not found at $SCRIPT_SYSTEMD_SERVICE"
                log "   Ollama systemd service may already be installed system-wide."
             fi
             
             # Reload systemd daemon to recognize new/changed service file
             log "Reloading systemd daemon..."
             run_systemctl daemon-reload

             # Ensure service is enabled for auto-start (optional but recommended)
             log "Enabling Ollama service for auto-start..."
             run_systemctl enable ollama
             
             # Configure systemd environment file before starting service
            if [[ -w /etc/default/ollama || -w /etc/sysconfig/ollama || $EUID -eq 0 ]]; then
                configure_systemd_env || log "⚠️  Systemd env configuration had issues, continuing with existing config"
                
                # Reload systemd to pick up environment changes
                log "Reloading systemd daemon..."
                run_systemctl daemon-reload
            else
                log "⚠️  No write access to systemd env files. Using existing Ollama service configuration."
                log "   To customize, edit /etc/default/ollama or /etc/sysconfig/ollama as root"
            fi
            
            # Stop any existing Ollama processes started by sod.sh (not systemd)
            log "Checking for leftover Ollama processes..."
            if pgrep -f "ollama serve" > /dev/null 2>&1; then
                log "Killing stray Ollama processes before systemd start..."
                pkill -f "ollama serve" 2>/dev/null || true
                sleep 2
            fi
            
            # Start via systemd (service must be installed: systemctl enable ollama)
            log "Starting Ollama via systemctl start ollama..."
            
            STARTED_VIA_SYSTEMD=false
            if [[ $EUID -ne 0 ]]; then
                if sudo -n systemctl start ollama 2>&1 | tee -a "${LOG_FILE}"; then
                    STARTED_VIA_SYSTEMD=true
                else
                    log "⚠️  systemctl start failed (likely requires passwordless sudo)."
                fi
            else
                if systemctl start ollama 2>&1 | tee -a "${LOG_FILE}"; then
                    STARTED_VIA_SYSTEMD=true
                else
                    log "⚠️  systemctl start failed."
                fi
            fi
            
            # Fallback: direct start if systemd failed
            if [[ "$STARTED_VIA_SYSTEMD" == false ]]; then
                log "Falling back to direct start: ollama serve &"
                # Server already has env vars exported; start in background
                nohup ollama serve > "${OLLAMA_SERVER_LOG}" 2>&1 &
                OLLAMA_BG_PID=$!
                log "  Ollama server started directly (PID: ${OLLAMA_BG_PID})"
                sleep 2
            else
                # Brief wait for service to spawn
                sleep 2
                
                # Verify service is active
                if [[ $EUID -ne 0 ]]; then
                    if ! sudo -n systemctl is-active --quiet ollama 2>/dev/null; then
                        log "❌ Ollama service is not active after start"
                        log "   Check logs: journalctl -u ollama -n 20"
                        exit 1
                    fi
                else
                    if ! systemctl is-active --quiet ollama 2>/dev/null; then
                        log "❌ Ollama service is not active after start"
                        log "   Check logs: journalctl -u ollama -n 20"
                        exit 1
                    fi
            fi
            
            # Verify server is responding
            sleep 1
            if ! curl -sf "http://localhost:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
                log "❌ Ollama server failed to respond on port ${OLLAMA_PORT}"
                exit 1
            fi
            log "✅ Ollama server is responsive."
            fi
            ;;
            
        macos)
            # macOS: Start directly (no systemd)
            log "macOS platform detected: starting Ollama directly"
            
            # Ensure any old Ollama processes are stopped
            if pgrep -f "ollama" > /dev/null 2>&1; then
                log "Stopping existing Ollama processes..."
                pkill -f "ollama" 2>/dev/null || true
                sleep 2
            fi
            
            # Start directly
            log "Starting ollama serve..."
            "${OLLAMA_BIN}" serve >> "${OLLAMA_SERVER_LOG}" 2>&1 &
            OLLAMA_PID=$!
            log "Ollama started with PID: ${OLLAMA_PID}"
            ;;
        *)
            log "⚠️  Unknown platform: $PLATFORM, falling back to direct start"
            "${OLLAMA_BIN}" serve >> "${OLLAMA_SERVER_LOG}" 2>&1 &
            OLLAMA_PID=$!
            log "Ollama started with PID: ${OLLAMA_PID}"
            ;;
    esac
    
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
    log "[dry-run] Would start Ollama via $([[ $PLATFORM == cachyos || $PLATFORM == linux ]] && echo 'systemctl start ollama' || echo 'ollama serve &')"
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
    
    # If a modelfile is provided, extract its base model (FROM directive)
    local base_model=""
    if [[ -n "$modfile_name" && -f "${MODFILE_DIR}/${modfile_name}" ]]; then
        base_model="$(grep -E '^FROM[[:space:]]+' "${MODFILE_DIR}/${modfile_name}" | head -1 | awk '{print $2}')"
        
        # If base model is different from target, ensure base exists first
        if [[ -n "$base_model" && "$base_model" != "$model_name" ]]; then
            log "  📥 Ensuring base model '$base_model' exists (required by modelfile)..."
            if ! ensure_model "$base_model" ""; then
                log "  ❌ Failed to ensure base model '$base_model' — cannot create $model_name from modelfile"
                return 1
            fi
            log "  ✅ Base model '$base_model' is available."
        fi
        
        # Try to create from modfile (base model now guaranteed to exist if different)
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
                qwen2.5-coder:32b-gpu)
                    [[ -f "${MODFILE_DIR}/qwen2.5-coder:32b-gpu.modelfile" ]] && echo "qwen2.5-coder:32b-gpu.modelfile" && return 0
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
                if echo "hello" | run_with_timeout 60 "${OLLAMA_BIN}" run "$DEVOPS_MODEL" &>/dev/null; then
                    log "  ✅ ${DEVOPS_MODEL} preloaded and ready."
                else
                    log "  ⚠️  ${DEVOPS_MODEL} preload timed out or failed."
                fi
            fi
            ;;
         cachyos|linux)
 # Warm up 72B (quality) and 7B (speed) on Linux/GPU
              for warm_model in "qwen2.5-coder:32b-gpu" "qwen2.5:7b-instruct"; do
                 if "${OLLAMA_BIN}" list 2>/dev/null | grep -q "^${warm_model}[[:space:]:]"; then
                     log "Warming up ${warm_model}..."
                     # Increase timeout for larger models
                     if [[ "$warm_model" == *"72b"* ]]; then
                         WARMUP_TIMEOUT=300  # 5 minutes for 72B model
                     else
                         WARMUP_TIMEOUT=120  # 2 minutes for 7B model
                     fi
                       if echo "Hello" | run_with_timeout "$WARMUP_TIMEOUT" "${OLLAMA_BIN}" run "$warm_model" 2>&1 | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tee -a "${LOG_FILE}"; then
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
            if [[ $ready -ne 1 ]]; then
                log "⚠️ Qdrant readiness check timed out, but containers may still be starting."
            fi
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
