#!/bin/bash
#============================================================================
# Title:            eod.sh
# Description:      End of Day script for Ollama optimized environment
# Author:           Keverall
# Date:             2026-04-28
# Version:          1.0.0
# Usage:            ./scripts/eod.sh
# Requirements:     bash, systemctl, docker, pgrep, pkill
# Exit Codes:       0 - Success, 1 - Error
#============================================================================

set -euo pipefail

# Configuration
OLLAMA_HOST="${OLLAMA_HOST:-0.0.0.0}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
QDRANT_PORT="${QDRANT_PORT:-6333}"

# Log file for Ollama server output
OLLAMA_LOG="logs/ollama-devops.log"
touch "$OLLAMA_LOG"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

echo "log file: ${OLLAMA_LOG}"


log() {
    echo "[$TIMESTAMP] $1" | tee -a "${OLLAMA_LOG}"
}

log "Stopping Ollama DevOps environment..."

# Stop Qdrant using Docker Compose
log "Stopping Qdrant vector database..."
cd "$(dirname "$0")/.."
if [[ -f "docker-compose.yml" ]]; then
    docker-compose down
    log "Qdrant stopped."
else
    log "Warning: docker-compose.yml not found. Skipping Qdrant stop."
fi

# Stop Ollama service
log "Stopping Ollama service..."
# Since Ollama is running as a systemd service, use systemctl to stop it
if systemctl list-units --type=service | grep -q "ollama.service"; then
    log "Stopping Ollama service via systemctl..."
    sudo systemctl stop ollama.service
    # Wait a moment for it to stop
    sleep 2
    if ! systemctl list-units --type=service | grep -q "ollama.service.*running"; then
        log "Ollama service stopped."
    else
        log "Warning: Ollama service may not have stopped. Trying to disable and stop..."
        sudo systemctl disable ollama.service
        sudo systemctl stop ollama.service
        sleep 2
        if ! systemctl list-units --type=service | grep -q "ollama.service.*running"; then
            log "Ollama service stopped after disable."
        else
            log "Error: Failed to stop Ollama service."
        fi
    fi
else
    log "Ollama service not found in systemd. Checking for ollama serve process..."
    # Fallback: kill the ollama serve process if systemd service not found
    if pgrep -f "ollama serve" > /dev/null; then
        log "Stopping Ollama server process..."
        pkill -f "ollama serve"
        # Wait a moment for it to stop
        sleep 2
        if ! pgrep -f "ollama serve" > /dev/null; then
            log "Ollama server process stopped."
        else
            log "Warning: Ollama server process may not have stopped. Trying force kill..."
            pkill -9 -f "ollama serve"
            sleep 1
            if ! pgrep -f "ollama serve" > /dev/null; then
                log "Ollama server process force stopped."
            else
                log "Error: Failed to stop Ollama server process."
            fi
        fi
    else
        log "Ollama server is not running."
    fi
fi

log "=== Environment Stopped Successfully ==="
exit 0
