.PHONY: app unit e2e down down-e2e clean build local-bootstrap local-build local-docs local-docs-project

STACK_LOCAL ?= stack.local.yaml

build:
	docker compose build

app:
	docker compose up app

unit:
	docker compose --profile test run --rm unit-tests

e2e:
	docker compose --profile e2e up --build --abort-on-container-exit --exit-code-from e2e-tests e2e-tests

down:
	docker compose down

down-e2e:
	docker compose --profile e2e down

clean:
	docker compose --profile e2e down --volumes --remove-orphans
	docker compose down --volumes --remove-orphans

local-bootstrap:
	stack --stack-yaml $(STACK_LOCAL) build polysemy-plugin

local-build: local-bootstrap
	stack --stack-yaml $(STACK_LOCAL) build

local-docs: local-bootstrap
	stack --stack-yaml $(STACK_LOCAL) build --haddock --haddock-deps

local-docs-project: local-bootstrap
	stack --stack-yaml $(STACK_LOCAL) build --haddock --no-haddock-deps
