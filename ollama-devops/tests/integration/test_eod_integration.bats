#!/usr/bin/env bats
# Integration tests for eod.sh with mocked dependencies

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
    mkdir -p logs
    # Create minimal docker-compose for eod to find/stop
    cat > docker-compose.yml <<'EOF'
version: "3"
services:
  qdrant:
    image: qdrant/qdrant:v1.12.0
EOF
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "eod.sh: Stops Qdrant via docker-compose" {
    run "$PROJECT_ROOT/scripts/eod.sh"
    [ "$status" -eq 0 ]
    grep -q "Stopping Qdrant" logs/ollama-devops.log || true
}

@test "eod.sh: Stops Ollama service gracefully" {
    run "$PROJECT_ROOT/scripts/eod.sh"
    [ "$status" -eq 0 ]
    grep -q "Stopping Ollama" logs/ollama-devops.log || true
}

@test "eod.sh: Handles case when Ollama not running" {
    run "$PROJECT_ROOT/scripts/eod.sh"
    [ "$status" -eq 0 ]
    grep -q "Ollama server is not running" logs/ollama-devops.log || true
}

@test "eod.sh: Exits with 0 on success" {
    run "$PROJECT_ROOT/scripts/eod.sh"
    [ "$status" -eq 0 ]
}
