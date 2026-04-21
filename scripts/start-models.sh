#!/bin/bash

# Ollama Model Startup Script for MacBook M4 Pro 24GB
# This script ensures Ollama is running and both models are available
#
# IMPORTANT: On Mac, use 'brew services start ollama' for background startup
# Using 'ollama serve &' directly can cause conflicts with Homebrew service

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Starting Ollama..."

# Check if Ollama is already running via Homebrew service
if ! ollama list; then
    echo "📡 Starting Ollama via brew services..."
    brew services start ollama
    sleep 3  # Give Ollama time to start via brew service
else 
    echo "✅ Ollama is already running."
fi

echo "✅ Ollama is running..."

# Pull the embedding model if not already present
if ! ollama list | grep -q "nomic-embed-text"; then
    echo "📥 Pulling nomic-embed-text..."
    ollama pull nomic-embed-text
fi

# Pull qwen2.5-coder:14b if not already present
if ! ollama list | grep -q "qwen2.5-coder:14b"; then
    echo "📥 Pulling qwen2.5-coder:14b..."
    ollama pull qwen2.5-coder:14b
fi

# Pull qwen3.6 - latest Agentic Coding model (released April 2026)
if ! ollama list | grep -q "qwen3.6"; then
    echo "📥 Pulling qwen3.6 (latest agentic coding model)..."
    ollama pull qwen3.6
fi

# Pull phi4 - best reasoning model
if ! ollama list | grep -q "phi4"; then
    echo "📥 Pulling phi4 (best reasoning model)..."
    ollama pull phi4
fi

# Create the custom devops model from the qwen Modelfile if it doesn't exist
if ! ollama list | grep -q "qwen2.5-coder:14b-devops"; then
    echo "🏗️ Creating qwen2.5-coder:14b-devops from Modelfile..."
    ollama create qwen2.5-coder:14b-devops -f /Users/keveverall/vscode/ollama/modfile-qwen
fi

# Create custom DevOps model from phi4 using the phi4 Modelfile
if ! ollama list | grep -q "phi4-devops"; then
    echo "🏗️ Creating phi4-devops from Modelfile..."
    ollama create phi4-devops -f /Users/keveverall/vscode/ollama/modfile-phi4
fi

echo "✅ All models ready!"
echo ""
echo "Available models:"
ollama list

if docker-compose -f docker-compose.yml up -d; then
    echo "✅ Docker containers started successfully!"
else
    echo "❌ Failed to start Docker containers. Please check the logs for details."
fi  
echo "🚀 Docker qdrant vector DB containers started!"

# preload "qwen2.5-coder:14b-devops"
echo "⏳ Preloading qwen2.5-coder:14b-devops with a test query..."
# shellcheck disable=SC1091
source "$SCRIPT_DIR/SOD-start-models.sh"
