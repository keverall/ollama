#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load the environment variables
source "$SCRIPT_DIR/.env"

echo "🛑 Shutting down DevOps Environment..."

# 1. Stop Docker containers
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    echo "🐳 Stopping Docker containers..."
    docker-compose -f "$SCRIPT_DIR/docker-compose.yml" down 2>/dev/null
else
    echo "ℹ️  No docker-compose.yml found, skipping Docker cleanup."
fi

# 2. Gracefully stop Ollama server (if running via 'ollama serve')
if "$OLLAMA_BIN" ps > /dev/null 2>&1; then
    echo "📡 Stopping Ollama server..."
    # Try graceful shutdown via SIGTERM to 'ollama serve' processes
    pkill -f "ollama serve" 2>/dev/null
    sleep 2
fi

# 3. Force kill any remaining Ollama processes
if pgrep -x "ollama" > /dev/null; then
    echo "🔪 Force-killing remaining Ollama processes..."
    killall -9 "ollama" 2>/dev/null
fi

# 4. Final cleanup of the Ollama app (macOS GUI)
osascript -e 'quit app "Ollama"' 2>/dev/null

echo "✅ All services stopped. VRAM cleared."