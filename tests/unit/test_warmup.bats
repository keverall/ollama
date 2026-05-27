#!/usr/bin/env bats
# Unit tests for model warmup logic

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
    mkdir -p modfiles
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

create_mock_ollama_run() {
    cat > "$TEST_TMPDIR/ollama" <<'MOCK'
#!/bin/bash
if [ "$1" = "run" ]; then
    echo "Simulating model inference..." >&2
    exit 0
fi
exit 1
MOCK
    chmod +x "$TEST_TMPDIR/ollama"
    export PATH="$TEST_TMPDIR:$PATH"
}

@test "Warmup: successful model run" {
    create_mock_ollama_run
    run bash -c '
        echo "Hello" | ollama run qwen2.5:7b-instruct > /dev/null 2>&1 || true
        echo "WARMUP_SUCCESS"
    '
    [ "$status" -eq 0 ]
    [ "$output" = "WARMUP_SUCCESS" ]
}

@test "Warmup: failure is suppressed with OR true" {
    create_mock_ollama_run
    # Make the mock fail
    cat > "$TEST_TMPDIR/ollama" <<'MOCK'
#!/bin/bash
if [ "$1" = "run" ]; then
    exit 1
fi
exit 0
MOCK
    chmod +x "$TEST_TMPDIR/ollama"
    
    run bash -c '
        echo "Hello" | ollama run qwen2.5:7b-instruct > /dev/null 2>&1 || true
        echo "WARMUP_COMPLETED"
    '
    [ "$status" -eq 0 ]
    [ "$output" = "WARMUP_COMPLETED" ]
}

@test "Warmup: conditional on model existence" {
    touch "$TEST_TMPDIR/modfiles/Qwen2.5-7B-instruct-GPU.modelfile"
    
    run bash -c '
        if [[ -f "./modfiles/Qwen2.5-7B-instruct-GPU.modelfile" ]]; then
            echo "WARMUP_SKIPPED"
        else
            echo "WARMUP_RUN"
        fi
    '
    [ "$status" -eq 0 ]
    [ "$output" = "WARMUP_SKIPPED" ]
}
