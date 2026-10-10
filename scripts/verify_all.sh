#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

source scripts/load_env.sh
load_env_file .env

if [[ -z "${POSTGRES_PASSWORD:-}" ]]; then
    echo "ERROR: .env debe definir POSTGRES_PASSWORD; ejecuta make setup primero." >&2
    exit 1
fi

export PYTHON="${PYTHON:-python}"

for verifier in \
    scripts/verify_base.sh \
    scripts/verify_m02.sh \
    scripts/verify_m03.sh \
    scripts/verify_m04.sh \
    scripts/verify_m05.sh
do
    bash "$verifier"
done

echo "Verificacion integrada M01-M05 completada."
