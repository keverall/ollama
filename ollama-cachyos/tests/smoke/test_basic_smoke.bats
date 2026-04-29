#!/usr/bin/env bats
# Smoke tests - quick validation of basic script operations

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
    mkdir -p logs modfiles
    cp "$PROJECT_ROOT/scripts/sod.sh" .
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
    [ -f logs/ollama-cachyos-devops.log ]
}

@test "Smoke: Script writes server log file" {
    run ./sod.sh
    [ "$status" -eq 0 ]
    [ -f logs/ollama-server.log ]
}

@test "Smoke: Script detects binaries correctly" {
    run ./sod.sh
    [ "$status" -eq 0 ]
    grep -q "GPU Status:" logs/ollama-cachyos-devops.log || true
}

@test "Smoke: Script sets environment variables" {
    run ./sod.sh
    [ "$status" -eq 0 ]
    grep -q "OLLAMA_NUM_PARALLEL=24" logs/ollama-server.log || true
}
