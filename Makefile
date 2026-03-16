.PHONY: help check-deps cluster keycloak all clean

# Load environment variables if .env exists
-include .env
export

ENV ?= dev
DOMAIN ?= example.com

help: ## Show this help menu
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033