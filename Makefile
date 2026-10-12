# Puzzle Hub — developer entry points. Run `make help`.
SHELL := /bin/bash
COMPOSE := docker compose -f infra/docker-compose.yml

.PHONY: help up up-obs down logs backend-test backend-run app-test app-run content-sync content-check lint tf-validate smoke

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-15s\033[0m %s\n",$$1,$$2}'

up: content-sync ## Start Postgres + API (http://localhost:8080)
	$(COMPOSE) up -d --build

up-obs: content-sync ## Start stack + Prometheus (9090) + Grafana (3000)
	$(COMPOSE) --profile observability up -d --build

down: ## Stop the local stack (keeps the DB volume)
	$(COMPOSE) --profile observability down

logs: ## Tail API logs
	$(COMPOSE) logs -f backend

backend-test: ## Backend unit + integration tests (needs Docker for Testcontainers)
	cd backend && ./mvnw -B -ntp verify

backend-run: ## Run the API from source against the compose Postgres
	$(COMPOSE) up -d postgres
	cd backend && SPRING_PROFILES_ACTIVE=dev ./mvnw -ntp spring-boot:run

app-test: ## Flutter analyze + tests
	cd app && flutter pub get && flutter analyze && flutter test

app-run: ## Run the app (pass DEVICE=<id>, API=<url>)
	cd app && flutter run $(if $(DEVICE),-d $(DEVICE)) --dart-define=API_BASE_URL=$(or $(API),http://10.0.2.2:8080)

content-sync: ## Copy shared puzzle content into app + backend
	scripts/sync-content.sh

content-check: ## Fail if app/backend content drifted from content/
	scripts/sync-content.sh --check

lint: content-check tf-validate ## All static checks
	cd app && dart format --output=none --set-exit-if-changed lib test && flutter analyze
	cd backend && ./mvnw -B -ntp -q -DskipTests verify
	@command -v actionlint >/dev/null && actionlint || echo "actionlint not installed - skipped"

tf-validate: ## terraform fmt + validate (no AWS credentials needed)
	terraform -chdir=infra/terraform fmt -check -recursive
	@for d in envs/staging envs/prod bootstrap; do \
	  terraform -chdir=infra/terraform/$$d init -backend=false -input=false >/dev/null && \
	  terraform -chdir=infra/terraform/$$d validate || exit 1; done

smoke: ## Smoke-test an API (URL=https://...)
	scripts/smoke-test.sh $(or $(URL),http://localhost:8080)
