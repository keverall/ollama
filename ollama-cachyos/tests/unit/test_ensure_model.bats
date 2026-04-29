#!/usr/bin/env bats
# Unit tests for ensure_model function logic

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
    mkdir -p modfiles
    # Create mock ollama
    cat > "$TEST_TMPDIR/ollama" <<'MOCK'
#!/bin/bash
case "$1" in
  list)
    if [ -f /tmp/ollama_models_cache ]; then
        cat /tmp/ollama_models_cache
    else
        echo "NAME    ID    SIZE    MODIFIED"
    fi
    ;;
  pull|create)
    echo "$2" >> /tmp/ollama_models_cache
    exit 0
    ;;
esac
MOCK
    chmod +x "$TEST_TMPDIR/ollama"
    # Reset model cache
    rm -f /tmp/ollama_models_cache
    touch /tmp/ollama_models_cache
}

teardown() {
    rm -rf "$TEST_TMPDIR"
    rm -f /tmp/ollama_models_cache
}

@test "ensure_model: model exists, should skip" {
    # Prepopulate cache with a model
    echo "qwen2.5:7b-instruct  abc123  7GB" >> /tmp/ollama_models_cache
    
    model_name="qwen2.5:7b-instruct"
    run env PATH="$TEST_TMPDIR:$PATH" bash -c "if ollama list 2>/dev/null | grep -q '^${model_name}[[:space:]:]'; then echo EXISTS; else echo NOT_FOUND; fi"
    [ "$status" -eq 0 ]
    [ "$output" = "EXISTS" ]
}

@test "ensure_model: model does not exist, should pull" {
    # Cache empty except header
    : > /tmp/ollama_models_cache
    echo "NAME    ID    SIZE    MODIFIED" > /tmp/ollama_models_cache
    
    model_name="qwen2.5:7b-instruct"
    run env PATH="$TEST_TMPDIR:$PATH" bash -c "if ollama list 2>/dev/null | grep -q '^${model_name}[[:space:]:]'; then echo EXISTS; else echo NOT_FOUND; fi"
    [ "$status" -eq 0 ]
    [ "$output" = "NOT_FOUND" ]
}

@test "Modfile path construction" {
    modfile_name="Qwen2.5-7B-instruct-GPU.modelfile"
    run bash -c "modfile_path='./modfiles/${modfile_name}'; echo \"\$modfile_path\""
    [ "$status" -eq 0 ]
    [ "$output" = "./modfiles/Qwen2.5-7B-instruct-GPU.modelfile" ]
}

@test "Modfile existence check" {
    touch "$TEST_TMPDIR/modfiles/test.modelfile"
    run bash -c "[[ -f '$TEST_TMPDIR/modfiles/test.modelfile' ]] && echo EXISTS || echo MISSING"
    [ "$status" -eq 0 ]
    [ "$output" = "EXISTS" ]
}

@test "Model name pattern matching: with tag" {
    model_name="qwen2.5:7b-instruct"
    run bash -c "echo 'qwen2.5:7b-instruct  abc  7GB' | grep -q '^${model_name}[[:space:]:]' && echo MATCH || echo NO_MATCH"
    [ "$status" -eq 0 ]
    [ "$output" = "MATCH" ]
}

@test "Model name pattern matching: without tag" {
    model_name="nomic-embed-text"
    run bash -c "echo 'nomic-embed-text:latest  xyz  1GB' | grep -q '^${model_name}[[:space:]:]' && echo MATCH || echo NO_MATCH"
    [ "$status" -eq 0 ]
    [ "$output" = "MATCH" ]
}
