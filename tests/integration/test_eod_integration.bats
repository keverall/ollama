#!/usr/bin/env bats
# Integration tests for eod.sh with mocked dependencies

setup() {
    # Ensure PROJECT_ROOT is set for the tests before changing directory
    if [[ -z "${PROJECT_ROOT:-}" ]]; then
        # Hardcode the project root for test environment
        PROJECT_ROOT="/Users/keveverall/vscode/ollama/ollama-devops"
        export PROJECT_ROOT
    fi

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

@test "eod.sh: Stops Docker containers" {
    run "$PROJECT_ROOT/scripts/eod.sh"
    [ "$status" -eq 0 ]
    EOD_LOG=$(ls logs/*-eod-run.log 2>/dev/null | head -1)
    # Matches log with emoji prefix and optional timestamp
    grep -Eq "\[.*\] (🐳 )?Stopping Docker containers" "$EOD_LOG" || \
    grep -q "Stopping Docker containers" "$EOD_LOG" || true
}

@test "eod.sh: Stops Ollama service" {
    run "$PROJECT_ROOT/scripts/eod.sh"
    [ "$status" -eq 0 ]
    EOD_LOG=$(ls logs/*-eod-run.log 2>/dev/null | head -1)
    grep -Eq "\[.*\] (📡 )?Stopping Ollama services" "$EOD_LOG" || \
    grep -q "Stopping Ollama services" "$EOD_LOG" || true
}

@test "eod.sh: Completes shutdown successfully" {
    run "$PROJECT_ROOT/scripts/eod.sh"
    [ "$status" -eq 0 ]
    EOD_LOG=$(ls logs/*-eod-run.log 2>/dev/null | head -1)
    grep -Eq "\[.*\] (✅ )?Environment shutdown complete" "$EOD_LOG" || \
    grep -q "Environment shutdown complete" "$EOD_LOG" || true
}

@test "eod.sh: Exits with 0 on success" {
    run "$PROJECT_ROOT/scripts/eod.sh"
    [ "$status" -eq 0 ]
}
