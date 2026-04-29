SHELL := /bin/sh

.DEFAULT_GOAL := help

.PHONY: help build test clean fmt snapshot deploy-sepolia deploy-holesky deploy-custom anvil

help:
	@echo "Foundry commands"
	@echo "  make build           Compile contracts"
	@echo "  make test            Run Foundry tests"
	@echo "  make clean           Remove Foundry build artifacts"
	@echo "  make fmt             Format Solidity files"
	@echo "  make snapshot        Run gas snapshot"
	@echo ""
	@echo "Deployment"
	@echo "  make deploy-sepolia  Deploy Bank and Pool to Sepolia"
	@echo "  make deploy-holesky  Deploy Bank and Pool to Holesky"
	@echo "  make deploy-custom   Deploy Bank and Pool to CUSTOM_RPC_URL"
	@echo ""
	@echo "Local"
	@echo "  make anvil           Start a local Anvil chain"

build:
	forge build

test:
	forge test

clean:
	forge clean

fmt:
	forge fmt src test script

snapshot:
	forge snapshot

deploy-sepolia:
	sh script/deploy-foundry.sh sepolia

deploy-holesky:
	sh script/deploy-foundry.sh holesky

deploy-custom:
	sh script/deploy-foundry.sh custom

anvil:
	anvil
