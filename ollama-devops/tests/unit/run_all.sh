#!/bin/bash
set -euo pipefail
TEST_COUNT=0; PASS_COUNT=0; FAIL_COUNT=0
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
run_test() { TEST_COUNT=$((TEST_COUNT+1)); echo -n "  [$TEST_COUNT] $1 ... "; if bats "$2"; then echo -e "${GREEN}PASS${NC}"; PASS_COUNT=$((PASS_COUNT+1)); else echo -e "${RED}FAIL${NC}"; FAIL_COUNT=$((FAIL_COUNT+1)); fi; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TEST_TMPDIR="$(mktemp -d)"
export BATSLIB_TIMEOUT_MULTIPLIER="${BATSLIB_TIMEOUT_MULTIPLIER:-2}"
echo "=========================================="; echo "  ollama-devops Unit Test Suite"; echo "=========================================="; echo ""
for test_file in $(ls "$SCRIPT_DIR/unit"/*.bats 2>/dev/null | sort); do run_test "$(basename "$test_file" .bats)" "$test_file"; done
echo ""; echo "=========================================="; echo "  Results: $PASS_COUNT/$TEST_COUNT passed"; echo "=========================================="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
