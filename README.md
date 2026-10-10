# CDRL — Revisión M01 a M06 de Víctor

Repositorio independiente para que los compañeros descarguen la copia, reproduzcan las pruebas y revisen los pendientes. Deriva de [arlett-ass/opt-cdrl-base](https://github.com/arlett-ass/opt-cdrl-base) y conserva el historial y la autoría del equipo.

El informe está en [docs/REVISION-M01-M06.md](docs/REVISION-M01-M06.md). Las 34 pruebas existentes pasaron durante la evaluación. Siguen pendientes dos correcciones de seguridad/actualización de M03, completar la evidencia y la parte grupal de auditoría y recuperación de M06.

## Descargar y preparar

Requisitos: Python 3, Git, Bash, make, Docker y Docker Compose con el motor iniciado. En Windows puede usarse WSL con Docker accesible desde esa distribución.

Ejecuta en Bash:

```bash
git clone https://github.com/Vixman128/opt-cdrl-base-revision-m01-m06.git
cd opt-cdrl-base-revision-m01-m06
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
cp .env.example .env
```

Edita `.env` y define una contraseña local en `POSTGRES_PASSWORD`. PostgreSQL y DynamoDB usan los puertos 5432 y 8000 por defecto; puedes cambiarlos en ese archivo si están ocupados. `.env` se mantiene fuera de Git.

## Corroborar las pruebas

```bash
make setup
make setup
make verify
python -m pytest tests/test_m06_evolution.py -q
```

`make verify` ejecuta 32 pruebas de M01 a M05 y genera reportes en `artifacts/`. M06 tiene dos pruebas unitarias y se ejecuta por separado. El informe explica las comprobaciones adicionales y los fallos encontrados, que la suite existente aún no detecta.

## Referencia de la base original

El texto siguiente corresponde a las instrucciones iniciales del proyecto del curso.

### CDRL — Base inicial del proyecto
Esta carpeta es la base común del proyecto **Cloud Data Reliability Lab (CDRL)** para la asignatura **Bases de datos en la nube**.

## Flujo de inicio

1. Descarga esta base desde Google Classroom.
2. Crea un repositorio GitHub propio para tu equipo; no trabajes sobre el repositorio del curso.
3. Copia el contenido de esta carpeta al repositorio del equipo.
4. Agrega únicamente a los integrantes del equipo, con un máximo de tres personas.
5. Ejecuta `make setup`, `make verify` y `make run`.
6. Completa el hito semanal y conserva evidencia técnica individual de tu contribución.

El lenguaje de la aplicación lo selecciona el equipo y debe documentarse en un ADR. La interfaz mínima común del repositorio es:

```text
make setup
make verify
make run
```

## Entornos

- AWS Academy Learner Lab es el entorno cloud oficial cuando el servicio esté habilitado.
- Docker Compose/PostgreSQL y el emulador local declarado por el equipo son el respaldo reproducible.
- No uses cuentas personales con facturación, ni subas credenciales, tokens o datos sensibles.

## Primera entrega

El hito M01 transforma esta base en un contrato de datos ejecutable: agrega el esquema relacional, migraciones idempotentes, seed sintético, pruebas, reporte y ADR. La base inicial solamente verifica la estructura de arranque; no es una solución terminada.

## Entrega de cada hito

En Classroom entrega el repositorio propio del equipo, el tag semanal solicitado, el SHA exacto y el reporte de `make verify`. El repositorio debe conservar el historial y la evidencia de participación técnica de cada integrante.
