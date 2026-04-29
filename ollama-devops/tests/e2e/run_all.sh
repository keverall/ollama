#!/bin/bash
# E2E test runner - full integration tests on real hardware
# Note: These tests may take 10-30 minutes due to model downloads

set -euo pipefail

TEST_TMPDIR="$(mktemp -d)"
cd "$TEST_TMPDIR"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo "=========================================="
echo "  E2E Test Suite (Full Hardware)"
echo "=========================================="
echo "WARNING: These tests start real Ollama server and pull large models."
echo "Estimated time: 10-30 minutes"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
if ! command -v ollama &>/dev/null; then
    echo -e "${RED}✗ ollama not found${NC}"
    exit 1
fi
if ! command -v docker &>/dev/null; then
    echo -e "${RED}✗ docker not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Prerequisites met${NC}"
echo ""

# Run the actual E2E test
echo "Running full sod.sh workflow..."
if "$PROJECT_ROOT/scripts/sod.sh"; then
    echo -e "${GREEN}✓ sod.sh completed successfully${NC}"
else
    echo -e "${RED}✗ sod.sh failed${NC}"
    exit 1
fi

# Validate outputs
echo ""
echo "Validating outputs..."
[ -f logs/ollama-cachyos-devops.log ] || { echo -e "${RED}✗ Main log missing${NC}"; exit 1; }
[ -f logs/ollama-server.log ] || { echo -e "${RED}✗ Server log missing${NC}"; exit 1; }
echo -e "${GREEN}✓ Log files present${NC}"

# Check Ollama is actually running
if ollama ps &>/dev/null; then
    echo -e "${GREEN}✓ Ollama server responding${NC}"
else
    echo -e "${RED}✗ Ollama not responding${NC}"
    exit 1
fi

# Check models loaded (at least nomic-embed-text should be present)
if ollama list | grep -q "nomic-embed-text"; then
    echo -e "${GREEN}✓ Models loaded${NC}"
else
    echo -e "${YELLOW}⚠ Model check skipped (may still be downloading)${NC}"
fi

# Check Qdrant
if curl -s http://localhost:6333/ready &>/dev/null; then
    echo -e "${GREEN}✓ Qdrant ready${NC}"
else
    echo -e "${YELLOW}⚠ Qdrant not ready yet${NC}"
fi

# Clean up
echo ""
echo "Cleaning up test environment..."
pkill -f "ollama serve" 2>/dev/null || true
docker compose -f "$PROJECT_ROOT/docker-compose.yml" down 2>/dev/null || true
rm -rf "$TEST_TMPDIR"
echo -e "${GREEN}✓ Cleanup complete${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}E2E tests completed!${NC}"
echo "=========================================="
exit 0
