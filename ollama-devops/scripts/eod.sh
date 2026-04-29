#!/bin/bash
#============================================================================
# Title:            eod.sh
# Description:      Cross-platform End of Day script for Ollama environment
#                   Supports macOS (MacBook) and Linux (CachyOS/Arch)
# Author:           Keverall
# Date:             2026-04-29
# Version:          1.0.0
# Usage:            ./scripts/eod.sh
# Requirements:     bash, docker, docker-compose (optional), systemctl (Linux)
# Exit Codes:       0 - Success, 1 - Error
#============================================================================

set -euo pipefail

#----------------------------------------------------------------------------
# Configuration
#----------------------------------------------------------------------------
OLLAMA_HOST="${OLLAMA_HOST:-[::]:11434}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
QDRANT_PORT="${QDRANT_PORT:-6333}"

# Allow manual override of platform detection
PLATFORM_OVERRIDE="${PLATFORM_OVERRIDE:-auto}"  # auto, macos, linux

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

# Set platform-specific modfile directory (for consistency, even though eod.sh doesn't use modfiles)
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
# Logging Setup
#----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/eod-${PLATFORM}.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "${LOG_DIR}"

log() {
    echo "[$TIMESTAMP] $1" | tee -a "${LOG_FILE}"
}

log "🛑 Shutting down Ollama DevOps Environment..."
log "Platform: $PLATFORM"
log "Project root: ${PROJECT_ROOT}"

#----------------------------------------------------------------------------
# Stop Docker Containers (Qdrant, etc.)
#----------------------------------------------------------------------------
log ""
log "🐳 Stopping Docker containers..."

# Check common locations for docker-compose.yml
DOCKER_COMPOSE_FILE=""
if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
    DOCKER_COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
elif [[ -f "${SCRIPT_DIR}/docker-compose.yml" ]]; then
    DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
fi

if [[ -n "$DOCKER_COMPOSE_FILE" ]]; then
    cd "${PROJECT_ROOT}"
    # Try both v1 and v2 docker compose commands
    if docker-compose -f "$DOCKER_COMPOSE_FILE" down 2>/dev/null || docker compose -f "$DOCKER_COMPOSE_FILE" down 2>/dev/null; then
        log "✅ Docker containers stopped."
    else
        log "⚠️  Docker compose down failed (containers may not be running)."
    fi
else
    log "ℹ️  No docker-compose.yml found, skipping Docker cleanup."
fi

#----------------------------------------------------------------------------
# Stop Ollama Service (Platform-Specific)
#----------------------------------------------------------------------------
log ""
log "📡 Stopping Ollama services..."

case "$PLATFORM" in
    macos)
        # macOS: Use osascript to quit desktop app, then kill processes
        log "Stopping Ollama on macOS..."
        
        # Try graceful quit of Ollama desktop app
        if command -v osascript &>/dev/null; then
            osascript -e 'quit app "Ollama"' 2>/dev/null || log "  (No Ollama app running or osascript failed)"
        fi
        
        # Kill any ollama server processes (lowercase)
        if pgrep -f "ollama" > /dev/null 2>&1; then
            log "Killing ollama processes..."
            pkill -f "ollama" 2>/dev/null || true
        fi
        
        # Kill Ollama UI app (capital O) if running
        if pgrep -f "Ollama" > /dev/null 2>&1; then
            log "Killing Ollama app..."
            pkill -9 -f "Ollama" 2>/dev/null || true
        fi
        
        sleep 2
        
        # Verify shutdown
        if pgrep -f "ollama" > /dev/null 2>&1; then
            log "⚠️  Some ollama processes still running, forcing..."
            pkill -9 -f "ollama" 2>/dev/null || true
        fi
        
        log "✅ Ollama services stopped (macOS)."
        ;;
        
    cachyos|linux)
        # Linux: Try systemctl first, then fallback to process kill
        log "Stopping Ollama on Linux..."
        
        # Check if running as root or with sudo
        if command -v systemctl &>/dev/null && [[ $EUID -eq 0 || -w /etc/systemd/system ]]; then
            if systemctl list-units --type=service 2>/dev/null | grep -q "ollama.service"; then
                log "Stopping Ollama service via systemctl..."
                sudo systemctl stop ollama.service 2>/dev/null || true
                sleep 2
                
                if ! systemctl is-active --quiet ollama.service 2>/dev/null; then
                    log "✅ Ollama service stopped."
                else
                    log "⚠️  Service still active, attempting disable+stop..."
                    sudo systemctl disable ollama.service 2>/dev/null || true
                    sudo systemctl stop ollama.service 2>/dev/null || true
                    sleep 2
                    
                    if ! systemctl is-active --quiet ollama.service 2>/dev/null; then
                        log "✅ Ollama service stopped after disable."
                    else
                        log "❌ Failed to stop Ollama service via systemctl."
                    fi
                fi
            else
                log "ℹ️  Ollama systemd service not found."
            fi
        else
            log "ℹ️  No systemctl access, skipping systemd management."
        fi
        
        # Always attempt process kill as fallback or primary method
        if pgrep -f "ollama" > /dev/null 2>&1; then
            log "Killing remaining ollama processes..."
            pkill -f "ollama" 2>/dev/null || true
            sleep 2
            
            if pgrep -f "ollama" > /dev/null 2>&1; then
                log "Force killing stubborn ollama processes..."
                pkill -9 -f "ollama" 2>/dev/null || true
            fi
        fi
        
        if ! pgrep -f "ollama" > /dev/null 2>&1; then
            log "✅ Ollama processes stopped."
        else
            log "⚠️  Some ollama processes may still be running."
        fi
        ;;
        
    *)
        log "⚠️  Unknown platform '$PLATFORM', attempting generic shutdown..."
        if pgrep -f "ollama" > /dev/null 2>&1; then
            pkill -f "ollama" 2>/dev/null || true
            log "Killed ollama processes."
        fi
        ;;
esac

#----------------------------------------------------------------------------
# Cleanup and Final Status
#----------------------------------------------------------------------------
log ""
log "🧹 Performing final cleanup..."

# Clear any temporary files if needed
# (reserved for future cleanup tasks)

log ""
log "✅ Environment shutdown complete."
log "=== End of Day Complete ==="
log "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

exit 0
