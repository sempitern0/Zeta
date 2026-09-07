.PHONY: help lint chmod init-dirs certs setup install-shellcheck install-hooks up up-detached up-build down ps restart stop build build-nc destroy destroy-volumes

.DEFAULT_GOAL := help

# Dynamically find any .sh script in the root directory and inside lib/
SCRIPTS := $(wildcard *.sh) $(wildcard lib/*.sh)

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

chmod: ## Make main scripts and hooks executable
	@chmod +x *.sh 2>/dev/null || true
	@chmod +x githooks/pre-commit 2>/dev/null || true
	@echo "✓ Granted execution permissions to scripts"

init-dirs: ## Create required project directory structure
	@mkdir -p sites content templates lib nginx/certs backend
	@echo "✓ Directory structure verified"

certs: init-dirs ## Generate self-signed SSL certificates for zeta.local if missing
	@if [ ! -f nginx/certs/zeta.crt ]; then \
		echo "Generating SSL self-signed certificates for zeta.local..."; \
		openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
			-keyout nginx/certs/zeta.key \
			-out nginx/certs/zeta.crt \
			-subj "/CN=zeta.local/O=Zeta SSG/C=ES" 2>/dev/null; \
		echo "✓ Certificates generated in nginx/certs/"; \
	else \
		echo "✓ SSL certificates already exist."; \
	fi

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

install-hooks: ## Install Git pre-commit hook into .git/hooks if git repository exists
	@if [ -d .git ]; then \
		mkdir -p .git/hooks; \
		cp githooks/pre-commit .git/hooks/pre-commit 2>/dev/null || true; \
		chmod +x .git/hooks/pre-commit 2>/dev/null || true; \
		echo "✓ Git pre-commit hook installed successfully!"; \
	fi

setup: chmod init-dirs certs install-hooks up-build ## Full setup: permissions, dirs, SSL certs, git hooks & build Docker containers
	@echo ""
	@echo "================================================================="
	@echo " 🎉 Zeta SSG is ready!"
	@echo " Remember to include this lines in /etc/hosts:"
	@echo "   127.0.0.1 zeta.local"
	@echo "   ::1       zeta.local"
	@echo ""
	@echo "Sites Dashboard available: https://zeta.local"
	@echo "================================================================="

# ==========================================
# Docker Compose Shortcuts
# ==========================================
up: ## Start containers in foreground
	docker compose up

up-detached: ## Start containers in background (detached)
	docker compose up -d

up-build: ## Rebuild and start containers in background
	docker compose up -d --build

down: ## Stop and remove containers
	docker compose down --remove-orphans

ps: ## List running containers
	docker compose ps

restart: down up-detached ## Restart all containers

stop: ## Stop containers without removing them
	docker compose stop

build: ## Build container images
	docker compose build

build-nc: ## Build container images without cache
	docker compose build --no-cache

destroy: ## Tear down containers, networks, images, and volumes
	docker compose down --rmi all --volumes --remove-orphans

destroy-volumes: ## Tear down containers and volumes
	docker compose down --volumes --remove-orphans