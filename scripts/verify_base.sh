#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

PYTHON_BIN="${PYTHON:-python}"
TEST_REPORT="artifacts/m01-tests.json"
VERIFY_REPORT="artifacts/base-verify.json"

required_files=(
  ".env.example"
  "Makefile"
  "docker-compose.yml"
  "docs/ADR-000-starter-base.md"
  "evidence/m01-data-contract.json"
  ".github/workflows/cdrl-feedback.yml"
  "db/migrations/001_schema.sql"
  "db/seed/seed.py"
  "rebuild.py"
  "tests/test_telemetry_contract.py"
)

for required in "${required_files[@]}"; do
  test -f "$required" || { echo "missing required file: $required" >&2; exit 1; }
done

docker compose config --quiet
mkdir -p artifacts
rm -f -- "$TEST_REPORT" "$VERIFY_REPORT"

echo "Ejecutando las cuatro pruebas del contrato M01 contra PostgreSQL..."
"$PYTHON_BIN" -m pytest \
  tests/test_telemetry_contract.py \
  -v \
  --tb=short \
  --json-report \
  --json-report-file="$TEST_REPORT"

"$PYTHON_BIN" - "$TEST_REPORT" "$VERIFY_REPORT" <<'PY'
import json
import sys
from pathlib import Path

test_report_path = Path(sys.argv[1])
verify_report_path = Path(sys.argv[2])
report = json.loads(test_report_path.read_text(encoding="utf-8"))
tests = report.get("tests", [])
expected = {
    "tests/test_telemetry_contract.py::test_normal_reading_is_accepted",
    "tests/test_telemetry_contract.py::test_lower_temperature_boundary_is_accepted",
    "tests/test_telemetry_contract.py::test_upper_co2_boundary_is_accepted",
    "tests/test_telemetry_contract.py::test_humidity_above_maximum_is_rejected",
}
passed = {test.get("nodeid") for test in tests if test.get("outcome") == "passed"}
summary = report.get("summary", {})

if report.get("exitcode") != 0 or len(tests) != 4 or passed != expected:
    raise SystemExit("M01 requiere exactamente sus cuatro escenarios aprobados.")
if summary.get("failed", 0) or summary.get("error", 0):
    raise SystemExit("El reporte M01 contiene pruebas fallidas o errores.")

verify_report_path.write_text(
    json.dumps(
        {
            "status": "passed",
            "scope": "repository_contract_and_m01_database_tests",
            "databasePreparation": "make setup",
            "tests": {
                "status": "passed",
                "total": len(tests),
                "passed": len(passed),
                "failed": 0,
                "report": str(test_report_path).replace("\\", "/"),
            },
            "nextMilestone": "m02-relational-model",
        },
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)
print(f"M01: {len(passed)}/4 pruebas aprobadas; detalle en {test_report_path}.")
PY

echo "Verificación de M01 completada."
