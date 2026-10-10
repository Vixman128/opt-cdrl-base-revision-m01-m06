.PHONY: setup verify run queries

PYTHON ?= python

# Prepara los servicios y reconstruye el esquema/seed desde el repositorio.
setup:
	@PYTHON="$(PYTHON)" bash scripts/setup.sh

# Ejecuta toda la suite contra la base preparada por `make setup`.
verify:
	@PYTHON="$(PYTHON)" bash scripts/verify_all.sh

run:
	@docker compose up

queries:
	@$(PYTHON) -m db.queries.demo
