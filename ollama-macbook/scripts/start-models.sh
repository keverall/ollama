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

# Ensure required environment variables are set
: "${OLLAMA_BIN:?OLLAMA_BIN not set in .env}"
: "${MODEL_LIST:?MODEL_LIST not set in .env}"
: "${DEVOPS_MODEL:?DEVOPS_MODEL not set in .env}"

# Pre-flight: Check required system binaries (excluding $OLLAMA_BIN which comes from .env)
for cmd in docker docker-compose curl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Required command not found: $cmd"
        exit 1
    fi
done

echo " DEVOPS_MODEL = $DEVOPS_MODEL"
echo "MODEL_LIST    = $MODEL_LIST"
echo "OLLAMA_BIN    = $OLLAMA_BIN"
echo "OLLAMA_HOST   = $OLLAMA_HOST"
echo "******************************************************************"
echo ""

# Log file for Ollama server output
OLLAMA_LOG="logs/ollama-macbook-server.log"
touch "$OLLAMA_LOG"

# --- Phase 1: Stop existing Ollama instances ---
echo "🛑 Resetting Ollama to apply memory optimisations..."
# Try graceful quit of the Ollama desktop app
osascript -e 'quit app "Ollama"' 2>/dev/null
# Kill any ollama server processes (lowercase)
killall -9 "ollama" 2>/dev/null
# Also kill the Ollama UI app (capital O) if still running
killall -9 "Ollama" 2>/dev/null
sleep 2

# --- Phase 2: Start Ollama ---
echo "🚀 Starting Ollama with 24GB optimizations..."
# Ensure OLLAMA_HOST is set for IPv6+IPv4 dual stack
export OLLAMA_HOST="${OLLAMA_HOST:-[::]:11434}"
"$OLLAMA_BIN" serve > "$OLLAMA_LOG" 2>&1 &
OLLAMA_PID=$!
echo "   Ollama PID: $OLLAMA_PID"
sleep 3

# --- Phase 3: Verify Ollama is running (with retries) ---
echo "🔍 Waiting for Ollama to become ready..."
MAX_RETRIES=10
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if "$OLLAMA_BIN" list > /dev/null 2>&1; then
        echo "✅ Ollama is running (attempt $((RETRY_COUNT+1)))."
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT+1))
    echo "   Waiting for Ollama to start... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ Error: Ollama failed to start after $MAX_RETRIES attempts."
    echo "   Last 10 lines of log:"
    tail -n 10 "$OLLAMA_LOG" 2>/dev/null || echo "No log file."
    exit 1
fi

# --- Phase 4: Ensure base models are present ---
echo "📦 Checking Base Models..."
IFS=',' read -ra MODELS <<< "$MODEL_LIST"
for model in "${MODELS[@]}"; do
    model_trimmed="$(echo "$model" | xargs)"  # Trim whitespace
    # Match model name (optionally with :tag) at start of line
    if ! "$OLLAMA_BIN" list 2>/dev/null | grep -q "^${model_trimmed}[[:space:]:]"; then
        echo "📥 Pulling $model_trimmed..."
        if "$OLLAMA_BIN" pull "$model_trimmed"; then
            echo "✅ $model_trimmed pulled."
        else
            echo "❌ Failed to pull $model_trimmed"
            exit 1
        fi
    else
        echo "✅ $model_trimmed already present."
    fi
done
unset IFS

# Determine modfile path for DevOps model
DEVOPS_MODFILE="$SCRIPT_DIR/../modfiles/modfile-$DEVOPS_MODEL"
echo "DEVOPS_MODFILE = $DEVOPS_MODFILE"

# Check if model exists (matches first column in ollama list)
if "$OLLAMA_BIN" list 2>/dev/null | grep -q "^${DEVOPS_MODEL}[[:space:]:]"; then
    echo "✅ $DEVOPS_MODEL already present."
else
    if [ -f "$DEVOPS_MODFILE" ]; then
        echo "Creating $DEVOPS_MODEL from $DEVOPS_MODFILE..."
        if "$OLLAMA_BIN" create "$DEVOPS_MODEL" -f "$DEVOPS_MODFILE"; then
            echo "✅ $DEVOPS_MODEL created successfully."
            # Verify creation with retry (Ollama may need a moment to register)
            sleep 2
            for attempt in 1 2 3; do
                if "$OLLAMA_BIN" list 2>/dev/null | grep -q "^${DEVOPS_MODEL}[[:space:]:]"; then
                    echo "✅ Verified: $DEVOPS_MODEL is in model list (attempt $attempt)."
                    break
                fi
                if [ $attempt -lt 3 ]; then
                    echo "   Waiting for model to appear in list... (attempt $attempt)"
                    sleep 2
                fi
            done
            if ! "$OLLAMA_BIN" list 2>/dev/null | grep -q "^${DEVOPS_MODEL}[[:space:]:]"; then
                echo "❌ Verification failed: $DEVOPS_MODEL not found after creation."
                echo "   Available models:"
                "$OLLAMA_BIN" list
                exit 1
            fi
        else
            echo "❌ Failed to create $DEVOPS_MODEL"
            echo "   Check log: $OLLAMA_LOG"
            exit 1
        fi
    else
        echo "❌ Modelfile not found: $DEVOPS_MODFILE"
        exit 1
    fi
fi

# --- Phase 6: Preload DevOps model (non-interactive) ---
echo "⏳ Warming up $DEVOPS_MODEL (loading into memory)..."
if echo "hello testing" | "$OLLAMA_BIN" run "$DEVOPS_MODEL" > /dev/null 2>&1; then
    echo "✅ $DEVOPS_MODEL preloaded successfully!"
else
    echo "⚠️  $DEVOPS_MODEL preload failed (model may still be usable)."
fi

# --- Phase 7: Display all models ---
echo ""
echo "Available models:"
"$OLLAMA_BIN" list

# --- Phase 8: API connectivity tests ---
echo "🔍 Testing API connectivity..."
curl -s --fail http://127.0.0.1:11434/api/tags > /dev/null && echo "  IPv4:      OK" || echo "  IPv4:      FAIL"
curl -s --fail http://[::1]:11434/api/tags > /dev/null && echo "  IPv6:      OK" || echo "  IPv6:      FAIL"
curl -s --fail http://localhost:11434/api/tags > /dev/null && echo "  localhost: OK" || echo "  localhost: FAIL"

# --- Phase 9: Start vector DB containers ---
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    echo "🐳 Starting Docker containers..."
    if docker-compose -f "$SCRIPT_DIR/docker-compose.yml" up -d; then
        echo "✅ Docker containers started!"
        echo "   Waiting for qdrant to become healthy..."
        sleep 3
        if docker-compose -f "$SCRIPT_DIR/docker-compose.yml" ps | grep -q "healthy"; then
            echo "✅ Qdrant is healthy."
        else
            echo "⚠️  Qdrant is still starting or unhealthy. Check: docker-compose logs"
        fi
    else
        echo "❌ Failed to start Docker containers. Check: docker-compose config"
        exit 1
    fi
else
    echo "❌ docker-compose.yml not found. Cannot start vector DB."
    exit 1
fi

echo ""
echo "🚀 Ollama local LLM ready for use!"
echo "📊 Model: $DEVOPS_MODEL (based on qwen2.5-coder:14b)"

