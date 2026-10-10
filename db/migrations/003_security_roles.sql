-- CDRL M03: separación de roles, vista segura y privilegio mínimo.
-- Requiere 001_schema.sql y 002_relational_model.sql.
-- Ejecutar mediante rebuild.py con el usuario administrativo de la base.

DO $$
DECLARE
    role_name TEXT;
BEGIN
    FOREACH role_name IN ARRAY ARRAY[
        'cdrl_migrator',
        'cdrl_writer',
        'cdrl_reader',
        'cdrl_operator'
    ]
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
            EXECUTE format(
                'CREATE ROLE %I WITH NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS',
                role_name
            );
        ELSE
            EXECUTE format(
                'ALTER ROLE %I WITH NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS',
                role_name
            );
        END IF;
    END LOOP;
END
$$;

-- Vista de operación deliberadamente acotada: identifica dispositivo,
-- estado y ubicación; no expone lecturas, coordenadas ni métricas ambientales.
CREATE OR REPLACE VIEW public.v_device_operational_status AS
SELECT
    d.id AS device_id,
    d.device_code,
    d.status AS device_status,
    l.location_code
FROM public.devices AS d
JOIN public.locations AS l ON l.id = d.location_id;

COMMENT ON VIEW public.v_device_operational_status IS
    'Vista de solo lectura para consultar estado operativo; excluye telemetría, nombres y coordenadas.';

-- Se revocan los permisos anteriores, incluido el acceso directo a la vista
-- amplia de M02 y a las tablas que contienen datos de ubicación/telemetría.
REVOKE ALL PRIVILEGES ON SCHEMA public FROM PUBLIC;
REVOKE ALL PRIVILEGES ON SCHEMA public
    FROM cdrl_migrator, cdrl_writer, cdrl_reader, cdrl_operator;
GRANT USAGE ON SCHEMA public
    TO cdrl_migrator, cdrl_writer, cdrl_reader, cdrl_operator;
GRANT CREATE ON SCHEMA public TO cdrl_migrator;

REVOKE ALL PRIVILEGES ON TABLE
    public.locations,
    public.devices,
    public.telemetry_readings,
    public.v_telemetry_context,
    public.v_device_operational_status
FROM PUBLIC, cdrl_migrator, cdrl_writer, cdrl_reader, cdrl_operator;

-- Reader y operator consultan únicamente la vista de operación segura.
GRANT SELECT ON TABLE public.v_device_operational_status
    TO cdrl_reader, cdrl_operator;

-- Writer puede insertar lecturas, pero no consultarlas ni modificar/borrar.
GRANT INSERT ON TABLE public.telemetry_readings TO cdrl_writer;

-- La identidad requiere USAGE de secuencia para INSERT; no se otorga SELECT.
DO $$
DECLARE
    sequence_name REGCLASS;
BEGIN
    SELECT pg_get_serial_sequence(
        'public.telemetry_readings', 'id'
    )::REGCLASS INTO sequence_name;

    IF sequence_name IS NULL THEN
        RAISE EXCEPTION 'No se encontro la secuencia identity de telemetry_readings.id';
    END IF;

    EXECUTE format(
        'REVOKE ALL PRIVILEGES ON SEQUENCE %s FROM PUBLIC, cdrl_migrator, cdrl_writer, cdrl_reader, cdrl_operator',
        sequence_name
    );
    EXECUTE format(
        'GRANT USAGE ON SEQUENCE %s TO cdrl_writer',
        sequence_name
    );
END
$$;

-- Los objetos nuevos permanecen privados para su propietario. La regla se
-- instala para el rol de migración y para quien ejecuta rebuild.py, de modo
-- que futuras migraciones no concedan acceso accidental a PUBLIC.
DO $$
DECLARE
    migration_role TEXT := current_user;
BEGIN
    EXECUTE format(
        'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC',
        migration_role
    );
    EXECUTE format(
        'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC',
        migration_role
    );
    EXECUTE format(
        'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC',
        migration_role
    );

    EXECUTE 'ALTER DEFAULT PRIVILEGES FOR ROLE cdrl_migrator IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC';
    EXECUTE 'ALTER DEFAULT PRIVILEGES FOR ROLE cdrl_migrator IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC';
    EXECUTE 'ALTER DEFAULT PRIVILEGES FOR ROLE cdrl_migrator IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC';
END
$$;

-- Migrator mantiene propiedad estructural; los demás roles no son propietarios.
ALTER TABLE public.locations OWNER TO cdrl_migrator;
ALTER TABLE public.devices OWNER TO cdrl_migrator;
ALTER TABLE public.telemetry_readings OWNER TO cdrl_migrator;
ALTER VIEW public.v_telemetry_context OWNER TO cdrl_migrator;
ALTER VIEW public.v_device_operational_status OWNER TO cdrl_migrator;

DO $$
DECLARE
    sequence_name REGCLASS;
BEGIN
    SELECT pg_get_serial_sequence(
        'public.telemetry_readings', 'id'
    )::REGCLASS INTO sequence_name;

    IF sequence_name IS NULL THEN
        RAISE EXCEPTION 'No se encontro la secuencia identity de telemetry_readings.id';
    END IF;

    EXECUTE format('ALTER SEQUENCE %s OWNER TO cdrl_migrator', sequence_name);
END
$$;
