#!/bin/bash

# Ollama Model Shutdown Script for MacBook M4 Pro 24GB
# This script stops Ollama and all related services

echo "🛑 Stopping Ollama and related services..."

# Stop Ollama via Homebrew service
if pgrep -x "ollama" > /dev/null; then
    echo "📡 Stopping Ollama via brew services..."
    brew services stop ollama
fi

echo "✅ Ollama and related services stopped!"
