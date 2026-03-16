.PHONY: app unit e2e down down-e2e clean build

build:
	docker compose build

app:
	docker compose up app

unit:
	docker compose --profile test run --rm unit-tests

e2e:
	docker compose --profile e2e up --abort-on-container-exit --exit-code-from e2e-tests e2e-tests

down:
	docker compose down

down-e2e:
	docker compose --profile e2e down

clean:
	docker compose --profile e2e down --volumes --remove-orphans
	docker compose down --volumes --remove-orphans
