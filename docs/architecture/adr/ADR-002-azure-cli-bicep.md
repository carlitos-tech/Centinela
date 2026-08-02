# ADR-002: Azure CLI como mecanismo principal de administración y Bicep como IaC declarativo

## Estado

Aceptada — 2026-08-02

## Contexto

El proyecto necesita gestionar recursos de Azure de forma trazable, repetible y auditable, dentro de un presupuesto limitado (USD 50) y sin exponer credenciales. El desarrollo se realiza mediante Claude Code, por lo que las operaciones sobre Azure deben poder validarse antes de ejecutarse y dejar rastro claro de qué se hizo y por qué.

## Decisión

- **Azure CLI** es el mecanismo principal de administración de recursos: toda operación de consulta, creación o configuración se ejecuta mediante comandos de Azure CLI, nunca mediante el portal manualmente para cambios que deban quedar trazados, ni mediante comandos improvisados sin validación previa.
- **Bicep** es el mecanismo declarativo de infraestructura como código (IaC): la definición de recursos vive en plantillas Bicep versionadas en `infra/`, no en pasos manuales.
- Todo cambio de infraestructura se valida (`bicep build`, `az deployment ... validate`) y se ejecuta en modo `what-if` antes de aplicarse realmente.
- No se eliminan recursos, no se modifican roles RBAC y no se despliega a producción sin aprobación humana explícita.

## Alternativas consideradas

- **Terraform**: descartado para mantener el proyecto dentro del ecosistema nativo de Azure y reducir herramientas adicionales a instalar/mantener en un proyecto de hackathon.
- **Cambios manuales vía Azure Portal**: descartado por falta de trazabilidad y riesgo de configuraciones no reproducibles.
- **Scripts imperativos ad-hoc sin IaC declarativo**: descartado por dificultar el control de versiones y la revisión de cambios de infraestructura.

## Consecuencias

- Todo cambio de infraestructura queda versionado y revisable mediante Pull Request, igual que el código de aplicación.
- Se reduce el riesgo de "configuration drift" entre lo declarado y lo real.
- Introduce la disciplina adicional de mantener plantillas Bicep válidas y actualizadas.
- La creación de plantillas Bicep funcionales y el registro de proveedores de Azure se realizan en una fase posterior explícitamente autorizada — no en la Fase 01.
