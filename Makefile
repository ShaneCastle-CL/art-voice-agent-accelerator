############################################################
# Makefile for gbb-ai-audio-agent
# Purpose: Manage code quality, environment, and app tasks
# Each target is documented for clarity and maintainability
############################################################

# Python interpreter to use
PYTHON_INTERPRETER = python
# Conda environment name (default: audioagent)
CONDA_ENV ?= audioagent
# Ensure current directory is in PYTHONPATH
export PYTHONPATH=$(PWD):$PYTHONPATH;
SCRIPTS_DIR = apps/rtagent/scripts
SCRIPTS_LOAD_DIR = tests/load
PHONE = +18165019907


# Install pre-commit and pre-push git hooks
set_up_precommit_and_prepush:
	pre-commit install -t pre-commit
	pre-commit install -t pre-push


# Run all code quality checks (formatting, linting, typing, security, etc.)
check_code_quality:
	# Ruff: auto-fix common Python code issues
	@pre-commit run ruff --all-files

	# Black: enforce code formatting
	@pre-commit run black --all-files

	# isort: sort and organize imports
	@pre-commit run isort --all-files

	# flake8: linting
	@pre-commit run flake8 --all-files

	# mypy: static type checking
	@pre-commit run mypy --all-files

	# check-yaml: validate YAML files
	@pre-commit run check-yaml --all-files

	# end-of-file-fixer: ensure newline at EOF
	@pre-commit run end-of-file-fixer --all-files

	# trailing-whitespace: remove trailing whitespace
	@pre-commit run trailing-whitespace --all-files

	# interrogate: check docstring coverage
	@pre-commit run interrogate --all-files

	# bandit: scan for Python security issues
	bandit -c pyproject.toml -r .


# Auto-fix code quality issues (formatting, imports, lint)
fix_code_quality:
	# Only use in development, not production
	black .
	isort .
	ruff --fix .


# Run unit tests with coverage report
run_unit_tests:
	$(PYTHON_INTERPRETER) -m pytest --cov=my_module --cov-report=term-missing --cov-config=.coveragerc


# Convenience targets for full code/test quality cycle
check_and_fix_code_quality: fix_code_quality check_code_quality
check_and_fix_test_quality: run_unit_tests


# ANSI color codes for pretty output
RED = \033[0;31m
NC = \033[0m # No Color
GREEN = \033[0;32m


# Helper function: print section titles in green
define log_section
	@printf "\n${GREEN}--> $(1)${NC}\n\n"
endef


# Create the conda environment from environment.yaml
create_conda_env:
	@echo "Creating conda environment"
	conda env create -f environment.yaml


# Activate the conda environment
activate_conda_env:
	@echo "Creating conda environment"
	conda activate $(CONDA_ENV)


# Remove the conda environment
remove_conda_env:
	@echo "Removing conda environment"
	conda env remove --name $(CONDA_ENV)

start_backend:
	python $(SCRIPTS_DIR)/start_backend.py

start_frontend:
	bash $(SCRIPTS_DIR)/start_frontend.sh

start_tunnel:
	bash $(SCRIPTS_DIR)/start_devtunnel_host.sh

generate_audio:
	python $(SCRIPTS_LOAD_DIR)/utils/audio_generator.py --max-turns 5

# WebSocket endpoint load testing (current approach)
# DEPLOYED_URL = 
LOCAL_URL = localhost:8010
run_load_test:
	@echo "Running load test (override with e.g. make run_load_test URL=wss://host TURNS=10 CONVERSATIONS=50 CONCURRENT=5 RECORD=1 RECORD_RATE=0.1 EXTRA_ARGS='--verbose')"
	$(eval URL ?= wss://$(LOCAL_URL)/api/v1/media/stream)
	$(eval TURNS ?= 5)
	$(eval CONVERSATIONS ?= 20)
	$(eval CONCURRENT ?= 20)
	$(eval RECORD ?= )
	$(eval RECORD_RATE ?= 0.2)
	@locust -f $(SCRIPTS_LOAD_DIR)/locustfile.py --headless -u $(CONVERSATIONS) -r $(CONCURRENT) --run-time 10m --host $(URL) --stop-timeout 60 --csv=locust_report --only-summary
# 	@python $(SCRIPTS_LOAD_DIR)/detailed_statistics_analyzer.py \
# 		--url $(URL) \
# 		--turns $(TURNS) \
# 		--conversations $(CONVERSATIONS) \
# 		--concurrent $(CONCURRENT) \
# 		$(if $(RECORD),--record) \
# 		$(if $(RECORD_RATE),--record-rate $(RECORD_RATE)) \
# 		$(EXTRA_ARGS)

# Conversation Analysis Targets
list-conversations:
	python $(SCRIPTS_LOAD_DIR)/conversation_playback.py --list

FILE_TO_ANALYZE = tests\load\results\recorded_conversations_20250829_085350.json

playback-conversations:
	python $(SCRIPTS_LOAD_DIR)/conversation_playback.py --conversation-file $(FILE_TO_ANALYZE)

# Run pylint on all Python files (excluding tests), output to report file
run_pylint:
	@echo "Running linter"
	find . -type f -name "*.py" ! -path "./tests/*" | xargs pylint -disable=logging-fstring-interpolation > utils/pylint_report/pylint_report.txt

############################################################
# Azure Redis Management
# Purpose: Connect to Azure Redis using Azure AD authentication
############################################################

# Connect to Azure Redis using Azure AD authentication
# Usage: make connect_redis [ENV_FILE=custom.env]
connect_redis:
	@echo "🔌 Azure Redis - Connecting with Azure AD Authentication"
	@echo "========================================================"
	@echo ""
	
	# Set default environment file
	$(eval ENV_FILE ?= .env)
	
	# Extract Redis configuration from environment file
	@echo "🔍 Extracting Redis configuration from $(ENV_FILE)"
	$(eval REDIS_HOST := $(shell grep '^REDIS_HOST=' $(ENV_FILE) | cut -d'=' -f2))
	$(eval REDIS_PORT := $(shell grep '^REDIS_PORT=' $(ENV_FILE) | cut -d'=' -f2))
	
	@if [ -z "$(REDIS_HOST)" ]; then \
		echo "❌ REDIS_HOST not found in $(ENV_FILE)"; \
		exit 1; \
	fi
	
	@if [ -z "$(REDIS_PORT)" ]; then \
		echo "❌ REDIS_PORT not found in $(ENV_FILE)"; \
		exit 1; \
	fi
	
	@echo "📋 Redis Configuration:"
	@echo "   🌐 Host: $(REDIS_HOST)"
	@echo "   🔌 Port: $(REDIS_PORT)"
	@echo ""
	
	# Get current Azure user's object ID
	@echo "🔍 Getting current Azure user's object ID..."
	$(eval USER_OBJECT_ID := $(shell az ad signed-in-user show --query id -o tsv 2>/dev/null))
	
	@if [ -z "$(USER_OBJECT_ID)" ]; then \
		echo "❌ Unable to get current user's object ID. Please ensure you are signed in to Azure CLI."; \
		echo "   Run: az login"; \
		exit 1; \
	fi
	
	@echo "👤 Current User Object ID: $(USER_OBJECT_ID)"
	@echo ""
	
	# Get access token for Redis scope
	@echo "🔐 Getting Azure access token for Redis scope..."
	$(eval ACCESS_TOKEN := $(shell az account get-access-token --scope https://redis.azure.com/.default --query accessToken -o tsv 2>/dev/null))
	
	@if [ -z "$(ACCESS_TOKEN)" ]; then \
		echo "❌ Unable to get access token for Redis scope."; \
		echo "   Please ensure you have proper permissions for Azure Cache for Redis."; \
		exit 1; \
	fi
	
	@echo "✅ Access token obtained successfully"
	@echo ""
	
	# Connect to Redis using Azure AD authentication
	@echo "🚀 Connecting to Redis with Azure AD authentication..."
	@echo "   Username: $(USER_OBJECT_ID)"
	@echo "   Password: [Azure Access Token]"
	@echo ""
	@echo "� Debug: Using command:"
	@echo "   redis-cli -h $(REDIS_HOST) -p $(REDIS_PORT) --tls -u $(USER_OBJECT_ID) -a [ACCESS_TOKEN]"
	@echo ""
	@echo "�📝 Note: You are now connected to Redis. Use Redis commands as needed."
	@echo "   Example commands: PING, INFO, KEYS *, GET <key>, SET <key> <value>"
	@echo "   Type 'quit' or 'exit' to disconnect."
	@echo ""
	
	@redis-cli -h $(REDIS_HOST) -p $(REDIS_PORT) --tls -u $(USER_OBJECT_ID) -a $(ACCESS_TOKEN) || { \
		echo ""; \
		echo "❌ Redis connection failed!"; \
		echo ""; \
		echo "🔧 Debug: Command that failed:"; \
		echo "   redis-cli -h $(REDIS_HOST) -p $(REDIS_PORT) --tls -u $(USER_OBJECT_ID) -a $(ACCESS_TOKEN)"; \
		echo ""; \
		echo "💡 Troubleshooting steps:"; \
		echo "   1. Test basic connectivity: telnet $(REDIS_HOST) $(REDIS_PORT)"; \
		echo "   2. Verify Azure permissions: az role assignment list --assignee $(USER_OBJECT_ID) --scope /subscriptions/$(shell az account show --query id -o tsv)/resourceGroups/$(shell grep '^AZURE_RESOURCE_GROUP=' $(ENV_FILE) | cut -d'=' -f2)/providers/Microsoft.Cache/redis/$(shell echo $(REDIS_HOST) | cut -d'.' -f1)"; \
		echo "   3. Check Redis configuration in Azure Portal"; \
		echo "   4. Verify TLS settings and Azure AD authentication is enabled"; \
		exit 1; \
	}

# Test Redis connection without interactive session
# Usage: make test_redis_connection [ENV_FILE=custom.env]
test_redis_connection:
	@echo "🧪 Azure Redis - Testing Connection"
	@echo "===================================="
	@echo ""
	
	# Set default environment file
	$(eval ENV_FILE ?= .env)
	
	# Extract Redis configuration from environment file
	$(eval REDIS_HOST := $(shell grep '^REDIS_HOST=' $(ENV_FILE) | cut -d'=' -f2))
	$(eval REDIS_PORT := $(shell grep '^REDIS_PORT=' $(ENV_FILE) | cut -d'=' -f2))
	
	@if [ -z "$(REDIS_HOST)" ] || [ -z "$(REDIS_PORT)" ]; then \
		echo "❌ Redis configuration not found in $(ENV_FILE)"; \
		exit 1; \
	fi
	
	# Get current Azure user's object ID and access token
	$(eval USER_OBJECT_ID := $(shell az ad signed-in-user show --query id -o tsv 2>/dev/null))
	$(eval ACCESS_TOKEN := $(shell az account get-access-token --scope https://redis.azure.com/.default --query accessToken -o tsv 2>/dev/null))
	
	@if [ -z "$(USER_OBJECT_ID)" ] || [ -z "$(ACCESS_TOKEN)" ]; then \
		echo "❌ Unable to authenticate with Azure. Please run: az login"; \
		exit 1; \
	fi
	
	@echo "🔍 Testing Redis connection..."
	@echo "   Host: $(REDIS_HOST):$(REDIS_PORT)"
	@echo "   User: $(USER_OBJECT_ID)"
	@echo ""
	
	# Test connection with PING command
	@echo "🔧 Debug: Attempting Redis connection with command:"
	@echo "   redis-cli -h $(REDIS_HOST) -p $(REDIS_PORT) --tls --user $(USER_OBJECT_ID) --pass [ACCESS_TOKEN]"
	@echo ""
	@if redis-cli -h $(REDIS_HOST) -p $(REDIS_PORT) --tls --user $(USER_OBJECT_ID) --pass $(ACCESS_TOKEN) PING > /dev/null 2>&1; then \
		echo "✅ Redis connection successful!"; \
		echo "📊 Redis Info:"; \
		redis-cli -h $(REDIS_HOST) -p $(REDIS_PORT) --tls --user $(USER_OBJECT_ID) --pass $(ACCESS_TOKEN) INFO server | head -5; \
	else \
		echo "❌ Redis connection failed!"; \
		echo ""; \
		echo "🔧 Debug: Full command that failed:"; \
		echo "   redis-cli -h $(REDIS_HOST) -p $(REDIS_PORT) --tls --user $(USER_OBJECT_ID) --pass $(ACCESS_TOKEN) PING"; \
		echo ""; \
		echo "🔧 Debug: Testing connection with verbose output:"; \
		redis-cli -h $(REDIS_HOST) -p $(REDIS_PORT) --tls --user $(USER_OBJECT_ID) --pass $(ACCESS_TOKEN) PING 2>&1 || true; \
		echo ""; \
		echo "   Please check:"; \
		echo "   • Redis host and port are correct"; \
		echo "   • Your Azure account has Redis Data Contributor role"; \
		echo "   • Azure Cache for Redis allows Azure AD authentication"; \
		echo "   • TLS is properly configured on the Redis instance"; \
		echo "   • Network connectivity to $(REDIS_HOST):$(REDIS_PORT)"; \
		exit 1; \
	fi

.PHONY: connect_redis test_redis_connection

############################################################
# Help and Documentation
############################################################

# Default target - show help
.DEFAULT_GOAL := help
# Show help information
help:
	@echo ""
	@echo "🛠️  gbb-ai-audio-agent Makefile"
	@echo "=============================="
	@echo ""
	@echo "📋 Code Quality:"
	@echo "  check_code_quality               Run all code quality checks (pre-commit, bandit, etc.)"
	@echo "  fix_code_quality                 Auto-fix code quality issues (black, isort, ruff)"
	@echo "  run_unit_tests                   Run unit tests with coverage"
	@echo "  run_pylint                       Run pylint analysis"
	@echo "  set_up_precommit_and_prepush     Install git hooks"
	@echo ""
	@echo "🐍 Environment Management:"
	@echo "  create_conda_env                 Create conda environment from environment.yaml"
	@echo "  activate_conda_env               Activate conda environment"
	@echo "  remove_conda_env                 Remove conda environment"
	@echo ""
	@echo "🚀 Application:"
	@echo "  starts_rtagent_server            Start backend server (FastAPI/Uvicorn)"
	@echo "  starts_rtagent_browser           Start frontend dev server (Vite + React)"
	@echo "  start_backend                    Start backend via script"
	@echo "  start_frontend                   Start frontend via script"
	@echo "  start_tunnel                     Start dev tunnel via script"
	@echo ""
	@echo "⚡ Load Testing:"
	@echo "  generate_audio                   Generate PCM audio files for load testing"
	@echo "  run_load_test                    Run WebSocket endpoint load testing (safe)"
	@echo ""
	@echo "🔴 Azure Redis Management:"
	@echo "  connect_redis                    Connect to Azure Redis using Azure AD authentication"
	@echo "  test_redis_connection            Test Redis connection without interactive session"
	@echo ""
	@echo "📖 Required Environment Variables (for Terraform):"
	@echo "  AZURE_SUBSCRIPTION_ID            Your Azure subscription ID"
	@echo "  AZURE_ENV_NAME                   Environment name (default: dev)"
	@echo ""
	@echo "💡 Quick Start for Environment Generation:"
	@echo "  export AZURE_SUBSCRIPTION_ID=<your-subscription-id>"
	@echo "  export AZURE_ENV_NAME=dev"
	@echo "  make generate_env_from_terraform"
	@echo "  make update_env_with_secrets"
	@echo ""
	@echo "💡 Quick Start for Full Terraform Deployment (Alternative to azd):"
	@echo "  1. cd infra/terraform && terraform init && terraform apply"
	@echo "  2. cd ../.. && make generate_env_from_terraform"
	@echo "  3. make update_env_with_secrets"
	@echo "  4. make generate_backend_deployment && make deploy_backend"
	@echo "  5. make generate_frontend_deployment && make deploy_frontend"
	@echo ""
	@echo "💡 Deployment Monitoring Tips:"
	@echo "  • Large deployments may timeout after 15 minutes but continue in background"
	@echo "  • Use monitor_deployment targets to check status during/after deployment"
	@echo "  • Install 'Azure App Service' VS Code extension for easy log streaming"
	@echo "  • Frontend builds (Vite/React) typically take 5-15 minutes"
	@echo ""
	@echo "📝 Note: ACS endpoint will be retrieved from:"
	@echo "  1. Environment file (ACS_ENDPOINT variable)"
	@echo "  2. Terraform state output (acs_endpoint)"
	@echo "  3. Manual input if not found above"
	@echo ""

.PHONY: help
