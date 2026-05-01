#!/bin/bash
# Generate test coverage report using bashcov

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COVERAGE_DIR="${PROJECT_ROOT}/coverage"

# shellcheck disable=SC2034
LOG_DIR="${PROJECT_ROOT}/logs"  # Used by lib_logging.sh sourced below

# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib_logging.sh"
log_init "$(basename "${BASH_SOURCE[0]}" .sh)" "coverage" "$PLATFORM"

log "Generating test coverage report..."

# Ensure user gem bin is in PATH (for bashcov)
if [ -d "$HOME/.local/share/gem/ruby/3.4.0/bin" ]; then
    export PATH="$HOME/.local/share/gem/ruby/3.4.0/bin:$PATH"
fi

# Check for bashcov
if ! command -v bashcov &>/dev/null; then
    log "Installing bashcov..."
    if command -v gem &>/dev/null; then
        gem install bashcov || true
    fi
    if ! command -v bashcov &>/dev/null; then
        log "Error: bashcov not found. Install with: gem install bashcov"
        exit 1
    fi
fi

# Clean previous coverage (in project root)
rm -rf "$COVERAGE_DIR"
mkdir -p "$COVERAGE_DIR"

log "Running tests with coverage from project root..."
# Export project root for tests that need it
export PROJECT_ROOT

# Change to project root so bashcov writes coverage/ there (not tests/coverage/)
cd "$PROJECT_ROOT"

# Run the full test suite (unit, integration, smoke, lint) under bashcov
# Use --all to include integration tests which exercise the real scripts
COVERAGE_DIR="$COVERAGE_DIR" bashcov --root "$PROJECT_ROOT" -- "$PROJECT_ROOT/tests/run_all.sh" --all "$@" 2>&1 | tee -a "${LOG_FILE}" || true

log ""
log "Coverage report generated at: $COVERAGE_DIR/index.html"
log "Open in browser: file://$COVERAGE_DIR/index.html"
