.PHONY: help setup dev build test test-coverage lint docker-build docker-push deploy-preview deploy-staging deploy-prod deploy-branch cleanup-preview gcp-deploy clean status

PROJECT_ID := trading-system-demo-464911
REGION := us-central1
BRANCH := $(shell git branch --show-current 2>/dev/null || echo "unknown")
COMMIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo "dev")

# Determine environment and image tags based on branch
ifeq ($(BRANCH),master)
    ENV := prod
    IMAGE_TAG := prod-$(COMMIT_SHA)
    SERVICE_SUFFIX :=
else ifeq ($(BRANCH),develop)
    ENV := staging
    IMAGE_TAG := staging-$(COMMIT_SHA)
    SERVICE_SUFFIX := -staging
else
    ENV := dev
    IMAGE_TAG := dev-$(COMMIT_SHA)
    SERVICE_SUFFIX := -dev
endif

# PR-specific variables (set by GitHub Actions)
ifdef PR_NUMBER
    ENV := preview
    IMAGE_TAG := pr-$(PR_NUMBER)-$(COMMIT_SHA)
    SERVICE_SUFFIX := -pr-$(PR_NUMBER)
endif

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Initial project setup
	@echo "Setting up development environment..."
	go mod tidy
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install github.com/air-verse/air@latest
	@echo "✅ Setup complete for $(BRANCH) branch ($(ENV) environment)"

dev: ## Start development with hot reload
	@echo "Starting development environment for $(ENV)..."
	ENV=$(ENV) air -c .air.toml

build: ## Build all binaries
	@echo "Building binaries for $(ENV) environment..."
	mkdir -p bin
	CGO_ENABLED=0 go build -ldflags="-X main.Version=$(IMAGE_TAG) -X main.Environment=$(ENV)" -o bin/pipeline ./cmd/market-pipeline
	CGO_ENABLED=0 go build -ldflags="-X main.Version=$(IMAGE_TAG) -X main.Environment=$(ENV)" -o bin/strategy ./cmd/strategy-engine
	CGO_ENABLED=0 go build -ldflags="-X main.Version=$(IMAGE_TAG) -X main.Environment=$(ENV)" -o bin/backtest ./cmd/backtest
	@echo "✅ Build complete"

test: ## Run tests
	@echo "Running tests..."
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -func=coverage.out

test-coverage: ## Run tests with coverage
	@echo "Generating coverage report..."
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "✅ Coverage report generated: coverage.html"

lint: ## Run linter
	@echo "Running linter..."
	golangci-lint run
	@echo "✅ Linting complete"

docker-build: ## Build Docker images
	@echo "Building Docker images for $(ENV) environment..."
	docker build -f deployments/docker/Dockerfile.pipeline \
		-t gcr.io/$(PROJECT_ID)/trading-pipeline:$(IMAGE_TAG) \
		-t gcr.io/$(PROJECT_ID)/trading-pipeline:latest-$(ENV) .
	docker build -f deployments/docker/Dockerfile.strategy \
		-t gcr.io/$(PROJECT_ID)/trading-strategy:$(IMAGE_TAG) \
		-t gcr.io/$(PROJECT_ID)/trading-strategy:latest-$(ENV) .
	@echo "✅ Docker build complete"

docker-push: docker-build ## Push Docker images to GCR
	@echo "Pushing Docker images..."
	docker push gcr.io/$(PROJECT_ID)/trading-pipeline:$(IMAGE_TAG)
	docker push gcr.io/$(PROJECT_ID)/trading-pipeline:latest-$(ENV)
	docker push gcr.io/$(PROJECT_ID)/trading-strategy:$(IMAGE_TAG)
	docker push gcr.io/$(PROJECT_ID)/trading-strategy:latest-$(ENV)
	@echo "✅ Docker push complete"

deploy-preview: ## Deploy to preview environment (for PRs)
	@echo "Deploying to preview environment..."
	gcloud run deploy trading-pipeline$(SERVICE_SUFFIX) \
		--image gcr.io/$(PROJECT_ID)/trading-pipeline:$(IMAGE_TAG) \
		--platform managed \
		--region $(REGION) \
		--allow-unauthenticated \
		--set-env-vars="ENV=$(ENV),VERSION=$(IMAGE_TAG)" \
		--max-instances=2 \
		--memory=512Mi
	gcloud run deploy trading-strategy$(SERVICE_SUFFIX) \
		--image gcr.io/$(PROJECT_ID)/trading-strategy:$(IMAGE_TAG) \
		--platform managed \
		--region $(REGION) \
		--allow-unauthenticated \
		--set-env-vars="ENV=$(ENV),VERSION=$(IMAGE_TAG)" \
		--max-instances=2 \
		--memory=512Mi
	@echo "✅ Preview deployment complete"

deploy-staging: ## Deploy to staging environment
	@echo "Deploying to staging environment..."
	gcloud run deploy trading-pipeline-staging \
		--image gcr.io/$(PROJECT_ID)/trading-pipeline:latest-staging \
		--platform managed \
		--region $(REGION) \
		--allow-unauthenticated \
		--set-env-vars="ENV=staging" \
		--min-instances=1 \
		--max-instances=5 \
		--cpu=1 \
		--memory=1Gi
	gcloud run deploy trading-strategy-staging \
		--image gcr.io/$(PROJECT_ID)/trading-strategy:latest-staging \
		--platform managed \
		--region $(REGION) \
		--allow-unauthenticated \
		--set-env-vars="ENV=staging" \
		--min-instances=1 \
		--max-instances=5 \
		--cpu=1 \
		--memory=1Gi
	@echo "✅ Staging deployment complete"

deploy-prod: ## Deploy to production environment
	@echo "Deploying to production environment..."
	gcloud run deploy trading-pipeline \
		--image gcr.io/$(PROJECT_ID)/trading-pipeline:latest-prod \
		--platform managed \
		--region $(REGION) \
		--allow-unauthenticated \
		--set-env-vars="ENV=production" \
		--min-instances=1 \
		--max-instances=10 \
		--cpu=2 \
		--memory=1Gi
	gcloud run deploy trading-strategy \
		--image gcr.io/$(PROJECT_ID)/trading-strategy:latest-prod \
		--platform managed \
		--region $(REGION) \
		--allow-unauthenticated \
		--set-env-vars="ENV=production" \
		--min-instances=1 \
		--max-instances=10 \
		--cpu=2 \
		--memory=1Gi
	@echo "✅ Production deployment complete"

deploy-branch: docker-push ## Deploy to environment based on current branch
	@echo "Deploying based on branch: $(BRANCH) -> $(ENV) environment"
	@if [ "$(ENV)" = "prod" ]; then \
		$(MAKE) deploy-prod; \
	elif [ "$(ENV)" = "staging" ]; then \
		$(MAKE) deploy-staging; \
	elif [ "$(ENV)" = "preview" ]; then \
		$(MAKE) deploy-preview; \
	else \
		echo "Development environment - use 'make dev' for local development"; \
	fi

cleanup-preview: ## Cleanup preview environment
	@echo "Cleaning up preview environment..."
	@if [ -n "$(PR_NUMBER)" ]; then \
		gcloud run services delete trading-pipeline-pr-$(PR_NUMBER) --region=$(REGION) --quiet || true; \
		gcloud run services delete trading-strategy-pr-$(PR_NUMBER) --region=$(REGION) --quiet || true; \
		echo "✅ Cleanup complete for PR $(PR_NUMBER)"; \
	else \
		echo "❌ PR_NUMBER not set - cannot cleanup"; \
	fi

auth-docker: ## Configure Docker authentication for GCR
	gcloud auth configure-docker gcr.io

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
	@echo "Cleaning build artifacts..."
	rm -rf bin/
	rm -f coverage.out coverage.html
	docker system prune -f
	@echo "✅ Clean complete"

status: ## Show current build context
	@echo "=== Build Context ==="
	@echo "Branch: $(BRANCH)"
	@echo "Environment: $(ENV)"
	@echo "Image Tag: $(IMAGE_TAG)"
	@echo "Service Suffix: $(SERVICE_SUFFIX)"
	@echo "Project: $(PROJECT_ID)"
	@echo "Region: $(REGION)"
	@echo "Commit: $(COMMIT_SHA)"

# Quality gates that must pass before deployment
quality-gate: test lint ## Run all quality checks
	@echo "✅ All quality gates passed"

# Full CI/CD pipeline simulation
ci-pipeline: setup quality-gate build docker-build ## Simulate full CI pipeline locally
	@echo "✅ CI pipeline simulation complete"
