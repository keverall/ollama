# Documentation Standard

This document outlines the documentation standard for all scripts and configuration files in the project.

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
# Hardware:         <Target hardware, e.g., RTX 4090 (24GB VRAM)>
# Parameters:       <List of key parameters and their values>
#============================================================================

# Optional: System prompt or other configuration
SYSTEM """<System prompt if applicable>"""
```

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

## General Guidelines

- Keep documentation up to date when making changes.
- Use clear, concise language.
- Avoid redundancy; reference other documents when appropriate.
- Mark deprecated sections clearly.
- Use consistent formatting and style.
