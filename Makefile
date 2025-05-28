.DEFAULT_GOAL := help

SHELL := bash
PATH := $(CURDIR)/.dev/go-tools/bin:$(PATH)

# Release version: Update this version when releasing the project.
# The first part of the version is the version of the meilisearch-ui, the second part is the patch version of meilisearch-ui-server itself.
# For example, 0.12.2-0 means that the meilisearch-ui version is 0.12.2 and the patch version of meilisearch-ui-server is 0.
# You MUST update MEILISEARCH_UI_VERSION and VERSION in the above rule.
VERSION := "0.12.2-1"
# Meilisearch UI version: This is the version of the meilisearch-ui that will be built.
MEILISEARCH_UI_VERSION := "v0.12.2"
BUILD_LDFLAGS = "-s -w -X main.Version=$(VERSION)"

# Load .env file if it exists.
ifneq (,$(wildcard ./.env))
  include .env
  export
endif

.PHONY: help
help: ## Show help
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[/0-9a-zA-Z_-]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}'


# --------------------------------------------------------------------------------------
# Development environment
# --------------------------------------------------------------------------------------
.PHONY: setup
setup: ## Setup development environment
	@echo "==> Setting up development environment..."
	@mkdir -p $(CURDIR)/.dev/go-tools
	@export GOPATH=$(CURDIR)/.dev/go-tools && \
		go install honnef.co/go/tools/cmd/staticcheck@latest && \
		go install github.com/Songmu/goxz/cmd/goxz@latest && \
		go install github.com/tcnksm/ghr@latest && \
		go install github.com/axw/gocov/gocov@latest && \
		go install github.com/matm/gocov-html/cmd/gocov-html@latest
	@export GOPATH=$(CURDIR)/.dev/go-tools && go clean -modcache && rm -rf $(CURDIR)/.dev/go-tools/pkg

.PHONY: clean
clean: ## Clean up development environment
	@rm -rf .dev

.PHONY: clean/build
clean/build: ## Clean up build directory
	@rm -rf .dev/build


# --------------------------------------------------------------------------------------
# Testing, Formatting and etc.
# --------------------------------------------------------------------------------------
.PHONY: format
format: ## Format source code
	@go fmt ./...

.PHONY: lint
lint: ## Lint source code
	@staticcheck ./...

.PHONY: test
test: ## Run tests
	@go test -race -timeout 30m ./...

.PHONY: test/short
test/short: ## Run short tests
	@go test -short -race -timeout 30m ./...

.PHONY: test/verbos
test/verbose: ## Run tests with verbose outputting
	@go test -race -timeout 30m -v ./...

.PHONY: test/cover
test/cover: ## Run tests with coverage report
	@mkdir -p $(CURDIR)/.dev/test
	@go test -race -coverpkg=./... -coverprofile=$(CURDIR)/.dev/test/coverage.out ./...
	@gocov convert $(CURDIR)/.dev/test/coverage.out | gocov-html > $(CURDIR)/.dev/test/coverage.html

.PHONY: open/coverage
open/coverage: ## Open coverage report
	@open $(CURDIR)/.dev/test/coverage.html


# --------------------------------------------------------------------------------------
# Go commands
# --------------------------------------------------------------------------------------
.PHONY: go-generate
go-generate: ## Run go generate
	@go generate ./...

.PHONY: go-mod-tidy
go-mod-tidy: ## Run go mod tidy
	@go mod tidy

# --------------------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------------------
.PHONY: start
start: ## Start the server
	@go run . -debug

.PHONY: build-ui
build/ui: ## Build meilisearch-ui and copy the files to the dist directory
	@./scripts/build-meilisearch-ui.sh $(MEILISEARCH_UI_VERSION)

.PHONY: build
build: ## Build dev binary
	@mkdir -p .dev/build/dev
	@CGO_ENABLED=0 go build -ldflags=$(BUILD_LDFLAGS) -o .dev/build/dev/meilisearch-ui-server .

build/release: ## Build release binary
	@mkdir -p .dev/build/release
	@CGO_ENABLED=0 go build -ldflags=$(BUILD_LDFLAGS) -trimpath -o .dev/build/release/meilisearch-ui-server .

.PHONY: build/dist
build/dist: ## Build cross-platform binaries for distribution
	@mkdir -p .dev/build/dist
	@CGO_ENABLED=0 goxz -n meilisearch-ui-server -os=linux,darwin -static -build-ldflags=$(BUILD_LDFLAGS) -trimpath -d=.dev/build/dist .


# --------------------------------------------------------------------------------------
# Release
# --------------------------------------------------------------------------------------
.PHONY: release
release: guard-GITHUB_TOKEN ## Release the project with the specified version and tags it
	@$(MAKE) clean/build
	@$(MAKE) build/ui
	@$(MAKE) build/dist
	@ghr -n "v$(VERSION)" -b "Release v$(VERSION)" v$(VERSION) .dev/build/dist


# --------------------------------------------------------------------------------------
# Utilities
# --------------------------------------------------------------------------------------
# This is a utility for checking variable definition
guard-%:
	@if [[ -z '${${*}}' ]]; then echo 'ERROR: variable $* not set' && exit 1; fi
