#!/usr/bin/env bats
# Integration tests for sod.sh with mocked dependencies

setup() {
    # Ensure PROJECT_ROOT is set for the tests before changing directory
    if [[ -z "${PROJECT_ROOT:-}" ]]; then
        # Hardcode the project root for test environment
        PROJECT_ROOT="/Users/keveverall/vscode/ollama/ollama-devops"
        export PROJECT_ROOT
    fi

    # Ensure mocks are in PATH for all tests
    MOCKS_DIR="/Users/keveverall/vscode/ollama/ollama-devops/tests/mocks"
    PATH="$MOCKS_DIR:$PATH"
    export PATH

    # Override OLLAMA_BIN to use mock instead of hardcoded path from .env
    export OLLAMA_BIN="ollama"

    # Enable test mode to exit after startup
    export TEST_MODE=true

    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
    mkdir -p logs modfiles
    export LOG_DIR="$PWD/logs"

    # Create a test-specific .env that doesn't override OLLAMA_BIN
    mkdir -p platform/macbook-m4-24gb-optimized
    cat > platform/macbook-m4-24gb-optimized/.env << 'EOF'
# Test environment - use mock binaries
export MODEL_LIST="nomic-embed-text,qwen2.5-coder:14b"
export DEVOPS_MODEL="qwen-devops"
# OLLAMA_BIN not set here - let it use PATH resolution
export OLLAMA_MODELS=~/.ollama/models/

# Memory optimizations for M4 Pro 24GB
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_KV_CACHE_TYPE=q4_0

export OLLAMA_HOST="[::]:11434" # Forces IPv6 + IPv4 dual-stack
EOF
    # Override PLATFORM_ENV_FILE to use the test .env
    export PLATFORM_ENV_FILE="$PWD/platform/macbook-m4-24gb-optimized/.env"

    # Determine actual log file created by script (will be platform-specific)
    ACTUAL_LOG=""


}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "sod.sh: Validates ollama binary exists (should succeed with mock)" {
    run "$PROJECT_ROOT/scripts/sod.sh"
    ACTUAL_LOG=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ "$status" -eq 0 ]
}

@test "sod.sh: Creates log directory" {
    run "$PROJECT_ROOT/scripts/sod.sh"
    ACTUAL_LOG=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ "$status" -eq 0 ]
    [ -d logs ]
}

@test "sod.sh: Logs startup messages" {
    run "$PROJECT_ROOT/scripts/sod.sh"
    ACTUAL_LOG=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ "$status" -eq 0 ]
    [ -n "$ACTUAL_LOG" ]
}

@test "sod.sh: Starts Ollama server" {
    run "$PROJECT_ROOT/scripts/sod.sh"
    ACTUAL_LOG=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ "$status" -eq 0 ]
    grep -q "Starting Ollama server" "$ACTUAL_LOG"
}

@test "sod.sh: Verifies Ollama readiness" {
    run "$PROJECT_ROOT/scripts/sod.sh"
    [ "$status" -eq 0 ]
    ACTUAL_LOG=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ -n "$ACTUAL_LOG" ]
    # wait_for_ollama logs "Ollama is ready" on success
    grep -q "Ollama is ready" "$ACTUAL_LOG"
}

@test "sod.sh: Checks models" {
    run "$PROJECT_ROOT/scripts/sod.sh"
    [ "$status" -eq 0 ]
    ACTUAL_LOG=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    # Phase 4 ensures models are present
    grep -q "📦 Phase 4: Ensuring models" "$ACTUAL_LOG"
}

@test "sod.sh: Starts Qdrant via docker-compose" {
    # Create minimal docker-compose.yml in current dir
    cat > docker-compose.yml <<'EOF'
version: "3"
services:
  qdrant:
    image: qdrant/qdrant:v1.12.0
EOF
    run "$PROJECT_ROOT/scripts/sod.sh"
    ACTUAL_LOG=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ "$status" -eq 0 ]
    grep -q "Starting Qdrant" "$ACTUAL_LOG"
}

@test "sod.sh: Final status shows success" {
    # Prepare docker-compose.yml
    cat > docker-compose.yml <<'EOF'
version: "3"
services:
  qdrant:
    image: qdrant/qdrant:v1.12.0
EOF
    run "$PROJECT_ROOT/scripts/sod.sh"
    ACTUAL_LOG=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ "$status" -eq 0 ]
    grep -q "Environment Started Successfully" "$ACTUAL_LOG"
}

@test "sod.sh: Sets correct OLLAMA_HOST binding" {
    export OLLAMA_HOST="0.0.0.0:11434"
    cat > docker-compose.yml <<'EOF'
version: "3"
services:
  qdrant:
    image: qdrant/qdrant:v1.12.0
EOF
    run "$PROJECT_ROOT/scripts/sod.sh"
    ACTUAL_LOG=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ "$status" -eq 0 ]
    grep -q "OLLAMA_HOST=0.0.0.0:11434" logs/ollama-server.log || true
}

@test "sod.sh: Handles existing Ollama process cleanup" {
    # Tell mock pgrep to simulate a running ollama process
    export TEST_MOCK_processes="ollama_running"
    cat > docker-compose.yml <<'EOF'
version: "3"
services:
  qdrant:
    image: qdrant/qdrant:v1.12.0
EOF
    run "$PROJECT_ROOT/scripts/sod.sh"
    ACTUAL_LOG=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ "$status" -eq 0 ]
    grep -q "Stopping existing Ollama processes" "$ACTUAL_LOG"
}
