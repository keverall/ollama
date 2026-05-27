#!/bin/bash
# Common test utilities and assertions

__test_utils_loaded=1

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

assert_equal() { local expected="$1" actual="$2" msg="$3"; if [ "$expected" != "$actual" ]; then echo -e "${RED}Assertion failed${NC}: $msg" >&2; echo "  Expected: $expected" >&2; echo "  Actual:   $actual" >&2; return 1; fi; return 0; }
assert_not_equal() { local unexpected="$1" actual="$2"; if [ "$unexpected" = "$actual" ]; then echo -e "${RED}Assertion failed${NC}: values should differ" >&2; return 1; fi; return 0; }
assert_contains() { local string="$1" substring="$2" msg="$3"; if [[ "$string" != *"$substring"* ]]; then echo -e "${RED}Assertion failed${NC}: $msg" >&2; echo "  String: $string" >&2; echo "  Should contain: $substring" >&2; return 1; fi; return 0; }
assert_file_exists() { local file="$1"; if [ ! -f "$file" ]; then echo -e "${RED}File not found${NC}: $file" >&2; return 1; fi; return 0; }
assert_dir_exists() { local dir="$1"; if [ ! -d "$dir" ]; then echo -e "${RED}Directory not found${NC}: $dir" >&2; return 1; fi; return 0; }
assert_file_contains() { local file="$1" pattern="$2"; if ! grep -q "$pattern" "$file" 2>/dev/null; then echo -e "${RED}File missing pattern${NC}: $pattern" >&2; echo "  File: $file" >&2; return 1; fi; return 0; }
assert_success() { local status="$1"; if [ "$status" -ne 0 ]; then echo -e "${RED}Expected success, got $status${NC}" >&2; return 1; fi; return 0; }
assert_failure() { local status="$1"; if [ "$status" -eq 0 ]; then echo -e "${RED}Expected failure, got 0${NC}" >&2; return 1; fi; return 0; }

create_fake_ollama() {
    mkdir -p bin
    cat > bin/ollama <<'OLLAMA'
#!/bin/bash
case "$1" in
    list) echo "NAME    ID    SIZE    MODIFIED"; echo "qwen2.5:7b  abc  7GB  2026-04-29";;
    ps) echo "NAME    ID    SIZE    EXPIRES";;
    *) exit 0;;
esac
OLLAMA
    chmod +x bin/ollama
    export PATH="$(pwd)/bin:$PATH"
}

