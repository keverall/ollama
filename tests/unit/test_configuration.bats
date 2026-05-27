#!/usr/bin/env bats
# Unit tests for configuration variables and defaults in sod.sh

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
    mkdir -p scriptdir
    cat > scriptdir/sod.sh <<'SCRIPT'
OLLAMA_HOST="${OLLAMA_HOST:-[::]:11434}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_BIN="${OLLAMA_BIN:-ollama}"
OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL:-24}"
OLLAMA_MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS:-2}"
QDRANT_PORT="${QDRANT_PORT:-6333}"
QDRANT_GRPC_PORT="${QDRANT_GRPC_PORT:-6334}"
SCRIPT
    chmod +x scriptdir/sod.sh
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "Default OLLAMA_HOST is [::]:11434 (IPv6+IPv4 dual stack)" {
    run bash -c 'source scriptdir/sod.sh && echo "$OLLAMA_HOST"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"[::]:11434"* ]]
}

@test "Default OLLAMA_PORT is 11434" {
    run bash -c 'source scriptdir/sod.sh && echo "$OLLAMA_PORT"'
    [ "$status" -eq 0 ]
    [ "$output" = "11434" ]
}

@test "Default OLLAMA_BIN is ollama" {
    run bash -c 'source scriptdir/sod.sh && echo "$OLLAMA_BIN"'
    [ "$status" -eq 0 ]
    [ "$output" = "ollama" ]
}

@test "Custom OLLAMA_HOST overrides default" {
    run bash -c 'export OLLAMA_HOST="0.0.0.0:11434"; source scriptdir/sod.sh && echo "$OLLAMA_HOST"'
    [ "$status" -eq 0 ]
    [ "$output" = "0.0.0.0:11434" ]
}

@test "Default OLLAMA_NUM_PARALLEL is 24" {
    run bash -c 'source scriptdir/sod.sh && echo "$OLLAMA_NUM_PARALLEL"'
    [ "$status" -eq 0 ]
    [ "$output" = "24" ]
}

@test "Default OLLAMA_MAX_LOADED_MODELS is 2" {
    run bash -c 'source scriptdir/sod.sh && echo "$OLLAMA_MAX_LOADED_MODELS"'
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "QDRANT_PORT default is 6333" {
    run bash -c 'source scriptdir/sod.sh && echo "$QDRANT_PORT"'
    [ "$status" -eq 0 ]
    [ "$output" = "6333" ]
}

@test "OLLAMA_BIN respects custom path" {
    run bash -c 'export OLLAMA_BIN="/usr/local/bin/ollama"; source scriptdir/sod.sh && echo "$OLLAMA_BIN"'
    [ "$status" -eq 0 ]
    [ "$output" = "/usr/local/bin/ollama" ]
}
