#!/bin/bash
set -euo pipefail

TEST_COUNT=0; PASS_COUNT=0; FAIL_COUNT=0
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

run_test() {
    TEST_COUNT=$((TEST_COUNT+1))
    echo -n "  [$TEST_COUNT] $1 ... "
    if timeout 60 bats "$2"; then
        echo -e "${GREEN}PASS${NC}"; PASS_COUNT=$((PASS_COUNT+1))
    else
        echo -e "${RED}FAIL${NC}"; FAIL_COUNT=$((FAIL_COUNT+1))
    fi
}

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
MOCKS_DIR="$TEST_DIR/mocks"

if [ ! -x "$MOCKS_DIR/ollama" ] || [ ! -x "$MOCKS_DIR/docker" ]; then
    echo "Installing mock binaries..."
    (cd "$MOCKS_DIR" && ./install.sh)
fi

PATH="$MOCKS_DIR:$PATH"
export PATH; export PROJECT_ROOT
mkdir -p "$TEST_DIR/logs"

echo "=========================================="
echo "  ollama-devops Integration Test Suite"
echo "=========================================="
echo ""

for test_file in $(find "$TEST_DIR/integration" -name "*.bats" | sort); do
    test_name="$(basename "$test_file" .bats)"
    run_test "$test_name" "$test_file"
done

echo ""; echo "=========================================="
echo "  Results: $PASS_COUNT/$TEST_COUNT passed"
echo "=========================================="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
