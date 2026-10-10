from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import uuid4

import pytest
from psycopg2 import errors, sql

from rebuild import get_connection


@pytest.fixture
def security_context():
    """Datos sintéticos aislados; cada prueba termina con ROLLBACK."""
    conn = get_connection()
    cur = conn.cursor()
    suffix = uuid4().hex[:10]
    location_code = f"M03-LOC-{suffix}"
    device_code = f"M03-DEV-{suffix}"

    try:
        cur.execute(
            """
            INSERT INTO public.locations (location_code, name, latitude, longitude)
            VALUES (%s, %s, %s, %s)
            RETURNING id
            """,
            (location_code, "Synthetic test location", Decimal("20"), Decimal("-98")),
        )
        location_id = cur.fetchone()[0]
        cur.execute(
            """
            INSERT INTO public.devices
                (location_id, device_code, name, status, installed_at)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id
            """,
            (
                location_id,
                device_code,
                "Synthetic test device",
                "active",
                datetime(2026, 9, 19, 10, tzinfo=timezone.utc),
            ),
        )
        device_id = cur.fetchone()[0]

        yield {
            "conn": conn,
            "cur": cur,
            "device_id": device_id,
            "device_code": device_code,
            "location_code": location_code,
        }
    finally:
        try:
            cur.execute("RESET ROLE")
        except Exception:
            conn.rollback()
        conn.rollback()
        cur.close()
        conn.close()


def _insert_reading(cur, device_id):
    recorded_at = datetime(2026, 9, 19, 12, tzinfo=timezone.utc)
    cur.execute(
        """
        INSERT INTO public.telemetry_readings
            (device_id, recorded_at, received_at,
             temperature_c, humidity_pct, co2_ppm)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (
            device_id,
            recorded_at,
            recorded_at + timedelta(seconds=1),
            Decimal("25.00"),
            Decimal("50.00"),
            Decimal("500.00"),
        ),
    )


def test_reader_can_query_only_safe_operational_view(security_context):
    cur = security_context["cur"]
    cur.execute("SET ROLE cdrl_reader")
    cur.execute(
        """
        SELECT device_code, device_status, location_code
        FROM public.v_device_operational_status
        WHERE device_id = %s
        """,
        (security_context["device_id"],),
    )
    assert cur.fetchall() == [
        (
            security_context["device_code"],
            "active",
            security_context["location_code"],
        )
    ]


def test_operator_can_query_only_safe_operational_view(security_context):
    cur = security_context["cur"]
    cur.execute("SET ROLE cdrl_operator")
    cur.execute(
        """
        SELECT device_code, device_status, location_code
        FROM public.v_device_operational_status
        WHERE device_id = %s
        """,
        (security_context["device_id"],),
    )
    assert cur.fetchall() == [
        (
            security_context["device_code"],
            "active",
            security_context["location_code"],
        )
    ]


def test_writer_can_insert_without_reading_telemetry(security_context):
    cur = security_context["cur"]
    cur.execute("SET ROLE cdrl_writer")
    _insert_reading(cur, security_context["device_id"])
    assert cur.rowcount == 1


def test_reader_cannot_query_sensitive_telemetry_context(security_context):
    cur = security_context["cur"]
    cur.execute("SET ROLE cdrl_reader")
    with pytest.raises(errors.InsufficientPrivilege) as exc:
        cur.execute("SELECT * FROM public.v_telemetry_context LIMIT 1")
    assert exc.value.pgcode == "42501"


def test_reader_cannot_insert_telemetry(security_context):
    cur = security_context["cur"]
    cur.execute("SET ROLE cdrl_reader")
    with pytest.raises(errors.InsufficientPrivilege) as exc:
        _insert_reading(cur, security_context["device_id"])
    assert exc.value.pgcode == "42501"


def test_operator_cannot_read_raw_telemetry(security_context):
    cur = security_context["cur"]
    cur.execute("SET ROLE cdrl_operator")
    with pytest.raises(errors.InsufficientPrivilege) as exc:
        cur.execute(
            "SELECT temperature_c FROM public.telemetry_readings LIMIT 1"
        )
    assert exc.value.pgcode == "42501"


def test_operator_cannot_modify_devices(security_context):
    cur = security_context["cur"]
    cur.execute("SET ROLE cdrl_operator")
    with pytest.raises(errors.InsufficientPrivilege) as exc:
        cur.execute(
            "UPDATE public.devices SET status = 'maintenance' WHERE id = %s",
            (security_context["device_id"],),
        )
    assert exc.value.pgcode == "42501"


def test_new_objects_created_by_migrator_are_private_by_default(security_context):
    cur = security_context["cur"]
    table_name = f"m03_default_acl_{uuid4().hex[:12]}"
    cur.execute("SET ROLE cdrl_migrator")
    cur.execute(
        sql.SQL("CREATE TABLE public.{} (id integer)").format(
            sql.Identifier(table_name)
        )
    )
    cur.execute("RESET ROLE")

    cur.execute(
        """
        SELECT
            has_table_privilege('cdrl_reader', to_regclass(%s), 'SELECT'),
            has_table_privilege('cdrl_writer', to_regclass(%s), 'SELECT'),
            has_table_privilege('cdrl_operator', to_regclass(%s), 'SELECT')
        """,
        (f"public.{table_name}",) * 3,
    )
    assert cur.fetchone() == (False, False, False)
