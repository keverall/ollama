#!/usr/bin/env bats
# Unit tests for Ollama readiness check loop logic

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
    # Create a basic mock that succeeds by default
    cat > "$TEST_TMPDIR/ollama" <<'MOCK'
#!/bin/bash
if [ "$1" = "list" ]; then
    echo "NAME    ID"
    exit 0
fi
exit 1
MOCK
    chmod +x "$TEST_TMPDIR/ollama"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
    rm -f /tmp/mock_ollama_retry_count
}

@test "Readiness: server responds immediately" {
    export PATH="$TEST_TMPDIR:$PATH"
    run bash -c '
        MAX_RETRIES=5
        RETRY_COUNT=0
        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            if ollama list > /dev/null 2>&1; then
                echo "READY"
                break
            fi
            RETRY_COUNT=$((RETRY_COUNT+1))
            sleep 0.1
        done
        echo "__RETRY_COUNT__=$RETRY_COUNT"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"READY"* ]]
    echo "$output" | grep -q "__RETRY_COUNT__=0"
}

@test "Readiness: server recovers after 2 failures" {
    # Create custom mock that fails first 2 calls, then succeeds
    cat > "$TEST_TMPDIR/ollama" <<'MOCK'
#!/bin/bash
COUNT_FILE="/tmp/mock_ollama_retry_count"
COUNT=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT+1))
echo $COUNT > "$COUNT_FILE"
if [ "$1" = "list" ]; then
    if [ $COUNT -le 2 ]; then
        exit 1
    else
        echo "NAME    ID"
        exit 0
    fi
fi
exit 1
MOCK
    chmod +x "$TEST_TMPDIR/ollama"
    echo "0" > /tmp/mock_ollama_retry_count
    
    export PATH="$TEST_TMPDIR:$PATH"
    run bash -c '
        MAX_RETRIES=5
        RETRY_COUNT=0
        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            if ollama list > /dev/null 2>&1; then
                echo "READY"
                break
            fi
            RETRY_COUNT=$((RETRY_COUNT+1))
            sleep 0.1
        done
        echo "__RETRY_COUNT__=$RETRY_COUNT"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"READY"* ]]
}

@test "Readiness: fails after max retries (timeout)" {
    # Mock always fails
    cat > "$TEST_TMPDIR/ollama" <<'MOCK'
#!/bin/bash
if [ "$1" = "list" ]; then
    exit 1
fi
exit 1
MOCK
    chmod +x "$TEST_TMPDIR/ollama"
    export PATH="$TEST_TMPDIR:$PATH"
    
    run bash -c '
        MAX_RETRIES=3
        RETRY_COUNT=0
        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            if ollama list > /dev/null 2>&1; then
                echo "READY"
                break
            fi
            RETRY_COUNT=$((RETRY_COUNT+1))
            sleep 0.1
        done
        if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            echo "TIMEOUT"
        fi
        echo "__RETRY_COUNT__=$RETRY_COUNT"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"TIMEOUT"* ]]
    echo "$output" | grep -q "__RETRY_COUNT__=3"
}
