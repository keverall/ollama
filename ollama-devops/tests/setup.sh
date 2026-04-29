#!/bin/bash
set -euo pipefail

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

# Colors (only when interactive)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

echo "=========================================="
echo "  ollama-devops Test Environment Setup"
echo "=========================================="
echo ""

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
    echo "Note: Running without sudo. Some packages may require manual installation."
    SUDO_CMD=""
fi

# Check OS and install dependencies
if command -v apt-get &>/dev/null; then
    echo "Detected Debian/Ubuntu"
    echo "Installing dependencies..."
    $SUDO_CMD apt-get update || true
    $SUDO_CMD apt-get install -y bats shellcheck curl wget || {
        echo -e "${YELLOW}⚠ Some packages could not be installed.${NC}"
        echo "Please install manually: bats, shellcheck"
    }
elif command -v pacman &>/dev/null; then
    echo "Detected Arch/CachyOS"
    echo "Installing dependencies..."
    if [ -n "$SUDO_CMD" ]; then
        $SUDO_CMD pacman -S --needed --noconfirm bats shellcheck || {
            echo -e "${YELLOW}⚠ Some packages could not be installed.${NC}"
            echo "Please install manually: bats, shellcheck"
        }
    else
        echo "Please install manually:"
        echo "  sudo pacman -S --needed bats shellcheck"
    fi
elif command -v brew &>/dev/null; then
    echo "Detected macOS"
    echo "Installing dependencies..."
    brew install bats-core shellcheck || {
        echo -e "${YELLOW}⚠ Some packages could not be installed.${NC}"
    }
else
    echo "Unknown package manager. Please install manually:"
    echo "  - bats (Bash Automated Testing System)"
    echo "  - shellcheck"
fi

# Install mocks if requested
if [ $WITH_MOCKS -eq 1 ]; then
    echo ""
    echo "Installing mock binaries..."
    (cd "$(dirname "${BASH_SOURCE[0]}")" && ./mocks/install.sh) || true
fi

# Create necessary directories
echo ""
echo "Creating test directories..."
mkdir -p logs coverage

# Verify installation
echo ""
echo "Verifying installation..."
BATS_OK=0
SHELLCHECK_OK=0

if command -v bats &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} bats installed"
    BATS_OK=1
else
    echo -e "  ${RED}✗${NC} bats not found"
fi

if command -v shellcheck &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} shellcheck installed"
    SHELLCHECK_OK=1
else
    echo -e "  ${RED}✗${NC} shellcheck not found"
fi

echo ""
if [ $BATS_OK -eq 1 ] && [ $SHELLCHECK_OK -eq 1 ]; then
    echo -e "${GREEN}Setup complete! All dependencies satisfied.${NC}"
else
    echo -e "${YELLOW}Setup incomplete — missing dependencies.${NC}"
    echo "Please install the missing packages above and re-run."
fi

echo ""
echo "Quick start:"
echo "  1. Run lint:   .ollama-devops/tests/run_all.sh --lint"
echo "  2. Run unit:   .ollama-devops/tests/run_all.sh --unit"
echo "  3. Run all:    .ollama-devops/tests/run_all.sh"
echo ""
echo "For E2E tests (full hardware), run separately:"
echo "  ./tests/e2e/run_all.sh"
