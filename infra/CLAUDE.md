# CLAUDE.md — infra/

Esta carpeta contendrá la infraestructura como código (IaC) de Centinela en **Bicep**.

## Estado actual

**Sin plantillas Bicep funcionales.** Esta carpeta no debe contener archivos `.bicep` desplegables ni parámetros de entorno hasta que la fase correspondiente del plan sea explícitamente autorizada.

## Reglas cuando se autorice el desarrollo

- Bicep es el único mecanismo declarativo de infraestructura. No se crean recursos manualmente por fuera de Bicep, salvo bootstrap explícitamente autorizado.
- Todo cambio se valida (`bicep build`, `az deployment ... validate`) y se ejecuta `what-if` antes de cualquier `apply` real.
- No se eliminan recursos ni se modifican roles RBAC sin aprobación humana explícita.
- Región principal: East US 2. Región alternativa: Central US.
- Presupuesto máximo del proyecto: USD 50 — cualquier plantilla debe considerar SKUs de bajo costo o niveles gratuitos donde sea posible.
- No se registran proveedores de Azure ni se crean recursos hasta la fase explícitamente autorizada para ello.
- No se incluyen credenciales, cadenas de conexión ni secretos en ningún archivo de parámetros versionado.
