# ADR-003: Seguridad relacional y mínimo privilegio

## Estado

Aceptado.

## Contexto

M03 separa las capacidades de migración, escritura, lectura y operación. La revisión de la entrega encontró que `cdrl_reader` y `cdrl_operator` podían leer telemetría, que `cdrl_operator` podía modificar dispositivos y que no había una política explícita para objetos futuros.

## Decisión

Se conservan cuatro roles `NOLOGIN`, usados como conjuntos de privilegios:

| Rol | Permiso |
| --- | --- |
| `cdrl_migrator` | `USAGE` y `CREATE` en `public`; propietario estructural de las tablas, secuencias y vistas. |
| `cdrl_writer` | `INSERT` en `telemetry_readings` y `USAGE` en su secuencia de identidad. No puede leer las lecturas. |
| `cdrl_reader` | `SELECT` únicamente en `v_device_operational_status`. |
| `cdrl_operator` | `SELECT` únicamente en `v_device_operational_status`; no puede modificar dispositivos. |

`v_device_operational_status` expone `device_id`, `device_code`, `device_status` y `location_code`. No presenta lecturas, valores ambientales, coordenadas ni nombres. La vista amplia `v_telemetry_context` permanece para las consultas de M02, pero M03 no concede acceso a ella ni a las tablas subyacentes.

La migración primero revoca privilegios anteriores en el esquema y en los objetos relacionales; después concede solamente los permisos enumerados. Los roles de lectura y operación no reciben acceso directo a `locations`, `devices`, `telemetry_readings` ni `v_telemetry_context`.

### Objetos futuros

La migración instala `ALTER DEFAULT PRIVILEGES` para el usuario que ejecuta las migraciones y para `cdrl_migrator`. Las tablas y secuencias nuevas no reciben permisos de `PUBLIC`; las funciones nuevas tampoco reciben `EXECUTE` para `PUBLIC`. Un objeto futuro requiere una concesión explícita y revisada para cada rol.

### Secretos

`POSTGRES_PASSWORD` se recibe desde `.env` local o del entorno de CI. `.env` no se versiona y `.env.example` solo documenta las variables. No hay contraseña alternativa en código.

## Verificación

`make setup` inicia PostgreSQL y DynamoDB Local, espera PostgreSQL, aplica migraciones y ejecuta el seed. Repetirlo comprueba la idempotencia del proceso. `make verify` ejecuta:

1. Las cuatro pruebas del contrato M01.
2. Las ocho pruebas de invariantes y las cuatro pruebas de aceptación de M02.
3. Ocho escenarios de M03: tres permisos permitidos, las cuatro denegaciones siguientes y una comprobación de privilegios predeterminados.
4. Las verificaciones de M04 y M05.

Las cuatro denegaciones M03 verifican `InsufficientPrivilege` y SQLSTATE `42501`:

1. `cdrl_reader` no puede consultar la vista amplia de telemetría de M02.
2. `cdrl_reader` no puede insertar lecturas.
3. `cdrl_operator` no puede consultar la tabla de telemetría.
4. `cdrl_operator` no puede actualizar dispositivos.

Los datos de prueba son sintéticos y cada prueba revierte su transacción. Los resultados detallados de pytest se generan en `artifacts/m01-tests.json`, `artifacts/m02-relational-results.json` y `artifacts/m03-security-results.json`.

## Consecuencias

- La telemetría no se expone a los roles de lectura y operación.
- Las consultas operativas muestran solo los campos necesarios.
- El writer puede agregar lecturas sin permiso para consultarlas.
- Una futura tabla, secuencia o función no se vuelve pública por omisión.
- Cualquier permiso requerido para un objeto nuevo debe incluirse de manera explícita y probarse.

## Limitaciones

Los roles `NOLOGIN` se prueban mediante `SET ROLE` desde una conexión administrativa. No se configuran identidades de aplicación ni autenticación externa por rol. Las verificaciones requieren PostgreSQL disponible y las variables locales configuradas.
