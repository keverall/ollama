#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC2034
LOG_DIR="${PROJECT_ROOT}/logs"  # Passed to lib_logging.sh via environment
# Initialize logging
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib_logging.sh"
log_init "$(basename "${BASH_SOURCE[0]}" .sh)" "test" "$PLATFORM"

# Colors (only when interactive). YELLOW and BLUE may be unused in non-interactive mode.
# shellcheck disable=SC2034
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi
# shellcheck disable=SC2034

# Parse arguments
# shellcheck disable=SC2034
RUN_SMOKE=0 RUN_UNIT=0 RUN_INTEGRATION=0 RUN_LINT=0 RUN_E2E=0
if [ $# -eq 0 ]; then
    RUN_SMOKE=1; RUN_UNIT=1; RUN_INTEGRATION=0; RUN_LINT=1
else
    for arg in "$@"; do
        case "$arg" in
            --smoke) RUN_SMOKE=1 ;;
            --unit) RUN_UNIT=1 ;;
            --integration) RUN_INTEGRATION=1 ;;
            --lint) RUN_LINT=1 ;;
            --all) RUN_SMOKE=1; RUN_UNIT=1; RUN_INTEGRATION=1; RUN_LINT=1; RUN_E2E=1 ;;  # E2E reserved
            *) echo "Unknown argument: $arg"; exit 1 ;;
        esac
    done
fi

# Mark RUN_E2E as intentionally read to satisfy shellcheck (reserved for future)
: "${RUN_E2E}"

ERRORS=0
export PROJECT_ROOT

log "=========================================="
log "  ollama-devops Full Test Suite"
log "=========================================="
log "Project root: $PROJECT_ROOT"
log ""

# Run lint
if [ $RUN_LINT -eq 1 ]; then
    log "=== Linting ==="
    if "$SCRIPT_DIR/run_lint.sh" 2>&1 | tee -a "${LOG_FILE}"; then
        log "${GREEN}✓ Linting passed${NC}"
    else
        log "${RED}✗ Linting failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    log ""
fi

# Run unit tests
if [ $RUN_UNIT -eq 1 ]; then
    log "=== Unit Tests ==="
    if "$SCRIPT_DIR/unit/run_all.sh" 2>&1 | tee -a "${LOG_FILE}"; then
        log "${GREEN}✓ Unit tests passed${NC}"
    else
        log "${RED}✗ Unit tests failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    log ""
fi

# Run integration tests
if [ $RUN_INTEGRATION -eq 1 ]; then
    log "=== Integration Tests ==="
    if "$SCRIPT_DIR/integration/run_all.sh" 2>&1 | tee -a "${LOG_FILE}"; then
        log "${GREEN}✓ Integration tests passed${NC}"
    else
        log "${RED}✗ Integration tests failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    log ""
fi

# Run smoke tests
if [ $RUN_SMOKE -eq 1 ]; then
    log "=== Smoke Tests ==="
    if "$SCRIPT_DIR/smoke/run_all.sh" 2>&1 | tee -a "${LOG_FILE}"; then
        log "${GREEN}✓ Smoke tests passed${NC}"
    else
        log "${RED}✗ Smoke tests failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    log ""
fi

if [ $ERRORS -eq 0 ]; then
    log "=========================================="
    log "${GREEN}All requested tests passed!${NC}"
    log "=========================================="
    exit 0
else
    log "=========================================="
    log "${RED}$ERRORS test suite(s) failed${NC}"
    log "=========================================="
    exit 1
fi
