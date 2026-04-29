#!/bin/bash
# Generate test coverage report using kcov

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COVERAGE_DIR="$SCRIPT_DIR/coverage"
KCOV_DIR="${KCOV_DIR:-/usr/local/bin/kcov}"

echo "Generating test coverage report..."

# Check for kcov
if ! command -v kcov &>/dev/null; then
    echo "Installing kcov..."
    # Try cargo (Rust)
    if command -v cargo &>/dev/null; then
        cargo install kcov || true
    else
        echo "Error: kcov not found. Install with: cargo install kcov"
        exit 1
    fi
fi

# Clean previous coverage
rm -rf "$COVERAGE_DIR"
mkdir -p "$COVERAGE_DIR"

echo "Running tests with coverage..."
# Run all unit tests with coverage
cd "$PROJECT_ROOT"
for test in $(find tests/unit -name "*.sh" -not -name "run_all.sh"); do
    echo "  Instrumenting: $(basename "$test")"
    "$KCOV_DIR" --include-path="$PROJECT_ROOT/scripts" \
                 --exclude-path="$PROJECT_ROOT/tests" \
                 "$COVERAGE_DIR/$(basename "$test" .sh)" \
                 bats "$test"
done

echo ""
echo "Coverage report generated at: $COVERAGE_DIR/index.html"
echo "Open in browser: file://$COVERAGE_DIR/index.html"
