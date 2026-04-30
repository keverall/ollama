#!/bin/bash
set -euo pipefail

TEST_COUNT=0; PASS_COUNT=0; FAIL_COUNT=0
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

# Logging setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"

# Initialize shared logging
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib_logging.sh"
log_init "$(basename "${BASH_SOURCE[0]}" .sh)" "test" "$PLATFORM"

run_test() {
    TEST_COUNT=$((TEST_COUNT+1))
    log "  [$TEST_COUNT] $1 ... "
    if timeout 30 bats "$2" 2>&1 | tee -a "${LOG_FILE}"; then
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
log "  Smoke Test Suite"
log "=========================================="
log ""

for f in $(find "$TEST_DIR/smoke" -name "*.bats" | sort); do
    run_test "$(basename "$f" .bats)" "$f"
done

log ""; log "=========================================="
log "  Results: $PASS_COUNT/$TEST_COUNT passed"
log "=========================================="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
