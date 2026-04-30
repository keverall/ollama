#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
LOG_DIR="${PROJECT_ROOT}/logs"
SCRIPT_NAME="$(basename "$0")"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
mkdir -p "${LOG_DIR}"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
log() {
    local msg="[$TIMESTAMP] $1"
    echo "$msg" | tee -a "${LOG_FILE}"
}
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ERRORS=0

log "=========================================="
log "  Linting ollama-devops Scripts"
log "=========================================="
log ""

# 1. Shellcheck
log "Running shellcheck..."
for script in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    log "  Checking: $(basename "$script")"
    if shellcheck "$script" 2>&1 | tee -a "${LOG_FILE}"; then
        log "    ${GREEN}✓${NC}"
    else
        log "    ${RED}✗ shellcheck failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# 2. Bash syntax check
log ""
log "Checking bash syntax..."
for script in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    if bash -n "$script" 2>&1 | tee -a "${LOG_FILE}"; then
        log "  $(basename "$script"): ${GREEN}✓${NC}"
    else
        log "  $(basename "$script"): ${RED}✗ syntax error${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# 3. Common issues
log ""
log "Checking for common issues..."
for script in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    log "  Analyzing: $(basename "$script")"
    
    # set -e
    if grep -q "^set -e" "$script"; then
        log "    ${GREEN}✓${NC} Uses 'set -e'"
    else
        log "    ${YELLOW}⚠ Missing 'set -e'${NC}"
    fi

    # set -u (in combined set -euo pipefail)
    if grep -qE "^set -[a-z]*u[a-z]* " "$script" || grep -qE "set -o pipefail" "$script"; then
        log "    ${GREEN}✓${NC} Uses 'set -u'"
    else
        log "    ${YELLOW}⚠ Missing 'set -u'${NC}"
    fi

    # set -o pipefail
    if grep -qE '^set [^#]*\bpipefail\b' "$script"; then
        log "    ${GREEN}✓${NC} Uses 'set -o pipefail'"
    else
        log "    ${YELLOW}⚠ Missing 'set -o pipefail'${NC}"
    fi

    # Hardcoded paths (common bad patterns)
    if grep -E '"/home/|/usr/local/bin/ollama|/etc/ollama' "$script" | grep -v "^#" | grep -v "OLLAMA_MODELS"; then
        log "    ${YELLOW}⚠ potential hardcoded path${NC}"
    fi

    # printf vs echo -n
    if grep -q 'echo -n' "$script"; then
        log "    ${YELLOW}⚠ Uses 'echo -n' (consider printf)${NC}"
    fi
done

# 4. Security scan (skip sudo systemctl which is expected)
log ""
log "Quick security scan..."
for script in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    if grep -qE '\b(eval|chmod 777|rm -rf /)\b' "$script"; then
        log "  $(basename "$script"): ${RED}⚠ potentially dangerous command${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# 5. Line endings
log ""
log "Checking line endings..."
for script in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$script" ] || continue
    if file "$script" | grep -q "CRLF"; then
        log "  $(basename "$script"): ${RED}✗ CRLF line endings${NC}"
        ERRORS=$((ERRORS + 1))
    else
        log "  $(basename "$script"): ${GREEN}✓ LF line endings${NC}"
    fi
done

log ""
if [ $ERRORS -eq 0 ]; then
    log "${GREEN}All linting checks passed!${NC}"
    exit 0
else
    log "${RED}$ERRORS issue(s) found${NC}"
    exit 1
fi
