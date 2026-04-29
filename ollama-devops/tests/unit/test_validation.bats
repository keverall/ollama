#!/usr/bin/env bats
# Unit tests for dependency validation logic

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "ollama binary detection - found" {
    cat > "$TEST_TMPDIR/ollama" <<'MOCK'
#!/bin/bash
echo "mock ollama"
MOCK
    chmod +x "$TEST_TMPDIR/ollama"
    run bash -c "PATH='$TEST_TMPDIR:\$PATH' command -v ollama"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ollama"* ]]
}

@test "ollama binary detection - not found" {
    mkdir -p "$TEST_TMPDIR/empty"
    run bash -c "PATH='$TEST_TMPDIR/empty' command -v ollama >/dev/null 2>&1 || echo 'not found'"
    [ "$status" -eq 0 ]
    [ "$output" = "not found" ]
}

@test "docker binary detection" {
    if command -v docker &>/dev/null; then
        run command -v docker
        [ "$status" -eq 0 ]
    else
        skip "docker not available"
    fi
}

@test "nvidia-smi detection (may skip if no GPU)" {
    if command -v nvidia-smi &>/dev/null; then
        # Query without looping
        run nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
        [ "$status" -eq 0 ]
    else
        skip "nvidia-smi not available"
    fi
}
