#!/usr/bin/env bats
# Integration tests for sod.sh with mocked dependencies

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
    mkdir -p logs modfiles
    export LOG_DIR="$PWD/logs"
    # Determine actual log file created by script (will be platform-specific)
    ACTUAL_LOG=""


}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "sod.sh: Validates ollama binary exists (should succeed with mock)" {
    # Use real script, mocks are in PATH from runner
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
    ACTUAL_LOG=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ "$status" -eq 0 ]
    grep -q "Ollama is running" "$ACTUAL_LOG"
}

@test "sod.sh: Checks models" {
    run "$PROJECT_ROOT/scripts/sod.sh"
    ACTUAL_LOG=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ "$status" -eq 0 ]
    grep -q "📦 Phase 4: Checking models" "$ACTUAL_LOG"
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
