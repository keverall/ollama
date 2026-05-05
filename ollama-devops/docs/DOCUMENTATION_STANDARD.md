# Documentation Standard

This document outlines the documentation standard for all scripts and configuration files in the ollama-devops project.

## Scripts (Bash)

Every script should include the following header block:

```bash
#!/bin/bash
#============================================================================
# Title:            <script_name.sh>
# Description:      <Brief description of what the script does>
# Author:           <Your name>
# Date:             <YYYY-MM-DD>
# Version:          <Version number, e.g., 1.0.0>
# Usage:            <How to use the script, if applicable>
# Requirements:     <List of requirements, e.g., bash, ollama, docker>
# Exit Codes:       <List of exit codes and their meanings, if applicable>
#============================================================================
```

Additionally:
- Use `set -euo pipefail` for robust error handling.
- Include descriptive comments for complex logic sections.
- Use meaningful variable names.
- Log important actions to a log file and/or stdout.
- Support `--dry-run` and `--help` flags for operational scripts.

### Cross-Platform Script Requirements

When writing scripts that support multiple platforms:

1. Detect platform early using `detect_platform()` from `lib_logging.sh`
2. Set platform-specific paths and configuration based on detection
3. Use `MODFILE_DIR` variable to reference platform modfiles
4. Load platform-specific `.env` from `platform/<platform>/.env`
5. Provide `PLATFORM_OVERRIDE` for manual platform specification
6. Include graceful fallbacks for missing platform-specific features

#### Bash Compatibility

Scripts must be compatible with **bash 3.2** (macOS default) and modern bash (5.x):

- **No associative arrays** (`declare -A`): Use `case` statements or functions for lookups
- **Avoid `timeout` without fallback**: Provide portable alternatives (background kill) for macOS
- **No `&>>` operator**: Use `>> file 2>&1` instead
- **Test with `bash -n` and `shellcheck -x`**: Catch portability issues early
- **Quote variable expansions**: Prevent word splitting and globbing issues

See `lib_logging.sh` for an example of associative array replacement with `log_level_priority()` function.

## Configuration Files

### Modfiles (Ollama)

Every modfile should include:

```bash
FROM <base_model>

#============================================================================
# Title:            <modfile_name>
# Description:      <Brief description of the model optimization>
# Author:           <Your name>
# Date:             <YYYY-MM-DD>
# Version:          <Version number, e.g., 1.0.0>
# Hardware:         <Target hardware, e.g., RTX 4090 (24GB VRAM) or M4 Pro>
# Parameters:       <List of key parameters and their values>
#============================================================================

# Optional: System prompt or other configuration
SYSTEM """<System prompt if applicable>"""
```

Modfile location: `platform/<platform>/modfiles/`

### Environment Files (.env)

Environment files should:
- Include comprehensive comments explaining each variable
- Provide platform-appropriate defaults
- Reference the `.envexample` template when creating new ones
- Be gitignored (only `.envexample` is committed)

Example structure:
```bash
# Platform-specific configuration
OLLAMA_BIN="ollama"
OLLAMA_HOST="[::]:11434"
DEFAULT_MODELS="model1,model2"

# Performance tuning
OLLAMA_NUM_PARALLEL="24"
OLLAMA_MAX_LOADED_MODELS="2"
```

Location: `platform/<platform>/.env` (copied to `scripts/.env` for use)

### Systemd Service Files

Every systemd service file should include:

```ini
#============================================================================
# Title:            <service_name>.service
# Description:      <Brief description of the service>
# Author:           <Your name>
# Date:             <YYYY-MM-DD>
# Version:          <Version number, e.g., 1.0.0>
# Documentation:    <Link to documentation if applicable>
#============================================================================

[Unit]
Description=<Human-readable description>
After=<dependencies>

[Service]
<service-specific configuration>

[Install]
WantedBy=<target>
```

Location: `systemd/`

### Docker Compose Files

The docker-compose.yml file should include a header comment:

```yaml
#============================================================================
# Title:            docker-compose.yml
# Description:      <Brief description of the composition>
# Author:           <Your name>
# Date:             <YYYY-MM-DD>
# Version:          <Version number, e.g., 1.0.0>
#============================================================================

version: '3.8'
services:
  # Service definitions
```

Location: `docker-compose.yml` (project root)

## README Files

Every major directory or component should have a README.md that includes:

```markdown
# <Component Name>

## Purpose
<Brief description of what this component does>

## Prerequisites
<List of software, hardware, or knowledge required>

## Installation
<Step-by-step installation instructions>

## Usage
<Examples of how to use the component>

## Configuration
<Description of configuration options, environment variables, etc.>

## Troubleshooting
<Common issues and solutions>

## Contributing
<Guidelines for contributing to this component>

## License
<License information>
```

### Project README Location

Main README: `ollama-devops/README.md`

Platform documentation: `ollama-devops/docs/`

## Directory Structure Reference

```
ollama-devops/
├── scripts/                          # Unified cross-platform scripts
│   ├── sod.sh                       # Start of Day script
│   ├── eod.sh                       # End of Day script
│   ├── lib_logging.sh               # Shared logging library
│   ├── initialisation/
│   │   └── setup_passwordless_sudo.sh   # Sudo configuration helper
│   └── .envexample                  # Configuration template
├── platform/                         # Platform-specific configurations
│   ├── macbook-m4-24gb-optimized/
│   │   ├── modfiles/                 # MacBook-specific modfiles
│   │   │   ├── modfile-gemma4
│   │   │   └── modfile-qwen-devops
│   │   └── .env                      # MacBook-specific config
│   └── cachyos-i9-32gb-nvidia-4090/
│       ├── modfiles/                 # CachyOS-specific modfiles
│       │   ├── qwen2.5-coder:32b-gpu.modelfile
│       │   ├── Qwen2.5-7B-instruct-GPU.modelfile
│       │   ├── nomic-embed-text-GPU.modelfile
│       │   └── snowflake-arctic-embed.modfile
│       └── .env                      # CachyOS-specific config
├── systemd/                          # systemd service files (Linux)
│   ├── ollama.service               # main service unit
│   ├── platform-overrides/          # drop-in configs
│   │   └── cachyos-nvidia.conf
│   └── README.md
├── docs/                             # Documentation
│   ├── SYSTEM_OVERVIEW.md
│   ├── API_ENDPOINTS.md
│   ├── SYSTEMD_INTEGRATION.md
│   ├── MIGRATION_SYSTEMD.md
│   ├── DOCUMENTATION_STANDARD.md
│   └── tests/
│       ├── README.md
│       ├── QUICKSTART.md
│       ├── TEST_PLAN.md
│       ├── TEST_SUMMARY.md
│       ├── IMPLEMENTATION_SUMMARY.md
│       └── ARCHITECTURE.txt
├── tests/                            # Test suites
│   ├── unit/                         # Unit tests
│   │   ├── run_all.sh
│   │   ├── test_configuration.bats
│   │   ├── test_validation.bats
│   │   ├── test_ensure_model.bats
│   │   ├── test_readiness_loop.bats
│   │   └── test_warmup.bats
│   ├── integration/                  # Integration tests
│   │   ├── run_all.sh
│   │   ├── test_sod_integration.bats
│   │   └── test_eod_integration.bats
│   ├── smoke/                        # Smoke tests
│   │   ├── run_all.sh
│   │   └── test_basic_smoke.bats
│   ├── e2e/                          # End-to-end tests
│   │   ├── run_all.sh
│   │   └── test_full_workflow.bats
│   ├── fixtures/                     # Test data
│   │   ├── nvidia-smi-output.csv
│   │   └── model-list-sample.txt
│   ├── mocks/                        # Mock binaries
│   │   ├── install.sh
│   │   ├── ollama
│   │   ├── docker-compose
│   │   ├── docker
│   │   ├── nvidia-smi
│   │   ├── curl
│   │   ├── pgrep
│   │   └── pkill
│   ├── test_utils/                   # Shared utilities
│   │   └── common.sh
│   ├── run_all.sh                    # Master runner
│   ├── run_lint.sh                   # Linting
│   ├── run_coverage.sh               # Coverage
│   └── setup.sh                      # Setup wizard
├── docker-compose.yml                # Qdrant deployment
├── Makefile                          # Build automation
└── logs/                             # Runtime logs (gitignored)
```

## General Guidelines

- Keep documentation up to date when making changes.
- Use clear, concise language.
- Avoid redundancy; reference other documents when appropriate.
- Mark deprecated sections clearly.
- Use consistent formatting and style.
- Include examples for complex procedures.
- Document platform-specific behavior in both script headers and docs.

## File Naming Conventions

- **Shell scripts**: lowercase with underscores (`sod.sh`, `eod.sh`, `run_all.sh`)
- **Modfiles**: Match model name with platform suffix (`qwen2.5-coder:32b-gpu.modelfile`)
- **Configuration**: `.env` for local, `.envexample` for template
- **Tests**: `test_<feature>.bats` for Bats test files
- **Documentation**: SCREAMING_SNAKE_CASE for filenames (`SYSTEM_OVERVIEW.md`)

---

**Last Updated:** 2026-04-30  
**Version:** 1.0.0
