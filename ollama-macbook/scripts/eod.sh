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

# 2. Stop Ollama server and app
echo "📡 Stopping Ollama services..."
# Try graceful quit of the Ollama desktop app
osascript -e 'quit app "Ollama"' 2>/dev/null
# Kill any ollama server processes
killall -9 "ollama" 2>/dev/null
# Kill the Ollama UI app if still running
killall -9 "Ollama" 2>/dev/null

echo "✅ All services stopped. VRAM cleared."