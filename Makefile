.PHONY: app unit integration e2e down down-e2e down-integration clean build local-bootstrap local-build local-docs local-docs-project local-test local-test-integration local-test-e2e

STACK_LOCAL ?= stack.local.yaml

build:
	docker compose build

app:
	docker compose up app

unit:
	docker compose --profile test run --build --rm unit-tests

integration:
	docker compose --profile integration up --build --abort-on-container-exit --exit-code-from integration-tests integration-tests

e2e:
	docker compose --profile e2e up --build --abort-on-container-exit --exit-code-from e2e-tests e2e-tests

down:
	docker compose down

down-e2e:
	docker compose --profile e2e down

down-integration:
	docker compose --profile integration down

clean:
	docker compose --profile e2e down --volumes --remove-orphans
	docker compose --profile integration down --volumes --remove-orphans
	docker compose down --volumes --remove-orphans

local-bootstrap:
	stack --stack-yaml $(STACK_LOCAL) build polysemy-plugin

local-build: local-bootstrap
	stack --stack-yaml $(STACK_LOCAL) build

local-docs: local-bootstrap
	stack --stack-yaml $(STACK_LOCAL) build --haddock --haddock-deps

local-docs-project: local-bootstrap
	stack --stack-yaml $(STACK_LOCAL) build --haddock --no-haddock-deps

local-test: local-bootstrap
	stack --stack-yaml $(STACK_LOCAL) test tp0:test:tp0-test

local-test-integration: local-bootstrap
	stack --stack-yaml $(STACK_LOCAL) test tp0:test:tp0-integration --no-run-tests

local-test-e2e: local-bootstrap
	# this target is meant for typechecking the E2E tests, not for running them, 
	# since they require the server to be running and the test environment to be set up
	stack --stack-yaml $(STACK_LOCAL) test tp0:exe:tp0-e2e --no-run-tests