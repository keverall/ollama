#!/bin/bash

# Ollama Model Startup Script for MacBook M4 Pro 24GB
# Ensures Ollama is running and all models are available and preloaded
# Qwen2.5-Coder-14B
# Memory Math: 14B weights (9Gb) + 64k KV Cache (10-12Gb) with quantization = 21Gb
# DevOps Edge: Qwen2.5-Coder is the industry leader for local coding.
# It handles multi-file logic and obscure CLI syntax much better than Gemma or Llama 3.1 8B.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Script DIR: $SCRIPT_DIR"

# Load environment variables
# shellcheck disable=SC1091
source "$SCRIPT_DIR/.env"

echo " DEVOPS_MODEL = $DEVOPS_MODEL"
echo "OLLAMA_MODELS = $OLLAMA_MODELS"
echo "OLLAMA_BIN    = $OLLAMA_BIN"
echo "******************************************************************"
echo ""


# --- Phase 1: Stop existing Ollama instances ---
echo "🛑 Resetting Ollama to apply memory optimisations..."
osascript -e 'quit app "Ollama"' 2>/dev/null
killall "$OLLAMA_BIN" 2>/dev/null
sleep 2

# --- Phase 2: Start Ollama ---
echo "🚀 Starting Ollama with 24GB optimizations..."
"$OLLAMA_BIN" serve > /dev/null 2>&1 &
sleep 5

# --- Phase 3: Verify Ollama is running ---
if ! "$OLLAMA_BIN" list > /dev/null 2>&1; then
    echo "❌ Error: Ollama failed to start."
    exit 1
fi
echo "✅ Ollama is running."

# --- Phase 4: Ensure base models are present ---
echo "📦 Checking Models..."
IFS=',' read -ra MODELS <<< "$OLLAMA_MODELS"
for model in "${MODELS[@]}"; do
    if ! $OLLAMA_BIN list | grep -q "$model"; then
        echo "📥 Pulling $model..."
        $OLLAMA_BIN pull "$model"
    else
        echo "✅ $model already present."
    fi
done

# --- Phase 5: Ensure DevOps model is created ---
echo "devops modfile path: $SCRIPT_DIR/modfile-$DEVOPS_MODEL"
$OLLAMA_BIN list | grep "$DEVOPS_MODEL"

if ! $OLLAMA_BIN list | grep -q "$DEVOPS_MODEL"; then
    if [ -f "$SCRIPT_DIR/modfile-$DEVOPS_MODEL" ]; then
        echo "Creating $DEVOPS_MODEL..."
        $OLLAMA_BIN create "$DEVOPS_MODEL" -f "$SCRIPT_DIR/modfile-$DEVOPS_MODEL"
        echo "✅ $DEVOPS_MODEL created."
    else
        echo "❌ Modelfile not found: $SCRIPT_DIR/modfile-$DEVOPS_MODEL"
    fi
else
    echo "✅ $DEVOPS_MODEL already present."
fi

# --- Phase 6: Preload DevOps model (non-interactive) ---
echo "⏳ Warming up $DEVOPS_MODEL..."
if echo "hello testing" | "$OLLAMA_BIN" run "$DEVOPS_MODEL" > /dev/null 2>&1; then
    echo "✅ $DEVOPS_MODEL preloaded successfully!"
else
    echo "⚠️  $DEVOPS_MODEL preload failed. Continuing anyway..."
fi

# --- Phase 7: Display all models ---
echo ""
echo "Available models:"
"$OLLAMA_BIN" list

# --- Phase 8: API connectivity tests ---
echo "🔍 Testing API connectivity..."
curl -s http://127.0.0.1:11434/api/tags > /dev/null && echo "  IPv4:      OK" || echo "  IPv4:      FAIL"
curl -s http://[::1]:11434/api/tags > /dev/null && echo "  IPv6:      OK" || echo "  IPv6:      FAIL"
curl -s http://localhost:11434/api/tags > /dev/null && echo "  localhost: OK" || echo "  localhost: FAIL"

# --- Phase 9: Start vector DB containers ---
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    docker-compose -f "$SCRIPT_DIR/docker-compose.yml" up -d && echo "✅ Docker containers started!"
else
    echo "❌ Failed to start Docker containers. Please check the logs for details."
fi

echo "🚀 Docker qdrant vector DB containers started!"
echo "🚀 Ollama local LLM ready for use!"

