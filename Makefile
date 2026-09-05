.PHONY: help lint chmod setup install-shellcheck install-hooks

.DEFAULT_GOAL := help

# Dynamically find any .sh script in the root directory and inside lib/
SCRIPTS := $(wildcard *.sh) $(wildcard lib/*.sh)

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

chmod: ## Make main script and hook executable
	@chmod +x *.sh 2>/dev/null || true
	@chmod +x githooks/pre-commit 2>/dev/null || true
	@echo "✓ Granted execution permissions to scripts"

install-shellcheck: ## Install ShellCheck automatically if missing
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "shellcheck not found. Installing automatically..."; \
		if command -v brew >/dev/null 2>&1; then \
			brew install shellcheck; \
		elif command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get update && sudo apt-get install -y shellcheck; \
		elif command -v dnf >/dev/null 2>&1; then \
			sudo dnf install -y shellcheck; \
		elif command -v pacman >/dev/null 2>&1; then \
			sudo pacman -S --noconfirm shellcheck; \
		else \
			echo "✗ Package manager not recognized. Please install shellcheck manually."; \
			exit 1; \
		fi \
	fi

lint: install-shellcheck ## Run ShellCheck on all .sh scripts
	@echo "Fixing line endings (CRLF -> LF)..."
	@sed -i 's/\r$$//' .shellcheckrc $(SCRIPTS) 2>/dev/null || true
	@echo "Running ShellCheck..."
	@shellcheck $(SCRIPTS)
	@echo "✓ ShellCheck passed cleanly!"

install-hooks: ## Install Git pre-commit hook into .git/hooks
	@mkdir -p .git/hooks
	@cp githooks/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "✓ Git pre-commit hook installed successfully!"

setup: chmod install-hooks lint ## Run full setup: permissions, hooks, and linter