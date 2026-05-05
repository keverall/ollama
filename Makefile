# ollama-cachyos Test Suite Makefile
# Follows DevOps principles: fast feedback, automation, reproducibility

.PHONY: help test test-unit test-integration test-smoke test-e2e test-all lint coverage clean install-mocks

# Default target
help:
	@echo "ollama-cachyos DevOps Test Suite"
	@echo ""
	@echo "Available targets:"
	@echo "  test-unit      - Run unit tests (fast, < 30s)"
	@echo "  test-integration - Run integration tests (< 5 min)"
	@echo "  test-smoke     - Run smoke tests (< 60s)"
	@echo "  test-e2e       - Run end-to-end tests (full workflow)"
	@echo "  test-all       - Run full test suite"
	@echo "  lint           - Run shellcheck on all scripts"
	@echo "  coverage       - Generate test coverage report"
	@echo "  install-mocks  - Setup mock binaries for offline testing"
	@echo "  clean          - Clean test artifacts"

# Directories
PROJECT_DIR := ollama-devops
TEST_DIR := $(PROJECT_DIR)/tests
BATS_DIR := $(TEST_DIR)/_bats_lib
UNIT_DIR := $(TEST_DIR)/unit
INT_DIR := $(TEST_DIR)/integration
SMOKE_DIR := $(TEST_DIR)/smoke
E2E_DIR := $(TEST_DIR)/e2e
FIXTURES_DIR := $(TEST_DIR)/fixtures
MOCKS_DIR := $(TEST_DIR)/mocks

# Script under test
SOD_SCRIPT := $(PROJECT_DIR)/scripts/sod.sh
EOD_SCRIPT := $(PROJECT_DIR)/scripts/eod.sh

# ===============================
# Unit Tests
# ===============================
test-unit: SHELLCHECK_FLAGS := -x
test-unit:
	@echo "Running unit tests..."
	@cd $(UNIT_DIR) && ./run_all.sh
	@echo "✅ Unit tests passed"

# ===============================
# Integration Tests
# ===============================
test-integration: export TEST_ENV := integration
test-integration:
	@echo "Running integration tests..."
	@cd $(INT_DIR) && ./run_all.sh
	@echo "✅ Integration tests passed"

# ===============================
# Smoke Tests
# ===============================
test-smoke: export TEST_ENV := smoke
test-smoke:
	@echo "Running smoke tests..."
	@cd $(SMOKE_DIR) && ./run_all.sh
	@echo "✅ Smoke tests passed"

# ===============================
# End-to-End Tests
# ===============================
test-e2e: export TEST_ENV := e2e
test-e2e:
	@echo "Running E2E tests (may take several minutes)..."
	@cd $(E2E_DIR) && ./run_all.sh
	@echo "✅ E2E tests passed"

# ===============================
# Full Test Suite
# ===============================
test-all: test-unit test-integration test-smoke
	@echo "Full test suite completed! (Excluding long-running E2E)"
	@echo "Run 'make test-e2e' separately for complete coverage."

# ===============================
# Linting
# ===============================
lint:
	@echo "Running shellcheck..."
	@shellcheck $(SOD_SCRIPT) $(EOD_SCRIPT)
	@echo "✅ Shellcheck passed"
	@echo "Running bashate..."
	@bash -n $(SOD_SCRIPT) && bash -n $(EOD_SCRIPT)
	@echo "✅ Bash syntax valid"

# ===============================
# Coverage
# ===============================
coverage:
	@echo "Generating coverage report..."
	@$(PROJECT_DIR)/tests/run_coverage.sh
	@echo "Coverage report generated at $(PROJECT_DIR)/coverage/index.html"

# ===============================
# Install mocks for offline testing
# ===============================
install-mocks:
	@echo "Installing mock binaries..."
	@cd $(MOCKS_DIR) && ./install.sh
	@echo "✅ Mocks installed to /usr/local/bin (for current session)"

# ===============================
# Cleanup
# ===============================
clean:
	@echo "Cleaning test artifacts..."
	rm -rf $(TEST_DIR)/logs/*
	rm -rf $(TEST_DIR)/coverage/*
	rm -rf $(TEST_DIR)/tmp/*
	rm -rf $(PROJECT_DIR)/coverage
	@echo "✅ Clean complete"
