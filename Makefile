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

# Test Infrastructure
test-setup: ## Set up test infrastructure
	@echo "Setting up test infrastructure..."
	docker-compose -f docker-compose.test.yml up -d
	@echo "Waiting for services to be ready..."
	sleep 10
	@echo "✅ Test infrastructure ready"

test-teardown: ## Tear down test infrastructure
	@echo "Tearing down test infrastructure..."
	docker-compose -f docker-compose.test.yml down -v
	@echo "✅ Test infrastructure cleaned up"

# Mock Generation
generate-mocks: ## Generate mocks for testing
	@echo "Generating mocks..."
	go generate ./...
	mockgen -source=pkg/client/websocket.go -destination=test/mocks/mock_websocket_client.go
	mockgen -source=internal/storage/interface.go -destination=test/mocks/mock_storage.go
	@echo "✅ Mocks generated"

# Test Data Management
load-test-data: ## Load test data into test database
	@echo "Loading test data..."
	./scripts/load_test_data.sh
	@echo "✅ Test data loaded"

test-unit: ## Run unit tests
	@echo "Running unit tests..."
	go test -short -v -coverprofile=coverage.out ./...
	@echo "✅ Unit tests complete"

test-integration: ## Run integration tests
	@echo "Running integration tests..."
	go test -tags=integration -v ./...
	$(MAKE) test-teardown
	@echo "✅ Integration tests complete"

test-race: ## Test for race conditions
	@echo "Testing for race conditions..."
	go test -race -short ./...
	@echo "✅ Race condition tests complete"

test-performance: ## Run performance tests
	@echo "Running performance benchmarks..."
	go test -bench=. -benchmem -benchtime=10s ./...
	@echo "✅ Performance tests complete"

test-load: ## Run load tests
	@echo "Running load tests..."
	./scripts/benchmark.sh
	@echo "✅ Load tests complete"

test-coverage: test-unit ## Generate detailed coverage report
	@echo "Generating coverage report..."
	go tool cover -html=coverage.out -o coverage.html
	@coverage=$$(go tool cover -func=coverage.out | grep total | awk '{print $$3}' | sed 's/%//'); \
	echo "Coverage: $$coverage%"
	@echo "✅ Coverage report: coverage.html"

test-all: test-unit test-integration test-race ## Run all tests
	@echo "✅ All tests passed"

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

# Quality Gates with Coverage Requirements
quality-gate: test-unit test-race lint ## All quality checks must pass
	@echo "Checking coverage requirements..."
	@coverage=$$(go tool cover -func=coverage.out | grep total | awk '{print $$3}' | sed 's/%//'); \
	if [ $$(echo "$$coverage < 80" | bc -l) -eq 1 ]; then \
		echo "❌ Coverage $$coverage% is below 80% requirement"; \
		exit 1; \
	else \
		echo "✅ Coverage $$coverage% meets requirements"; \
	fi
	@echo "✅ All quality gates passed"

# Test Development Helpers
test-watch: ## Watch files and run tests on changes
	@echo "Watching for changes..."
	find . -name "*.go" | entr -c make test-unit

test-debug: ## Run tests with debugging information
	go test -v -gcflags="all=-N -l" ./...

test-profile: ## Run tests with CPU profiling
	go test -cpuprofile=cpu.prof -memprofile=mem.prof -bench=. ./...
	go tool pprof cpu.prof

# Full CI/CD pipeline simulation
ci-pipeline: setup quality-gate build docker-build ## Simulate full CI pipeline locally
	@echo "✅ CI pipeline simulation complete"
