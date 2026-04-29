#!/bin/bash
set -euo pipefail
MOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Installing mock binaries from $MOCK_DIR..."

cat > "$MOCK_DIR/ollama" <<'OLLAMA'
#!/bin/bash
MOCK_MODE="${TEST_MOCK_ollama:-default}"
case "$MOCK_MODE" in
  always-fail) exit 1 ;;
  start-fail-2)
    CALL_COUNT_FILE="/tmp/ollama_call_count"
    COUNT=$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo 0)
    COUNT=$((COUNT+1)); echo "$COUNT" > "$CALL_COUNT_FILE"
    [ $COUNT -le 2 ] && exit 1 || exit 0
    ;;
  *) 
    if [ "$1" = "list" ]; then echo "NAME    ID"; echo "qwen2.5:7b abc 7GB"; exit 0
    elif [ "$1" = "ps" ]; then echo "NAME    ID"; exit 0
    else exit 0; fi
    ;;
esac
OLLAMA

cat > "$MOCK_DIR/docker-compose" <<'DOCKER'
#!/bin/bash
echo "Mock docker-compose: $*"
exit 0
DOCKER

cat > "$MOCK_DIR/docker" <<'DOCKERBIN'
#!/bin/bash
echo "Mock docker: $*"
exit 0
DOCKERBIN

cat > "$MOCK_DIR/nvidia-smi" <<'NVIDIA'
#!/bin/bash
MOCK_GPU="${TEST_MOCK_GPU:-present}"
if [ "$MOCK_GPU" = "absent" ]; then exit 127
elif [ "$MOCK_GPU" = "error" ]; then echo "NVIDIA-SMI error" >&2; exit 1; fi
echo "NVIDIA GeForce RTX 4090, 595.58.03, 23028 MiB, 2944 MiB, 19579 MiB"
NVIDIA

cat > "$MOCK_DIR/curl" <<'CURL'
#!/bin/bash
MOCK_MODE="${TEST_MOCK_curl:-success}"
[ "$MOCK_MODE" = "success" ] && echo '{"version":"0.21.2"}' && exit 0 || exit 1
CURL

cat > "$MOCK_DIR/pgrep" <<'PGR'
#!/bin/bash
# Mock pgrep: check for process matching pattern
MOCK_PROC="${TEST_MOCK_processes:-none}"
if [[ "$MOCK_PROC" == "ollama_running" ]] && [[ "$*" == *"-f"* ]] && [[ "$*" == *"ollama"* ]]; then
    exit 0  # Simulate ollama process found
elif [[ "$1" == "-f"* ]]; then
    exit 1  # No match
else
    exit 1
fi
PGR

cat > "$MOCK_DIR/pkill" <<'PKL'
#!/bin/bash
# Mock pkill: kill processes matching pattern
MOCK_PROC="${TEST_MOCK_processes:-none}"
if [[ "$MOCK_PROC" == "ollama_running" ]] && [[ "$*" == *"-f"* ]] && [[ "$*" == *"ollama"* ]]; then
    exit 0  # Simulate kill success
else
    exit 0  # No processes to kill, still success
fi
PKL

for f in ollama docker-compose docker nvidia-smi curl pgrep pkill; do chmod +x "$MOCK_DIR/$f"; done
echo "✅ Mocks installed to $MOCK_DIR"
