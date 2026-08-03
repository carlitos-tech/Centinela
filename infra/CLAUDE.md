# CLAUDE.md — infra/

Esta carpeta contendrá la infraestructura como código (IaC) de Centinela en **Bicep**.

## Estado actual

**Fase 03 (Azure CLI Command Gateway y Bicep IaC) — plantillas Bicep validadas localmente, sin desplegar.** Esta carpeta contiene `main.bicep` (subscription-scoped) y sus módulos (`monitoring`, `storage`, `key-vault`, `app-service`, `sql`), `dev.bicepparam` y scripts de validación (`scripts/validate.*`, `scripts/what-if.*`). Todo se valida con `az bicep build`/`lint` y `az deployment sub validate`/`what-if` exclusivamente — **no se ha creado ningún recurso de Azure, no se ha registrado ningún proveedor y no se ha ejecutado ningún `deployment ... create`**. Ver [`docs/evidence/phase-03-azure-cli-gateway-iac-report.md`](../docs/evidence/phase-03-azure-cli-gateway-iac-report.md) y [ADR-002](../docs/architecture/adr/ADR-002-azure-cli-bicep.md).

## Reglas cuando se autorice el desarrollo

- Bicep es el único mecanismo declarativo de infraestructura. No se crean recursos manualmente por fuera de Bicep, salvo bootstrap explícitamente autorizado.
- Todo cambio se valida (`bicep build`, `az deployment ... validate`) y se ejecuta `what-if` antes de cualquier `apply` real.
- No se eliminan recursos ni se modifican roles RBAC sin aprobación humana explícita.
- Región principal: East US 2. Región alternativa: Central US.
- Presupuesto máximo del proyecto: USD 50 — cualquier plantilla debe considerar SKUs de bajo costo o niveles gratuitos donde sea posible.
- No se registran proveedores de Azure ni se crean recursos hasta la fase explícitamente autorizada para ello.
- No se incluyen credenciales, cadenas de conexión ni secretos en ningún archivo de parámetros versionado.
