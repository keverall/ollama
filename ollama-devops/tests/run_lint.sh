#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ERRORS=0

echo "=========================================="
echo "  Linting ollama-devops Scripts"
echo "=========================================="
echo ""

# 1. Shellcheck
echo "Running shellcheck..."
for script in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    echo "  Checking: $(basename "$script")"
    if shellcheck "$script"; then
        echo -e "    ${GREEN}✓${NC}"
    else
        echo -e "    ${RED}✗ shellcheck failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# 2. Bash syntax check
echo ""
echo "Checking bash syntax..."
for script in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    if bash -n "$script"; then
        echo -e "  $(basename "$script"): ${GREEN}✓${NC}"
    else
        echo -e "  $(basename "$script"): ${RED}✗ syntax error${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# 3. Common issues
echo ""
echo "Checking for common issues..."
for script in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    echo "  Analyzing: $(basename "$script")"
    
    # set -e
    if grep -q "^set -e" "$script"; then
        echo -e "    ${GREEN}✓${NC} Uses 'set -e'"
    else
        echo -e "    ${YELLOW}⚠ Missing 'set -e'${NC}"
    fi
    
    # set -u (in combined set -euo pipefail)
    if grep -qE "^set -[a-z]*u[a-z]* " "$script" || grep -qE "set -o pipefail" "$script"; then
        echo -e "    ${GREEN}✓${NC} Uses 'set -u'"
    else
        echo -e "    ${YELLOW}⚠ Missing 'set -u'${NC}"
    fi
    
    # set -o pipefail
    if grep -qE '^set [^#]*\bpipefail\b' "$script"; then
        echo -e "    ${GREEN}✓${NC} Uses 'set -o pipefail'"
    else
        echo -e "    ${YELLOW}⚠ Missing 'set -o pipefail'${NC}"
    fi
    
    # Hardcoded paths (common bad patterns)
    if grep -E '"/home/|/usr/local/bin/ollama|/etc/ollama' "$script" | grep -v "^#" | grep -v "OLLAMA_MODELS"; then
        echo -e "    ${YELLOW}⚠ potential hardcoded path${NC}"
    fi
    
    # printf vs echo -n
    if grep -q 'echo -n' "$script"; then
        echo -e "    ${YELLOW}⚠ Uses 'echo -n' (consider printf)${NC}"
    fi
done

# 4. Security scan (skip sudo systemctl which is expected)
echo ""
echo "Quick security scan..."
for script in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    if grep -qE '\b(eval|chmod 777|rm -rf /)\b' "$script"; then
        echo -e "  $(basename "$script"): ${RED}⚠ potentially dangerous command${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# 5. Line endings
echo ""
echo "Checking line endings..."
for script in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    if file "$script" | grep -q "CRLF"; then
        echo -e "  $(basename "$script"): ${RED}✗ CRLF line endings${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "  $(basename "$script"): ${GREEN}✓ LF line endings${NC}"
    fi
done

echo ""
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All linting checks passed!${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS issue(s) found${NC}"
    exit 1
fi
