.PHONY: help test build up down lint template

IMAGE ?= hello-app:local
APP_VERSION ?= 1.0.0

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  %-12s %s\n", $$1, $$2}'

test: ## Run app unit tests
	cd app && npm test

build: ## Build the app image
	docker build --build-arg APP_VERSION=$(APP_VERSION) -t $(IMAGE) app

lint: ## Lint the Helm chart
	helm lint charts/hello-app

template: ## Render the Helm chart
	helm template hello-app charts/hello-app --set serviceMonitor.enabled=true

up: ## Create cluster + deploy app + monitoring
	./scripts/cluster-up.sh

down: ## Delete the cluster
	./scripts/cluster-down.sh
