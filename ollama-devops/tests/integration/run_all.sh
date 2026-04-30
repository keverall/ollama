#!/bin/bash
set -euo pipefail

TEST_COUNT=0; PASS_COUNT=0; FAIL_COUNT=0
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# Logging setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"
SCRIPT_NAME="$(basename "$0")"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
mkdir -p "${LOG_DIR}"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
log() {
    local msg="[$TIMESTAMP] $1"
    echo "$msg" | tee -a "${LOG_FILE}"
}

run_test() {
    TEST_COUNT=$((TEST_COUNT+1))
    log "  [$TEST_COUNT] $1 ... "
    if timeout 60 bats "$2" 2>&1 | tee -a "${LOG_FILE}"; then
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
