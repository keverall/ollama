#!/bin/bash
set -euo pipefail

# shellcheck disable=SC2034
TEST_TMPDIR=""  # Reserved for future use
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC2034
LOG_DIR="${PROJECT_ROOT}/logs"  # Used by lib_logging.sh sourced below

# Shared logging library
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib_logging.sh"
log_init "$(basename "${BASH_SOURCE[0]}" .sh)" "setup" "$PLATFORM"

# Colors (only when interactive). YELLOW and BLUE may be unused in non-interactive mode.
# shellcheck disable=SC2034
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi
# shellcheck disable=SC2034
QUICK=0
WITH_MOCKS=0
SKIP_SUDO=0

for arg in "$@"; do
    case "$arg" in
        --quick) QUICK=1 ;;
        --with-mocks) WITH_MOCKS=1 ;;
        --skip-sudo) SKIP_SUDO=1 ;;
    esac
done

# Mark QUICK as intentionally read to satisfy shellcheck (reserved for future)
: "${QUICK}"

log "=========================================="
log "  ollama-devops Test Environment Setup"
log "=========================================="
log ""

needs_sudo() {
    if [ $SKIP_SUDO -eq 1 ]; then return 1; fi
    if [[ $EUID -eq 0 ]]; then return 1; fi
    if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        return 0
    fi
    return 1
}

SUDO_CMD=""
if needs_sudo; then
    SUDO_CMD="sudo"
else
    log "Note: Running without sudo. Some packages may require manual installation."
    SUDO_CMD=""
fi

# Check OS and install dependencies
if command -v apt-get &>/dev/null; then
    log "Detected Debian/Ubuntu"
    log "Installing dependencies..."
    $SUDO_CMD apt-get update || true
    $SUDO_CMD apt-get install -y bats shellcheck curl wget || {
        log "${YELLOW}⚠ Some packages could not be installed.${NC}"
        log "Please install manually: bats, shellcheck"
    }
elif command -v pacman &>/dev/null; then
    log "Detected Arch/CachyOS"
    log "Installing dependencies..."
    if [ -n "$SUDO_CMD" ]; then
        $SUDO_CMD pacman -S --needed --noconfirm bats shellcheck || {
            log "${YELLOW}⚠ Some packages could not be installed.${NC}"
            log "Please install manually: bats, shellcheck"
        }
    else
        log "Please install manually:"
        log "  sudo pacman -S --needed bats shellcheck"
    fi
elif command -v brew &>/dev/null; then
    log "Detected macOS"
    log "Installing dependencies..."
    brew install bats-core shellcheck || {
        log "${YELLOW}⚠ Some packages could not be installed.${NC}"
    }
else
    log "Unknown package manager. Please install manually:"
    log "  - bats (Bash Automated Testing System)"
    log "  - shellcheck"
fi

# Install mocks if requested
if [ $WITH_MOCKS -eq 1 ]; then
    log ""
    log "Installing mock binaries..."
    (cd "$(dirname "${BASH_SOURCE[0]}")" && ./mocks/install.sh) || true
fi

# Create necessary directories
log ""
log "Creating test directories..."
mkdir -p logs coverage

# Verify installation
log ""
log "Verifying installation..."
BATS_OK=0
SHELLCHECK_OK=0

if command -v bats &>/dev/null; then
    log "  ${GREEN}✓${NC} bats installed"
    BATS_OK=1
else
    log "  ${RED}✗${NC} bats not found"
fi

if command -v shellcheck &>/dev/null; then
    log "  ${GREEN}✓${NC} shellcheck installed"
    SHELLCHECK_OK=1
else
    log "  ${RED}✗${NC} shellcheck not found"
fi

log ""
if [ $BATS_OK -eq 1 ] && [ $SHELLCHECK_OK -eq 1 ]; then
    log "${GREEN}Setup complete! All dependencies satisfied.${NC}"
else
    log "${YELLOW}Setup incomplete — missing dependencies.${NC}"
    log "Please install the missing packages above and re-run."
fi

log ""
log "Quick start:"
log "  1. Run lint:   ./ollama-devops/tests/run_all.sh --lint"
log "  2. Run unit:   ./ollama-devops/tests/run_all.sh --unit"
log "  3. Run all:    ./ollama-devops/tests/run_all.sh"
log ""
log "For E2E tests (full hardware), run separately:"
log "  ./ollama-devops/tests/e2e/run_all.sh"
