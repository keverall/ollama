#!/bin/bash
#============================================================================
# Title:            eod.sh
# Description:      Cross-platform End of Day script for Ollama environment
#                   Supports macOS (MacBook) and Linux (CachyOS/Arch) with systemd
# Author:           Keverall
# Date:             2026-04-30
# Version:          2.0.1
# Usage:            ./scripts/eod.sh [--dry-run]
# Requirements:     bash, docker, docker-compose (optional), systemctl (Linux)
#                   passwordless sudo (recommended for Linux systemd operations)
# Exit Codes:       0 - Success, 1 - Error
#
# SUDO BEHAVIOR:
#   - Passwordless sudo configured: performs all systemctl operations without prompts
#   - Sudo requires a password: skips systemctl operations gracefully, logs manual commands
#   - Running as root: operates without sudo
#
# CONFIGURING PASSWORDLESS SUDO (Linux):
#   Run: sudo visudo
#   Add this line (replace $USER with your username):
#     $USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start ollama
#     $USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop ollama
#     $USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl disable ollama
#   Or allow all systemctl commands (less secure):
#     $USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl *
#
#   Verify: sudo -n true && echo "Passwordless sudo configured" || echo "Password required"
#============================================================================

set -euo pipefail

#----------------------------------------------------------------------------
# Shared Logging Library
#----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow PROJECT_ROOT override (useful for test harnesses)
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

#----------------------------------------------------------------------------
# Configuration
#----------------------------------------------------------------------------
OLLAMA_HOST="${OLLAMA_HOST:-[::]:11434}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
QDRANT_PORT="${QDRANT_PORT:-6333}"

# Allow manual override of platform detection
PLATFORM_OVERRIDE="${PLATFORM_OVERRIDE:-auto}"  # auto, macos, linux

# Dry-run mode
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Cross-platform End of Day shutdown script for Ollama DevOps environment."
            echo "Stops Docker containers and Ollama services on macOS and Linux."
            echo ""
            echo "Options:"
            echo "  --dry-run    Simulate actions without making changes"
            echo "  --help, -h   Show this help message"
            echo ""
            echo "Linux Sudo Requirements:"
            echo "  - Recommended: Configure passwordless sudo for 'systemctl' commands"
            echo "  - Without it: systemctl operations are skipped, manual commands logged"
            echo ""
            echo "See script header or README for passwordless sudo configuration details."
            exit 0
            ;;
        *)
            echo "Warning: Unknown argument: $arg" >&2
            ;;
    esac
done

# Platform Detection and Logging Initialization
#----------------------------------------------------------------------------

# Initialize shared logging (lib_logging.sh provides detect_platform and PLATFORM)
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib_logging.sh"
log_init "$(basename "${BASH_SOURCE[0]}" .sh)" "run" "$PLATFORM"

log INFO "Detected platform: $PLATFORM" "🎯 "

# Allow PROJECT_ROOT override (useful for test harnesses)
# PROJECT_ROOT is already set above before sourcing lib_logging.sh
: "${PROJECT_ROOT}"

# Set platform-specific modfile directory (for consistency with sod.sh)
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
# Mark MODFILE_DIR as used (set for consistency with sod.sh)
: "${MODFILE_DIR}"

# Check for dry-run flag
if [[ "$DRY_RUN" == true ]]; then
    log WARN "DRY RUN MODE - No actual changes will be made"
fi

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
run_systemctl() {
    local cmd="$1"
    if [[ "$DRY_RUN" == true ]]; then
        log INFO "[dry-run] Would run: systemctl $cmd ollama"
        return 0
    fi

    if [[ $EUID -eq 0 ]]; then
        # Running as root, no sudo needed
        systemctl "$cmd" ollama 2>&1 | tee -a "${LOG_FILE}" || true
    elif command -v sudo &>/dev/null; then
        # Use sudo -n to avoid password prompts; fail gracefully if not allowed
        sudo -n systemctl "$cmd" ollama 2>&1 | tee -a "${LOG_FILE}" || {
            log WARN "Skipping 'systemctl $cmd ollama' (requires passwordless sudo)"
            log INFO "Run manually: sudo systemctl $cmd ollama"
            return 0
        }
    else
        log WARN "sudo not available, skipping 'systemctl $cmd ollama'"
        return 0
    fi
}

# Verify passwordless sudo configuration (warns if not set up)
CAN_USE_SUDO=true
check_passwordless_sudo || CAN_USE_SUDO=false

log INFO "Shutting down Ollama DevOps Environment..." "🛑 "
log INFO "Platform: $PLATFORM"
log INFO "Project root: ${PROJECT_ROOT}"

#----------------------------------------------------------------------------
# Stop Docker Containers (Qdrant, etc.)
#----------------------------------------------------------------------------
log ""
log INFO "Stopping Docker containers..." "🐳 "

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
        log SUCCESS "Docker containers stopped."
    else
        log WARN "Docker compose down failed (containers may not be running)."
    fi
else
    log INFO "No docker-compose.yml found, skipping Docker cleanup."
fi

#----------------------------------------------------------------------------
# Stop Ollama Service (Platform-Specific)
#----------------------------------------------------------------------------
log ""
log INFO "Stopping Ollama services..." "📡 "

case "$PLATFORM" in
    macos)
        # macOS: Use osascript to quit desktop app, then kill processes
        log INFO "Stopping Ollama on macOS..."
        
        # Try graceful quit of Ollama desktop app
        if command -v osascript &>/dev/null; then
            osascript -e 'quit app "Ollama"' 2>/dev/null || log INFO "  (No Ollama app running or osascript failed)"
        fi
        
        # Kill any ollama server processes (lowercase)
        if pgrep -f "ollama" > /dev/null 2>&1; then
            log INFO "Killing ollama processes..."
            pkill -f "ollama" 2>/dev/null || true
        fi
        
        # Kill Ollama UI app (capital O) if running
        if pgrep -f "Ollama" > /dev/null 2>&1; then
            log INFO "Killing Ollama app..."
            pkill -9 -f "Ollama" 2>/dev/null || true
        fi
        
        sleep 2
        
        # Verify shutdown
        if pgrep -f "ollama" > /dev/null 2>&1; then
            log WARN "Some ollama processes still running, forcing..."
            pkill -9 -f "ollama" 2>/dev/null || true
        fi
        
        log SUCCESS "Ollama services stopped (macOS)."
        ;;
        
    cachyos|linux)
        # Linux: systemd primary management, with process kill fallback
        log INFO "Stopping Ollama on Linux..."
        
        # Step 1: Disable service to prevent automatic restart
        log INFO "Disabling Ollama service auto-restart..."
        run_systemctl disable
        
        # Step 2: Stop the service
        log INFO "Stopping Ollama service via systemctl..."
        if command -v systemctl &>/dev/null; then
            run_systemctl stop
            sleep 2
            
            # Check if service stopped (skip in dry-run)
            if [[ "$DRY_RUN" == true ]]; then
                log SUCCESS "Ollama service would be stopped (dry-run)."
            else
                service_stopped=false
                if [[ "$CAN_USE_SUDO" == false ]] && [[ $EUID -ne 0 ]]; then
                    log WARN "Cannot verify service status (requires passwordless sudo or root)"
                    log INFO "Verify manually: sudo systemctl is-active ollama"
                    service_stopped=true  # Assume success, can't verify
                elif command -v sudo &>/dev/null && [[ $EUID -ne 0 ]]; then
                    if ! sudo -n systemctl is-active --quiet ollama 2>/dev/null; then
                        service_stopped=true
                    fi
                else
                    if ! systemctl is-active --quiet ollama 2>/dev/null; then
                        service_stopped=true
                    fi
                fi
                
                if [[ "$service_stopped" == true ]]; then
                    log SUCCESS "Ollama service stopped via systemctl."
                else
                    log WARN "Service still active after systemctl stop, attempting process kill..."
                fi
            fi
        else
            log INFO "systemctl not available, skipping systemd management."
        fi
        
        # Step 3: Force kill any Ollama processes (including respawned ones)
        if [[ "$DRY_RUN" == true ]]; then
            log INFO "[dry-run] Would kill remaining Ollama processes"
        elif pgrep -f "ollama" > /dev/null 2>&1; then
            log INFO "Killing remaining Ollama processes..."
            pkill -TERM -f "ollama" 2>/dev/null || true
            sleep 2
            
            if pgrep -f "ollama" > /dev/null 2>&1; then
                log INFO "Force killing stubborn Ollama processes..."
                pkill -9 -f "ollama" 2>/dev/null || true
                sleep 1
            fi
        fi
        
        # Step 4: Verify shutdown
        if ! pgrep -f "ollama" > /dev/null 2>&1; then
            log SUCCESS "Ollama processes stopped."
        else
            log ERROR "FAILED to stop all Ollama processes."
            log INFO "Manual intervention may be required: sudo pkill -9 ollama"
        fi
        ;;
        
    *)
        log WARN "Unknown platform '$PLATFORM', attempting generic shutdown..."
        if pgrep -f "ollama" > /dev/null 2>&1; then
            pkill -f "ollama" 2>/dev/null || true
            log INFO "Killed ollama processes."
        fi
        ;;
esac
# Mark MODFILE_DIR as used (set for consistency with sod.sh)
: "${MODFILE_DIR}"

#----------------------------------------------------------------------------
# Cleanup and Final Status
#----------------------------------------------------------------------------
log ""
log INFO "Performing final cleanup..." "🧹 "

# Clear any temporary files if needed
# (reserved for future cleanup tasks)

log ""
log SUCCESS "Environment shutdown complete."
log INFO "=== End of Day Complete ==="
log INFO "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

exit 0
