default:
	@echo "Please choose one of: init, fmt, validate, plan, apply, or destroy"

init:
	docker compose run --rm shared-iac init

fmt:
	docker compose run --rm shared-iac fmt

validate:
	docker compose run --rm shared-iac validate

plan:
	docker compose run --rm shared-iac plan 

apply:
	docker compose run --rm shared-iac apply 

destroy:
	docker compose run --rm shared-iac destroy 