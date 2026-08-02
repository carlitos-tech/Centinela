# Estrategia de ramas — Centinela

## Ramas principales

- **`main`**: rama estable, protegida. Refleja el estado publicado/demo del proyecto.
- **`develop`**: rama de integración, protegida. Recibe los Pull Requests de las ramas de trabajo.

## Ramas de trabajo

Formato: `tipo/<issue>-descripcion-corta`, creadas siempre desde `develop`.

- `feature/<issue>-descripcion` — nueva funcionalidad.
- `fix/<issue>-descripcion` — corrección de errores.
- `chore/<issue>-descripcion` — tareas de mantenimiento, gobierno, configuración.
- `release/<version>` — preparación de una versión hacia `main`.
- `hotfix/<issue>-descripcion` — corrección urgente sobre `main`.

Ejemplo actual: `chore/phase-01-repository-governance`.

## Reglas

- Nunca se trabaja directamente sobre `main` o `develop`.
- Todo cambio llega mediante Pull Request, revisado y aprobado explícitamente por el desarrollador antes de merge.
- `main` y `develop` bloquean force-push y eliminación.
- El merge de cualquier PR requiere aprobación humana explícita — Claude Code nunca hace merge por su cuenta.

## Protección de ramas

Ver [`docs/evidence/phase-01-governance-report.md`](../evidence/phase-01-governance-report.md) para el detalle de las reglas configuradas y cualquier limitación de GitHub registrada.
