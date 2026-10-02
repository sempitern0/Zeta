.PHONY: help setup chmod init-dirs check syntax lint install-hooks run serve build-all certs docker-up docker-down docker-ps docker-restart

.DEFAULT_GOAL := help
SCRIPTS := $(wildcard *.sh) $(wildcard lib/*.sh)

help: ## Show available targets
	@echo "Usage: make [target]"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

chmod: ## Make Zeta scripts executable
	@chmod +x main.sh 2>/dev/null || true
	@chmod +x githooks/pre-commit 2>/dev/null || true
	@echo "✓ Executable permissions ready"

init-dirs: ## Create the local sites workspace
	@mkdir -p sites
	@touch sites/.gitkeep
	@echo "✓ Local workspace ready"

check: ## Check required runtime dependencies
	@command -v bash >/dev/null 2>&1 || { echo "✗ Bash is required"; exit 1; }
	@bash -c '(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3) ))' || { echo "✗ Bash 4.3+ is required"; exit 1; }
	@command -v pandoc >/dev/null 2>&1 || { echo "✗ Pandoc is required to build sites"; exit 1; }
	@echo "✓ Bash: $$(bash --version | head -n 1)"
	@echo "✓ Pandoc: $$(pandoc --version | head -n 1)"
	@if command -v python3 >/dev/null 2>&1; then echo "✓ Python 3: local preview available"; else echo "• Python 3 not found: build works, built-in preview disabled"; fi

syntax: ## Validate Bash syntax without extra tools
	@for file in $(SCRIPTS); do bash -n "$$file" || exit 1; done
	@echo "✓ Bash syntax checks passed"

lint: syntax ## Run ShellCheck when already installed
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(SCRIPTS); \
		echo "✓ ShellCheck passed"; \
	else \
		echo "✗ ShellCheck is not installed. Install it explicitly if you want linting."; \
		exit 2; \
	fi

install-hooks: ## Install the repository pre-commit hook when .git exists
	@if [ -d .git ] && [ -f githooks/pre-commit ]; then \
		mkdir -p .git/hooks; \
		cp githooks/pre-commit .git/hooks/pre-commit; \
		chmod +x .git/hooks/pre-commit; \
		echo "✓ Pre-commit hook installed"; \
	else \
		echo "• Git hook skipped"; \
	fi

setup: chmod init-dirs install-hooks check syntax ## Prepare Zeta without Docker or system changes
	@echo ""
	@echo "Zeta is ready. Run: ./main.sh"

run: ## Open the interactive Zeta assistant
	@./main.sh

serve: ## Build every local site and serve the workspace on port 8000
	@./main.sh serve

build-all: ## Build every local site into its public/ directory
	@./main.sh build-all

certs: ## Optional: generate local zeta.local TLS certificates for Docker/Nginx
	@mkdir -p nginx/certs
	@if [ ! -f nginx/certs/zeta.crt ]; then \
		openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
			-keyout nginx/certs/zeta.key \
			-out nginx/certs/zeta.crt \
			-subj "/CN=zeta.local/O=Zeta SSG/C=ES"; \
		echo "✓ Local certificates generated"; \
	else \
		echo "✓ Local certificates already exist"; \
	fi

docker-up: certs ## Optional: start the existing Nginx HTTPS development stack
	docker compose up -d

docker-down: ## Stop the optional Docker development stack
	docker compose down --remove-orphans

docker-ps: ## Show optional Docker stack status
	docker compose ps

docker-restart: docker-down docker-up ## Restart the optional Docker development stack
