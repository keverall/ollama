#!/bin/bash

# Ollama Model Startup Script for MacBook M4 Pro 24GB
# This script starts Ollama and all related services

echo " Starting Ollama and related services..."

# Start Ollama via Homebrew service
if ! pgrep -x "ollama" > /dev/null; then
    echo "📡 Starting Ollama via brew services..."
    brew services start ollama
    sleep 3  # Give Ollama time to start via brew service
fi

echo "✅ qwen2.5-coder:14b-devops preloaded with test query!"

if ollama run qwen2.5-coder:14b-devops "test"; then
    echo " qwen2.5-coder:14b-devops Executed Successfully"
else
    echo " qwen2.5-coder:14b-devops Command Failed"
fi
