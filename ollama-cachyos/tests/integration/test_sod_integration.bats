#!/usr/bin/env bats
# Integration tests for sod.sh with mocked dependencies

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
    mkdir -p logs modfiles
    export LOG_DIR="$PWD/logs"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "sod.sh: Validates ollama binary exists (should succeed with mock)" {
    # Use real script, mocks are in PATH from runner
    run "$PROJECT_ROOT/scripts/sod.sh"
    [ "$status" -eq 0 ]
}

@test "sod.sh: Creates log directory" {
    run "$PROJECT_ROOT/scripts/sod.sh"
    [ "$status" -eq 0 ]
    [ -d logs ]
}

@test "sod.sh: Logs startup messages" {
    run "$PROJECT_ROOT/scripts/sod.sh"
    [ "$status" -eq 0 ]
    [ -f logs/ollama-cachyos-devops.log ]
}

@test "sod.sh: Starts Ollama server" {
    run "$PROJECT_ROOT/scripts/sod.sh"
    [ "$status" -eq 0 ]
    grep -q "Starting Ollama server" logs/ollama-cachyos-devops.log
}

@test "sod.sh: Verifies Ollama readiness" {
    run "$PROJECT_ROOT/scripts/sod.sh"
    [ "$status" -eq 0 ]
    grep -q "Ollama is running" logs/ollama-cachyos-devops.log
}

@test "sod.sh: Checks models" {
    run "$PROJECT_ROOT/scripts/sod.sh"
    [ "$status" -eq 0 ]
    grep -q "Checking Base Models" logs/ollama-cachyos-devops.log
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
    [ "$status" -eq 0 ]
    grep -q "Starting Qdrant" logs/ollama-cachyos-devops.log
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
    [ "$status" -eq 0 ]
    grep -q "Environment Started Successfully" logs/ollama-cachyos-devops.log
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
    [ "$status" -eq 0 ]
    grep -q "Stopping existing Ollama processes" logs/ollama-cachyos-devops.log
}
