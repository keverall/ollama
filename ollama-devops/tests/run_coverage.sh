#!/bin/bash
# Generate test coverage report using kcov

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COVERAGE_DIR="$SCRIPT_DIR/coverage"
KCOV_DIR="${KCOV_DIR:-/usr/local/bin/kcov}"

# shellcheck disable=SC2034
LOG_DIR="${PROJECT_ROOT}/logs"  # Used by lib_logging.sh sourced below

# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib_logging.sh"
log_init "$(basename "${BASH_SOURCE[0]}" .sh)" "coverage" "$PLATFORM"

log "Generating test coverage report..."

# Check for kcov
if ! command -v kcov &>/dev/null; then
    log "Installing kcov..."
    # Try cargo (Rust)
    if command -v cargo &>/dev/null; then
        cargo install kcov || true
    else
        log "Error: kcov not found. Install with: cargo install kcov"
        exit 1
    fi
fi

# Clean previous coverage
rm -rf "$COVERAGE_DIR"
mkdir -p "$COVERAGE_DIR"

log "Running tests with coverage..."
# Run all unit tests with coverage
cd "$PROJECT_ROOT"
# Use while-read loop for robust handling of filenames with spaces
find tests/unit -name "*.sh" -not -name "run_all.sh" -print0 | while IFS= read -r -d '' test; do
    log "  Instrumenting: $(basename "$test")"
    "$KCOV_DIR" --include-path="$PROJECT_ROOT/scripts" \
                 --exclude-path="$PROJECT_ROOT/tests" \
                 "$COVERAGE_DIR/$(basename "$test" .sh)" \
                 bats "$test"
done

log ""
log "Coverage report generated at: $COVERAGE_DIR/index.html"
log "Open in browser: file://$COVERAGE_DIR/index.html"
