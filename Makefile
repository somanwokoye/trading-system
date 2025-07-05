.PHONY: help setup dev build test lint docker-build deploy-dev clean

PROJECT_ID := trading-system-demo-464911
REGION := us-central1

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Initial project setup
	@echo "Setting up development environment..."
	go mod tidy
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install github.com/air-verse/air@latest
	@echo "✅ Setup complete"

dev: ## Start development with hot reload
	@echo "Starting development environment..."
	air -c .air.toml

build: ## Build all binaries
	@echo "Building binaries..."
	mkdir -p bin
	go build -o bin/pipeline ./cmd/market-pipeline
	go build -o bin/strategy ./cmd/strategy-engine
	go build -o bin/backtest ./cmd/backtest
	@echo "✅ Build complete"

test: ## Run tests
	go test -v -race ./...

test-coverage: ## Run tests with coverage
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "✅ Coverage report generated: coverage.html"

lint: ## Run linter
	golangci-lint run

docker-build: ## Build Docker images
	docker build -f deployments/docker/Dockerfile.pipeline -t gcr.io/$(PROJECT_ID)/trading-pipeline:latest .
	docker build -f deployments/docker/Dockerfile.strategy -t gcr.io/$(PROJECT_ID)/trading-strategy:latest .

docker-push: docker-build ## Push Docker images to GCR
	docker push gcr.io/$(PROJECT_ID)/trading-pipeline:latest
	docker push gcr.io/$(PROJECT_ID)/trading-strategy:latest

gcp-deploy: ## Deploy to Google Cloud Run
	gcloud run deploy trading-pipeline \
		--image gcr.io/$(PROJECT_ID)/trading-pipeline:latest \
		--platform managed \
		--region $(REGION) \
		--allow-unauthenticated

	gcloud run deploy trading-strategy \
		--image gcr.io/$(PROJECT_ID)/trading-strategy:latest \
		--platform managed \
		--region $(REGION) \
		--allow-unauthenticated

clean: ## Clean build artifacts
	rm -rf bin/
	rm -f coverage.out coverage.html
	docker system prune -f