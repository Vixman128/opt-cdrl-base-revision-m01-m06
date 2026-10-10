#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

PYTHON_BIN="${PYTHON:-python}"
if [[ -z "${PYTHON:-}" || "$PYTHON_BIN" == "python" || "$PYTHON_BIN" == "python3" ]]; then
    if [[ -f ".venv/Scripts/python.exe" ]]; then
        PYTHON_BIN=".venv/Scripts/python.exe"
    elif [[ -x ".venv/bin/python" ]]; then
        PYTHON_BIN=".venv/bin/python"
    elif command -v python >/dev/null 2>&1; then
        PYTHON_BIN="python"
    elif command -v python3 >/dev/null 2>&1; then
        PYTHON_BIN="python3"
    else
        echo "ERROR: no se encontro Python; activa o crea .venv." >&2
        exit 1
    fi
fi

mkdir -p artifacts evidence docs db/migrations db/seed src tests
test -f .env.example || { echo "ERROR: falta .env.example." >&2; exit 1; }

source scripts/load_env.sh
if [[ -f .env ]]; then
    load_env_file .env
elif [[ -z "${POSTGRES_PASSWORD:-}" ]]; then
    cp .env.example .env
    echo "Se creo .env desde .env.example. Define POSTGRES_PASSWORD y vuelve a ejecutar make setup." >&2
    exit 1
fi

if [[ -z "${POSTGRES_PASSWORD:-}" ]]; then
    echo "ERROR: define POSTGRES_PASSWORD en .env antes de preparar la base." >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker no esta disponible en PATH." >&2
    exit 1
fi

echo "Levantando PostgreSQL y DynamoDB Local..."
docker compose up -d --wait postgres dynamodb
docker compose ps

echo "Aplicando migraciones y seed idempotente..."
"$PYTHON_BIN" rebuild.py
echo "Setup completado."
