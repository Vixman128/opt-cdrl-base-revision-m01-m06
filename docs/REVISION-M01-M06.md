# Evaluación del proyecto M01 a M06

Fecha de evaluación 10 de octubre de 2026

La copia corregida del Escritorio ya puede preparar los servicios y ejecutar las pruebas mediante los comandos solicitados por el maestro. Pasaron las 34 pruebas existentes. Sin embargo, la entrega completa todavía tiene fallos comprobados en la política de permisos M03, la actualización de bases anteriores y la trazabilidad. El M06 de equipo continúa incompleto, aunque la evolución de esquema de Víctor funciona incluso contra DynamoDB real.

Esta es una revisión con los criterios de la retroalimentación del maestro. No es una calificación oficial. Las guías disponibles no proporcionan pesos suficientes para calcular una nueva nota sobre ocho.

## Estado evaluado y método

Se evaluó `C:/Users/Vixman Suarez/Desktop/opt-cdrl-base-review`, rama `fix/m01-m03-reproducibility-security`. Su commit base es `4896d5e1de14001f808cfafc6563c9a38b9c40bf`. Las correcciones estaban sin commit durante la evaluación y después se registraron en `6c2a87b23726027f2bc491b93e71c54b6dc7b9f1`. El parche `source.patch` conserva los cambios evaluados; los tres scripts nuevos de preparación e integración también se copiaron a la instantánea. La carpeta compartida se llama ahora `opt-cdrl-base-revision-m01-m06`.

Se creó un checkout nuevo en WSL, un entorno virtual nuevo y volúmenes Docker nuevos para PostgreSQL y DynamoDB. Se configuró un `.env` local sintético, ignorado por Git, a partir del ejemplo. Después se ejecutaron exactamente `make setup`, `make setup` y `make verify`, sin preparar la base por separado. El motor fue Docker Engine 29.7.2 con Compose 5.5.0; Python 3.14.4 y las dependencias de requirements.txt. Esta ejecución acredita el flujo Linux/WSL. No acredita el arranque de Docker Desktop en Windows, cuyo fallo de infraestructura motivó el motor separado.

Se compararon los conteos y las huellas del contenido antes y después del segundo setup. Se ejecutó M06 aparte porque `make verify` termina en M05. Finalmente se hicieron comprobaciones adicionales sobre las cinco consultas, nuevos objetos de seguridad, actualización desde la migración anterior y evolución M06 en DynamoDB real.

## Resultados ejecutados

| Comprobación | Resultado | Evidencia |
|---|---|---|
| Primer `make setup` con volúmenes nuevos | Aprobado | setup-first.log |
| Segundo `make setup` | Aprobado | setup-second.log |
| Idempotencia de filas y migraciones | Aprobada; 3 ubicaciones, 5 dispositivos y 50 lecturas, con huellas idénticas | db-before.log, db-after.log |
| `make verify` M01 a M05 | Aprobado, 32 pruebas | verify-integrated.log |
| M01 | 4 de 4 | artifacts/m01-tests.json |
| M02 | 12 de 12, ocho invariantes y cuatro de aceptación | artifacts/m02-relational-results.json |
| M03 básico | 8 de 8, incluidas cuatro denegaciones | artifacts/m03-security-results.json |
| M04 | 4 de 4; selección Document/MongoDB 3.95 | artifacts/m04-storage-selection-results.json |
| M05 | 4 de 4 contra DynamoDB; tabla repetible y dos GSIs | artifacts/m05-document-store-results.json |
| M06 unitario de Víctor | 2 de 2 | artifacts/teacher-m06-unit.json |
| M06 de Víctor en DynamoDB real | Siete comprobaciones aprobadas | m06-real-dynamodb.log |
| Cinco consultas y bordes M02 | Dieciséis comprobaciones adicionales aprobadas al cargar el entorno | m02-query-additional-checks.log |
| `make queries` después de setup, sin exportar `.env` | Falló por POSTGRES_PASSWORD ausente | queries-clean-shell.log |
| Política de funciones futuras M03 | Falló en ambos creadores y los tres roles operativos | m03-additional-probe.log |
| Actualización desde M03 antiguo | Falló la corrección de permisos; rebuild terminó con código cero | m03-upgrade-from-legacy.log, upgrade-rebuild.log |

Las comprobaciones adicionales se ejecutaron sobre objetos y datos sintéticos. Los objetos de seguridad se revirtieron mediante ROLLBACK, la base temporal de actualización se eliminó y los tres eventos M06 de prueba se borraron. No se usó una base existente del proyecto original.

## Evaluación por entrega

### M01

La observación central del maestro está corregida en esta copia: `make setup` inicia servicios y ejecuta reconstrucción/seed, y `make verify` ejecuta los cuatro escenarios y genera un reporte real. Se comprobó que repetir setup conserva los datos sembrados. Queda completar el SHA de la evidencia y entregar la versión final corregida. Las correcciones evaluadas están registradas en `6c2a87b`. Una ejecución local correcta no modifica retrospectivamente la entrega o los tags anteriores.

### M02

Pasaron los doce escenarios propios y las cinco consultas devolvieron resultados coherentes con el seed. También se comprobó el caso vacío, límites uno y mil, rechazo de límites inválidos, identificadores inadecuados y fechas sin zona o invertidas.

El comando `make queries` falla porque no carga `.env`; la carga hecha dentro de setup no persiste en la terminal que lo invoca. Al cargar el entorno explícitamente, la demostración funciona. Además, el verificador M02 todavía no ejecuta ni valida esta demostración de las cinco consultas. El ADR-002 conserva una afirmación antigua sobre no modificar verify_base. Estos problemas deben cerrarse junto con el SHA.

### M03

En una base nueva, el operador ya no puede leer telemetría cruda ni modificar dispositivos y sí puede consultar la vista operacional acotada. Las cuatro denegaciones obtuvieron el resultado esperado. Las tablas y secuencias nuevas tampoco quedaron accesibles para los roles operativos.

Se confirmaron dos defectos que no detectan los ocho tests existentes. Primero, reader, writer y operator pudieron ejecutar una función nueva creada tanto por el administrador como por migrator. `ALTER DEFAULT PRIVILEGES ... IN SCHEMA public REVOKE EXECUTE` no revoca el permiso global de PUBLIC. Hay que revocar el permiso global para cada creador previsto y probar funciones, además de tablas y secuencias. PostgreSQL explica explícitamente esta diferencia en [ALTER DEFAULT PRIVILEGES](https://www.postgresql.org/docs/16/sql-alterdefaultprivileges.html).

Segundo, al simular una base con 003 antigua registrada, el rebuild actual omitió esa migración y mantuvo SELECT de telemetría y UPDATE(status) del operador. Conservó las 50 lecturas, pero no creó la vista segura. Hace falta una nueva migración correctiva que actualice una base existente sin perder datos; editar un archivo ya registrado no basta.

El ADR actual también debe recuperar el procedimiento de rotación de credenciales, alternativas y participación individual solicitados. La evidencia sigue diciendo not_run y conserva el bloqueo anterior de Docker, aunque esta evaluación sí ejecutó los tests. Se respetó el criterio posterior del maestro de restringir al operador; la guía anterior proponía permisos más amplios.

### M04

La matriz, los pesos, el cálculo del ganador y los cuatro escenarios funcionan. La guía permite hipótesis explícitas; no corresponde exigir despliegues productivos de cuatro motores que no fueron pedidos. Quedan cerrar la redacción provisional sobre el descarte de Graph y alinear la evidencia: SHA y conteos M02/M03. La participación real documentada en Git debe conservarse aunque difiera del reparto propuesto por la guía.

### M05

El verificador completo pasó con DynamoDB real dentro de Docker. Se comprobó CRUD, duplicados, ausencia, documento inválido, preparación repetida y ambos índices. El flujo integrado desde setup también funcionó en esta evaluación. Quedan el SHA y las cifras desactualizadas de la evidencia. Estas pruebas corresponden a DynamoDB Local; no se presentan como pruebas en AWS ni de desempeño productivo.

### M06

Los dos tests existentes de Víctor pasaron. La comprobación adicional en DynamoDB real confirmó coexistencia v1/v2, conservación de datos, migración persistida, repetición sin otra escritura, no-op de v2, duplicado y ausencia. Por tanto, su alcance individual de evolución funciona.

La entrega grupal todavía carece de auditoría segura, operaciones auditadas, recuperación, pruebas y fixtures correspondientes, verifier M06, artifact y evidence de M06. `make verify` no incluye M06. Estas tareas faltantes pertenecen al reparto de equipo y no deben atribuirse todas a Víctor. El ADR-006 reconoce que están pendientes.

## Correcciones necesarias antes de presentar todo como terminado

1. Crear una nueva migración M03 que cierre permisos de funciones futuras y actualice los permisos anteriores. Agregar verificaciones reales de funciones y actualización de una base antigua.
2. Hacer que el comando de consultas cargue el entorno y que la verificación M02 produzca y valide su demostración.
3. Completar el ADR de seguridad y actualizar evidencias con resultados actuales, conteos y SHA del commit entregado. Los arreglos evaluados están en `6c2a87b`; este repositorio independiente se comparte para revisión del equipo.
4. Integrar las partes faltantes del equipo M06 y conectarlas con la verificación oficial.

La preparación y las pruebas que antes explicaban buena parte de las notas bajas ya están integradas y comprobadas en la copia corregida. No daría por aprobada todavía la entrega completa: M03 conserva dos fallos de seguridad/reproducibilidad y M06 grupal no está completo.

## Fuentes revisadas

Se usaron los tres comentarios del maestro proporcionados en la conversación y las guías locales M03, M04, M05 y M06. No se encontraron guías M01/M02 en las rutas revisadas; para esos hitos se tomó la retroalimentación del maestro y lo que declara el repositorio.

- C:/Users/Vixman Suarez/Downloads/Guia_M03_Seguridad_Relacional_CDRL.docx
- C:/Users/Vixman Suarez/Downloads/Guia_M04_Seleccion_Almacenamiento_NoSQL_CDRL.docx
- C:/Users/Vixman Suarez/Downloads/Guia_M05.docx
- C:/Users/Vixman Suarez/Downloads/Guia_M06_evolucion_auditoria_recuperacion.docx

El detalle de ejecución y los reportes se conservan en esta carpeta. `statuses.tsv` distingue errores funcionales adicionales del éxito de la suite actual.

## Nombre de la copia para compartir

Después de la evaluación, la carpeta se renombró a opt-cdrl-base-revision-m01-m06 y la rama local a review/m01-m06-victor. La rama que se subió inicialmente al repositorio del equipo fue eliminada por indicación de Víctor. La copia se comparte en un repositorio independiente, con main como rama de descarga. Los resultados corresponden al código evaluado antes del cambio de nombre; esta actualización de documentación no vuelve a ejecutar ni modifica las pruebas. Esta versión se comparte para revisión del equipo y conserva los pendientes documentados arriba.
