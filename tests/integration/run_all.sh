#!/bin/bash
set -euo pipefail

TEST_COUNT=0; PASS_COUNT=0; FAIL_COUNT=0
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# Logging setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"

# Initialize shared logging
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib_logging.sh"
log_init "$(basename "${BASH_SOURCE[0]}" .sh)" "test" "$PLATFORM"

run_with_timeout() {
    local timeout_seconds=$1
    shift
    if command -v timeout &>/dev/null; then
        timeout "$timeout_seconds" "$@" 2>&1
        return $?
    elif command -v gtimeout &>/dev/null; then
        gtimeout "$timeout_seconds" "$@" 2>&1
        return $?
    else
        # Simple fallback timeout using background process and signals
        local start_time
        start_time=$(date +%s)
        "$@" 2>&1 &
        local cmd_pid=$!

        # Wait for command with timeout
        local elapsed=0
        while [[ $elapsed -lt $timeout_seconds ]]; do
            if ! kill -0 "$cmd_pid" 2>/dev/null; then
                # Process finished
                wait "$cmd_pid" 2>/dev/null
                return $?
            fi
            sleep 1
            elapsed=$((elapsed + 1))
        done

        # Timeout reached - kill the process
        kill -TERM "$cmd_pid" 2>/dev/null || kill -KILL "$cmd_pid" 2>/dev/null || true
        wait "$cmd_pid" 2>/dev/null || true
        return 124  # timeout exit code
    fi
}

run_test() {
    TEST_COUNT=$((TEST_COUNT+1))
    log "  [$TEST_COUNT] $1 ... "
    if run_with_timeout 1200 bats "$2" 2>&1 | tee -a "${LOG_FILE}"; then
        log "${GREEN}PASS${NC}"; PASS_COUNT=$((PASS_COUNT+1))
    else
        log "${RED}FAIL${NC}"; FAIL_COUNT=$((FAIL_COUNT+1))
    fi
}

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOCKS_DIR="$TEST_DIR/mocks"

if [ ! -x "$MOCKS_DIR/ollama" ] || [ ! -x "$MOCKS_DIR/docker" ]; then
    log "Installing mock binaries..."
    (cd "$MOCKS_DIR" && ./install.sh 2>&1 | tee -a "${LOG_FILE}")
fi

PATH="$MOCKS_DIR:$PATH"
export PATH; export PROJECT_ROOT

log "=========================================="
log "  ollama-devops Integration Test Suite"
log "=========================================="
log ""

for test_file in $(find "$TEST_DIR/integration" -name "*.bats" | sort); do
    test_name="$(basename "$test_file" .bats)"
    run_test "$test_name" "$test_file"
done

log ""; log "=========================================="
log "  Results: $PASS_COUNT/$TEST_COUNT passed"
log "=========================================="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
