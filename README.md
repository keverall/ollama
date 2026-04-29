# Ollama DevOps Project

A comprehensive project for managing and deploying Ollama AI models with DevOps best practices, including configuration management, automated deployment, and model lifecycle management.

## Project Structure

```text
├── logs/
│   ├── ollama-macbook-server.log
│   └── ollama-server.log
└── ollama-macbook/
    ├── README.md
    ├── modfiles/
    │   ├── modfile-gemma4
    │   └── modfile-qwen-devops
    ├── scripts/
    │   ├── .env
    │   ├── .envexample
    │   ├── EOD-Stop-models.sh
    │   ├── docker-compose.yml
    │   ├── modfile-gemma4
    │   ├── modfile-qwen-devops
    │   └── start-models.sh
    └── test/
```

## Key Components

- **.kilo/**: Kilo configuration and skills for automation
- **ollama-macbook/**: Main project directory with scripts and configurations
- **nomic-embed-text,qwen2.5-coder:14b/**: Ollama model storage
- **logs/**: Server logs for monitoring

## DevOps Standards

### Version Control
- Use Git for version control with meaningful commit messages
- Follow semantic versioning for releases
- Protect main branch with required reviews and CI checks

### CI/CD Pipeline
- Automated testing on pull requests
- Automated deployment using scripts in `ollama-macbook/scripts/`
- Docker Compose for containerized deployments
- Environment-specific configurations (.env files)

### Configuration Management
- Centralized configuration in `.kilo/` directory
- Environment variables managed via `.env` files
- Modfiles for Ollama model configurations

### Monitoring and Logging
- Logs stored in `logs/` directory
- Server logs for troubleshooting
- Model performance monitoring

### Security
- No secrets committed to repository
- Environment variables for sensitive data
- Regular dependency updates

### Deployment
- Automated model startup via `start-models.sh`
- Graceful shutdown with `EOD-Stop-models.sh`
- Docker Compose for orchestrated deployments

### Testing
- Test scripts in `test/` directory
- Integration tests for Ollama API endpoints
- Validation of model loading and inference