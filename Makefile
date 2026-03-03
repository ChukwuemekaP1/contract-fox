# StellarAid Contract Workspace Makefile
# Provides convenient commands for building, testing, and deploying Soroban contracts

.PHONY: build test clean help deploy-testnet deploy-mainnet fmt lint wasm

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)StellarAid Contract Workspace$(NC)"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'

build: ## Build all workspace crates
	@echo "$(BLUE)Building all workspace crates...$(NC)"
	cargo build --workspace
	@echo "$(GREEN)Build complete!$(NC)"

wasm: ## Build WASM contracts for deployment
	@echo "$(BLUE)Building WASM contracts...$(NC)"
	cargo build -p donation --target wasm32-unknown-unknown --release
	cargo build -p withdrawal --target wasm32-unknown-unknown --release
	cargo build -p campaign --target wasm32-unknown-unknown --release
	@echo "$(GREEN)WASM build complete!$(NC)"
	@echo "$(YELLOW)WASM files located in target/wasm32-unknown-unknown/release/$(NC)"

test: ## Run all tests
	@echo "$(BLUE)Running all tests...$(NC)"
	cargo test --workspace
	@echo "$(GREEN)Tests complete!$(NC)"

test-contracts: ## Run contract tests only
	@echo "$(BLUE)Running contract tests...$(NC)"
	cargo test -p donation
	cargo test -p withdrawal
	cargo test -p campaign
	@echo "$(GREEN)Contract tests complete!$(NC)"

deploy-testnet: wasm ## Deploy contracts to Soroban testnet
	@echo "$(YELLOW)Deploying to testnet...$(NC)"
	@echo "$(BLUE)Deploying donation contract...$(NC)"
	soroban contract deploy --wasm target/wasm32-unknown-unknown/release/donation.wasm --source-account default --network testnet
	@echo "$(BLUE)Deploying withdrawal contract...$(NC)"
	soroban contract deploy --wasm target/wasm32-unknown-unknown/release/withdrawal.wasm --source-account default --network testnet
	@echo "$(BLUE)Deploying campaign contract...$(NC)"
	soroban contract deploy --wasm target/wasm32-unknown-unknown/release/campaign.wasm --source-account default --network testnet
	@echo "$(GREEN)Testnet deployment complete!$(NC)"

deploy-mainnet: wasm ## Deploy contracts to Soroban mainnet
	@echo "$(YELLOW)Deploying to mainnet...$(NC)"
	@echo "$(RED)WARNING: This will use real funds!$(NC)"
	@read -p "Are you sure? [y/N] " confirm && [ $$confirm = y ] || exit 1
	@echo "$(BLUE)Deploying donation contract...$(NC)"
	soroban contract deploy --wasm target/wasm32-unknown-unknown/release/donation.wasm --source-account default --network mainnet
	@echo "$(BLUE)Deploying withdrawal contract...$(NC)"
	soroban contract deploy --wasm target/wasm32-unknown-unknown/release/withdrawal.wasm --source-account default --network mainnet
	@echo "$(BLUE)Deploying campaign contract...$(NC)"
	soroban contract deploy --wasm target/wasm32-unknown-unknown/release/campaign.wasm --source-account default --network mainnet
	@echo "$(GREEN)Mainnet deployment complete!$(NC)"

fmt: ## Format all code
	@echo "$(BLUE)Formatting code...$(NC)"
	cargo fmt --all
	@echo "$(GREEN)Formatting complete!$(NC)"

lint: ## Run clippy linter
	@echo "$(BLUE)Running linter...$(NC)"
	cargo clippy --workspace -- -D warnings
	@echo "$(GREEN)Linting complete!$(NC)"

clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	cargo clean
	@echo "$(GREEN)Clean complete!$(NC)"

install-cli: ## Install Soroban CLI
	@echo "$(BLUE)Installing Soroban CLI...$(NC)"
	cargo install --locked soroban-cli
	@echo "$(GREEN)Soroban CLI installed!$(NC)"

# Development utilities
dev-setup: install-cli ## Setup development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@rustup target add wasm32-unknown-unknown
	@echo "$(GREEN)Development environment ready!$(NC)"
### Makefile for Stellar / Soroban contract development
# Usage:
#   make build           # build workspace
#   make wasm            # build contract WASM (package: $(CONTRACT_PKG))
#   make deploy          # deploy WASM using soroban CLI (requires `soroban`)
#   make fund ADDR=G...  # fund an address on testnet using Friendbot (curl)
#   make invoke FUNC=ping # invoke a function on deployed contract (requires CONTRACT_ID)
#   make test            # run cargo test
#   make fmt             # run cargo fmt
#   make lint            # run cargo clippy (strict)
#   make clean           # cargo clean

# --- Configuration ---
CONTRACT_PKG ?= stellaraid-core
WASM_TARGET ?= wasm32-unknown-unknown
RELEASE_FLAG ?= --release
NETWORK ?= testnet
WASM_FILE ?= target/$(WASM_TARGET)/release/$(CONTRACT_PKG).wasm
CONTRACT_ID_FILE ?= .contract_id

.PHONY: all help build wasm deploy fund invoke test fmt lint clean

all: build

help:
	@echo "Makefile targets:"
	@echo "  build           Build the entire workspace"
	@echo "  wasm            Build contract WASM for $(CONTRACT_PKG)"
	@echo "  deploy          Deploy $(WASM_FILE) to $(NETWORK) via soroban"
	@echo "  fund ADDR=...   Fund a testnet address using Friendbot"
	@echo "  invoke FUNC=... Invoke a method on deployed contract (set CONTRACT_ID or CONTRACT_ID_FILE)"
	@echo "  test            Run cargo test"
	@echo "  fmt             Run cargo fmt"
	@echo "  lint            Run cargo clippy"
	@echo "  clean           Run cargo clean"

build:
	cargo build --workspace

wasm:
	@which cargo >/dev/null 2>&1 || (echo "cargo not found"; exit 1)
	@rustup target add $(WASM_TARGET) >/dev/null 2>&1 || true
	cargo build -p $(CONTRACT_PKG) --target $(WASM_TARGET) $(RELEASE_FLAG)

deploy: wasm
	@command -v soroban >/dev/null 2>&1 || (echo "soroban CLI not found; install via 'cargo install soroban-cli'"; exit 1)
	@echo "Deploying $(WASM_FILE) to network=$(NETWORK)"
	@soroban contract deploy --wasm $(WASM_FILE) --network $(NETWORK) | tee $(CONTRACT_ID_FILE)
	@echo "Contract ID stored in $(CONTRACT_ID_FILE)"

fund:
	@if [ -z "$(ADDR)" ]; then echo "Usage: make fund ADDR=G..."; exit 1; fi
	@if [ "$(NETWORK)" != "testnet" ]; then echo "Friendbot only available on testnet/futurenet"; exit 1; fi
	@echo "Funding $(ADDR) via Friendbot"
	@curl -sS "https://friendbot.stellar.org/?addr=$(ADDR)" || true

invoke:
	@command -v soroban >/dev/null 2>&1 || (echo "soroban CLI not found; install via 'cargo install soroban-cli'"; exit 1)
	@if [ -z "$(FUNC)" ]; then echo "Usage: make invoke FUNC=<method> [CONTRACT_ID=<id>] [ARGS='arg1 arg2']"; exit 1; fi
	@CONTRACT_ID=$${CONTRACT_ID:-$$(cat $(CONTRACT_ID_FILE) 2>/dev/null || true)}; \
	if [ -z "$$CONTRACT_ID" ]; then echo "Contract ID not set and $(CONTRACT_ID_FILE) missing"; exit 1; fi; \
	ARGS=$${ARGS:-}; \
	set -x; soroban contract invoke --id "$$CONTRACT_ID" --network $(NETWORK) --fn $(FUNC) --args $$ARGS

test:
	cargo test --workspace

fmt:
	cargo fmt --all

lint:
	cargo clippy --all-targets --all-features -- -D warnings

clean:
	cargo clean

