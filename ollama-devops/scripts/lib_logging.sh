#!/bin/bash
#============================================================================
# Title:            lib_logging.sh
# Description:      Shared logging library for ollama-devops scripts
#                   Provides centralized logging with levels, timestamps,
#                   and log-file management
# Author:           Keverall
# Date:             2026-04-30
# Version:          1.0.0
# Requirements:     bash 4+, tee command
#============================================================================
set -euo pipefail

# Prevent double-sourcing
if [[ -n "${_LIB_LOGGING_SOURCED:-}" ]]; then
    return 0
fi
_LIB_LOGGING_SOURCED=1

#----------------------------------------------------------------------------
# Logging Configuration
#----------------------------------------------------------------------------

# Default log level (INFO, WARN, ERROR, SUCCESS, DEBUG)
: "${LOG_LEVEL:-INFO}"

# Log level precedence (higher number = more critical)
log_level_priority() {
    case "$1" in
        DEBUG)   echo 1 ;;
        INFO)    echo 2 ;;
        SUCCESS) echo 2 ;;
        WARN)    echo 3 ;;
        ERROR)   echo 4 ;;
        *)       echo 0 ;;
    esac
}

# Emoji mapping for log levels
log_emoji() {
    local level="$1"
    case "$level" in
        INFO)    echo "" ;;
        WARN)    echo "⚠️  " ;;
        ERROR)   echo "❌ " ;;
        SUCCESS) echo "✅ " ;;
        DEBUG)   echo "🔍 " ;;
        *)       echo "" ;;
    esac
}

# Detect platform: macos, cachyos, linux, or unknown
# Respects PLATFORM_OVERRIDE env var (auto, macos, cachyos, linux)
detect_platform() {
    # Check for manual platform override first
    if [[ "${PLATFORM_OVERRIDE:-auto}" != "auto" ]]; then
        echo "${PLATFORM_OVERRIDE}"
        return
    fi

    local os
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$os" in
        darwin*) echo "macos" ;;
        linux*)
            if [[ -f /etc/os-release ]] && grep -qiE "cachyos|arch" /etc/os-release; then
                echo "cachyos"
            else
                echo "linux"
            fi
            ;;
        *) echo "unknown" ;;
    esac
}

# Set PLATFORM if not already set (allows override via environment)
: "${PLATFORM:=$(detect_platform)}"

#----------------------------------------------------------------------------
# Log File Management
#----------------------------------------------------------------------------

# Initialize log file for the calling script
# Call this from your script BEFORE calling log()
# If platform is not provided, uses the auto-detected $PLATFORM
log_init() {
    local script_name="${1:-$(basename "${BASH_SOURCE[1]}" .sh)}"
    local purpose="${2:-run}"
    local platform="${3:-$PLATFORM}"

    # Use provided LOG_DIR or infer from PROJECT_ROOT
    if [[ -z "${LOG_DIR:-}" ]] && [[ -n "${PROJECT_ROOT:-}" ]]; then
        LOG_DIR="${PROJECT_ROOT}/logs"
    elif [[ -z "${LOG_DIR:-}" ]]; then
        # Fallback to script-relative logs directory
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        LOG_DIR="$(dirname "$script_dir")/logs"
    fi

    FILE_TIMESTAMP="$(date '+%Y%m%d%H%M%S')"
    LOG_FILE="${LOG_DIR}/${FILE_TIMESTAMP}-${platform}-${script_name}-${purpose}.log"

    mkdir -p "${LOG_DIR}"
}

#----------------------------------------------------------------------------
# Core Logging Function
#----------------------------------------------------------------------------
# Usage examples:
#   log "Simple info message"                          -> INFO level, timestamp
#   log WARN "Watch out!"                               -> WARN with ⚠️ emoji
#   log ERROR "Something broke"                         -> ERROR with ❌ emoji
#   log SUCCESS "Task completed"                        -> SUCCESS with ✅ emoji
#   log "msg" "" "no_timestamp"                        -> suppress timestamp (3rd arg)
#   log "msg" "" "" "true"                             -> explicit no_timestamp
#   log INFO "message" "CUSTOM: "                      -> custom prefix
#
# Parameters:
#   $1 = log level (INFO|WARN|ERROR|SUCCESS|DEBUG) or message (if single arg)
#   $2 = message text (optional, required if $1 is level)
#   $3 = custom prefix (optional)
#   $4 = no_timestamp flag (optional, "true" suppresses timestamp)
log() {
    local level="INFO"
    local message=""
    local prefix=""
    local no_timestamp=""

    # Parse arguments (backward compatible: single arg = message)
    if [[ $# -eq 1 ]]; then
        message="$1"
    elif [[ $# -ge 2 ]]; then
        level="$1"
        message="$2"
        if [[ $# -ge 3 ]]; then
            prefix="$3"
        fi
        if [[ $# -ge 4 ]]; then
            no_timestamp="$4"
        fi
    fi

    # Check log level filter
    if [[ -n "${LOG_LEVEL_FILTER:-}" ]]; then
        local level_pri filter_pri
        level_pri=$(log_level_priority "$level")
        filter_pri=$(log_level_priority "$LOG_LEVEL_FILTER")
        if [[ "$level_pri" -lt "$filter_pri" ]]; then
            return 0
        fi
    fi

    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Determine line prefix
    local line_prefix=""
    if [[ -n "$prefix" ]]; then
        line_prefix="$prefix"
    else
        line_prefix="$(log_emoji "$level")"
    fi

    # Build output line
    local output=""
    if [[ "$no_timestamp" == "true" ]]; then
        output="${line_prefix}${message}"
    else
        output="[$timestamp] ${line_prefix}${message}"
    fi

    # Write to console (interpret ANSI escapes) and log file (strip them)
    printf '%b\n' "$output"
    printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' >> "${LOG_FILE}"
}

#----------------------------------------------------------------------------
# Convenience Wrappers
#----------------------------------------------------------------------------

log_info()    { log INFO "$1" "${2:-}" "${3:-}"; }
log_warn()    { log WARN "$1" "${2:-}" "${3:-}"; }
log_error()   { log ERROR "$1" "${2:-}" "${3:-}"; }
log_success() { log SUCCESS "$1" "${2:-}" "${3:-}"; }
log_debug()   { log DEBUG "$1" "${2:-}" "${3:-}"; }

#----------------------------------------------------------------------------
# Log File Query Utilities
#----------------------------------------------------------------------------

# Get the current log file path
log_file() {
    echo "${LOG_FILE}"
}

# Tail the current log file
log_tail() {
    local lines="${1:-20}"
    if [[ -f "${LOG_FILE}" ]]; then
        tail -n "$lines" "${LOG_FILE}"
    else
        echo "No log file found at ${LOG_FILE}" >&2
        return 1
    fi
}

# Search log file for pattern
log_grep() {
    local pattern="$1"
    if [[ -f "${LOG_FILE}" ]]; then
        grep -i "$pattern" "${LOG_FILE}" || true
    else
        echo "No log file found at ${LOG_FILE}" >&2
        return 1
    fi
}

# Export log file path for external tools
export LOG_FILE
