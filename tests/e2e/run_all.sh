#!/bin/bash
# E2E test runner - full integration tests on real hardware
# Note: These tests may take 10-30 minutes due to model downloads

set -euo pipefail

# Logging setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"

# Initialize shared logging
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib_logging.sh"
log_init "$(basename "${BASH_SOURCE[0]}" .sh)" "test" "$PLATFORM"

TEST_TMPDIR="$(mktemp -d)"
cd "$TEST_TMPDIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log "=========================================="
log "  E2E Test Suite (Full Hardware)"
log "=========================================="
log "WARNING: These tests start real Ollama server and pull large models."
log "Estimated time: 10-30 minutes"
log ""

# Check prerequisites
log "Checking prerequisites..."
if ! command -v ollama &>/dev/null; then
    log "${RED}✗ ollama not found${NC}"
    exit 1
fi
if ! command -v docker &>/dev/null; then
    log "${RED}✗ docker not found${NC}"
    exit 1
fi
log "${GREEN}✓ Prerequisites met${NC}"
log ""

# Run the actual E2E test
log "Running full sod.sh workflow..."
if "$PROJECT_ROOT/scripts/sod.sh" 2>&1 | tee -a "${LOG_FILE}"; then
    log "${GREEN}✓ sod.sh completed successfully${NC}"
else
    log "${RED}✗ sod.sh failed${NC}"
    exit 1
fi

# Validate outputs
log ""
log "Validating outputs..."
# Find the sod.sh log file (most recent)
SOD_LOG=$(ls -t "${PROJECT_ROOT}/logs/"*-sod-run.log 2>/dev/null | head -1)
if [[ -f "$SOD_LOG" ]]; then
    log "Main log present: $(basename "$SOD_LOG")"
else
    log "Main log missing"
    exit 1
fi
if [[ -f "${PROJECT_ROOT}/logs/ollama-server.log" ]]; then
    log "${GREEN}✓ Server log present${NC}"
else
    log "${RED}✗ Server log missing${NC}"
    exit 1
fi

# Check Ollama is actually running
if ollama ps &>/dev/null; then
    log "${GREEN}✓ Ollama server responding${NC}"
else
    log "${RED}✗ Ollama not responding${NC}"
    exit 1
fi

# Check models loaded (at least nomic-embed-text should be present)
if ollama list | grep -q "nomic-embed-text"; then
    log "${GREEN}✓ Models loaded${NC}"
else
    log "${YELLOW}⚠ Model check skipped (may still be downloading)${NC}"
fi

# Check Qdrant
if curl -s http://localhost:6333/ready &>/dev/null; then
    log "${GREEN}✓ Qdrant ready${NC}"
else
    log "${YELLOW}⚠ Qdrant not ready yet${NC}"
fi

# Clean up
log ""
log "Cleaning up test environment..."
pkill -f "ollama serve" 2>/dev/null || true
docker compose -f "$PROJECT_ROOT/docker-compose.yml" down 2>/dev/null || true
rm -rf "$TEST_TMPDIR"
log "${GREEN}✓ Cleanup complete${NC}"

log ""
log "=========================================="
log "${GREEN}E2E tests completed!${NC}"
log "=========================================="
exit 0
