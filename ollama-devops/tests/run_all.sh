#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors (only when interactive)
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

# Parse arguments
RUN_SMOKE=0; RUN_UNIT=0; RUN_INTEGRATION=0; RUN_LINT=0; RUN_E2E=0
if [ $# -eq 0 ]; then
    RUN_SMOKE=1; RUN_UNIT=1; RUN_INTEGRATION=0; RUN_LINT=1
else
    for arg in "$@"; do
        case "$arg" in
            --smoke) RUN_SMOKE=1 ;;
            --unit) RUN_UNIT=1 ;;
            --integration) RUN_INTEGRATION=1 ;;
            --lint) RUN_LINT=1 ;;
            --all) RUN_SMOKE=1; RUN_UNIT=1; RUN_INTEGRATION=1; RUN_LINT=1; RUN_E2E=1 ;;
            *) echo "Unknown argument: $arg"; exit 1 ;;
        esac
    done
fi

ERRORS=0
export PROJECT_ROOT

echo "=========================================="
echo "  ollama-devops Full Test Suite"
echo "=========================================="
echo "Project root: $PROJECT_ROOT"
echo ""

# Run lint
if [ $RUN_LINT -eq 1 ]; then
    echo "=== Linting ==="
    if "$SCRIPT_DIR/run_lint.sh"; then
        echo -e "${GREEN}✓ Linting passed${NC}"
    else
        echo -e "${RED}✗ Linting failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    echo ""
fi

# Run unit tests
if [ $RUN_UNIT -eq 1 ]; then
    echo "=== Unit Tests ==="
    if "$SCRIPT_DIR/unit/run_all.sh"; then
        echo -e "${GREEN}✓ Unit tests passed${NC}"
    else
        echo -e "${RED}✗ Unit tests failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    echo ""
fi

# Run integration tests
if [ $RUN_INTEGRATION -eq 1 ]; then
    echo "=== Integration Tests ==="
    if "$SCRIPT_DIR/integration/run_all.sh"; then
        echo -e "${GREEN}✓ Integration tests passed${NC}"
    else
        echo -e "${RED}✗ Integration tests failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    echo ""
fi

# Run smoke tests
if [ $RUN_SMOKE -eq 1 ]; then
    echo "=== Smoke Tests ==="
    if "$SCRIPT_DIR/smoke/run_all.sh"; then
        echo -e "${GREEN}✓ Smoke tests passed${NC}"
    else
        echo -e "${RED}✗ Smoke tests failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    echo ""
fi

if [ $ERRORS -eq 0 ]; then
    echo "=========================================="
    echo -e "${GREEN}All requested tests passed!${NC}"
    echo "=========================================="
    exit 0
else
    echo "=========================================="
    echo -e "${RED}$ERRORS test suite(s) failed${NC}"
    echo "=========================================="
    exit 1
fi
