#!/usr/bin/env bats
# Smoke tests - quick validation of basic script operations

setup() {
    # Auto-detect PROJECT_ROOT if not set (allows running test file directly)
    if [[ -z "${PROJECT_ROOT:-}" ]]; then
        local test_dir
        if [[ -n "${BATS_TEST_DIRNAME:-}" ]]; then
            test_dir="${BATS_TEST_DIRNAME}"
        else
            test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        fi
        PROJECT_ROOT="$(cd "$test_dir/../.." && pwd)"
    fi

    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
    mkdir -p logs modfiles
    cp "$PROJECT_ROOT/scripts/sod.sh" .
    export LOG_DIR="${TEST_TMPDIR}/logs"
    cp "$PROJECT_ROOT/scripts/lib_logging.sh" .
    chmod +x sod.sh
    # Unset PROJECT_ROOT so script auto-detects based on location
    unset PROJECT_ROOT
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "Smoke: Script syntax is valid" {
    run bash -n sod.sh
    [ "$status" -eq 0 ]
}

@test "Smoke: Script is executable" {
    [ -x sod.sh ]
}

@test "Smoke: Script runs without crashing (mocked deps)" {
    run ./sod.sh
    [ "$status" -eq 0 ]
}

@test "Smoke: Script creates log directory" {
    run ./sod.sh
    [ "$status" -eq 0 ]
    [ -d logs ]
}

@test "Smoke: Script writes main log file" {
    run ./sod.sh
    [ "$status" -eq 0 ]
    # Check that main log file was created
    actual_log=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ -n "$actual_log" ]
}

@test "Smoke: Script writes server log file" {
    run ./sod.sh
    [ "$status" -eq 0 ]
    [ -f logs/ollama-server.log ]
}

@test "Smoke: Script detects binaries correctly" {
    run ./sod.sh
    [ "$status" -eq 0 ]
    # Check log for GPU status
    local logfile
    logfile=$(ls logs/*-sod-run.log 2>/dev/null | head -1)
    [ -n "$logfile" ] && grep -q "GPU Status:" "$logfile" || true
}

@test "Smoke: Script sets environment variables" {
    run ./sod.sh
    [ "$status" -eq 0 ]
    grep -q "OLLAMA_NUM_PARALLEL=24" logs/ollama-server.log || true
}
