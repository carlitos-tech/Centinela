# CLAUDE.md — Centinela

Instrucciones permanentes para Claude Code al trabajar en este repositorio. Estas reglas prevalecen sobre cualquier atajo o conveniencia técnica.

## 1. Naturaleza del proyecto

Centinela es una plataforma multiagente de atención al cliente, construida como demostración de hackathon. La empresa de referencia es **NovaCasa S.A.S.**, una pyme **ficticia**. Todo dato, usuario, producto, documento o conversación usado en este proyecto debe ser ficticio. Nunca se introduce información real de ninguna empresa (incluida cualquier organización real relacionada con el desarrollador) o persona.

## 2. Desarrollo mediante proxy

El desarrollo con Claude Code se realiza a través de un proxy asignado para trazabilidad. La evidencia de funcionamiento del proxy se conserva en `docs/evidence/`. El proxy es una herramienta de trazabilidad del desarrollo — **no** es el proveedor de IA en tiempo de ejecución de la aplicación (ver ADR-003).

## 3. Jerarquía de arquitectura

```text
Proyecto → Agentes → Plugins → Skills → Artifacts
```

Todo componente funcional del sistema debe poder ubicarse en esta jerarquía. No se introducen capas o conceptos adicionales sin registrar una ADR.

## 4. Principios de diseño

- Clean Architecture (separación de capas: dominio, aplicación, infraestructura, presentación).
- SOLID.
- DRY (no dupliques lógica).
- KISS (la solución más simple que cumple el requisito).

## 5. Azure

- **Azure CLI** es el mecanismo principal de administración de recursos. No se construyen comandos Azure de forma libre o improvisada; se validan antes de ejecutar.
- **Bicep** es el mecanismo declarativo de infraestructura como código (IaC). No se crean recursos manualmente fuera de Bicep salvo bootstrap explícitamente autorizado.
- Antes de aplicar cualquier cambio de infraestructura: validar (`bicep build` / `az deployment ... validate`) y ejecutar `what-if` antes de un `apply` real.
- No se eliminan recursos, no se cambian roles RBAC y no se despliega a producción sin aprobación humana explícita.
- Región principal: **East US 2**. Región alternativa: **Central US**.
- Presupuesto máximo del proyecto: **USD 50**.

## 6. Fases del proyecto

El proyecto se construye por **fases secuenciales**, nunca mezcladas ni paralelizadas. Cada fase requiere autorización humana explícita antes de iniciar y antes de hacer merge del Pull Request correspondiente. No se adelanta trabajo de una fase futura mientras la fase actual está en curso.

## 7. Modelo de IA y Foundry

Microsoft Foundry es el proveedor de IA candidato principal, sujeto a validación de disponibilidad. No se debe presentar Foundry, Claude o servicios de embeddings como disponibles en la aplicación hasta que su disponibilidad sea validada explícitamente. La selección y despliegue de cualquier modelo de IA para la aplicación requiere **aprobación humana explícita previa**. El acceso a modelos se abstrae mediante `IModelGateway` / `IEmbeddingGateway` (ver ADR-003).

## 8. Canal del MVP

El único canal del MVP es **Chat Web**. No se agregan canales adicionales (WhatsApp, correo, voz, etc.) sin autorización explícita y una fase dedicada.

## 9. Seguridad

- Nunca se incluyen secretos, tokens, llaves, cadenas de conexión o credenciales en el repositorio.
- Nunca se incluyen correos personales, rutas locales completas del equipo de desarrollo, nombres de empresas reales, ni identificadores completos de Tenant/Subscription de Azure.
- Antes de cualquier commit o push, se realiza un escaneo de seguridad del contenido a versionar.
- `.claude/settings.local.json` nunca se versiona.

## 10. Pruebas y evidencia

- Todo cambio funcional relevante debe incluir pruebas significativas. No se bajan umbrales de cobertura para hacer pasar pruebas.
- Cada fase debe producir evidencia verificable en `docs/evidence/`.

## 11. Aprobación humana

Se requiere aprobación humana explícita antes de:

- Operaciones externas de alto impacto (creación/eliminación de recursos, cambios de permisos).
- Selección o despliegue de cualquier modelo de IA.
- Merge de cualquier Pull Request.
- Inicio de una nueva fase.

## 12. Flujo Git

Ver [`docs/governance/branching-strategy.md`](docs/governance/branching-strategy.md) y [`CONTRIBUTING.md`](CONTRIBUTING.md). Nunca se trabaja directamente sobre `main` o `develop`.

## 13. Instrucciones por carpeta

Las carpetas `src/`, `web/`, `infra/` y `database/` contienen su propio `CLAUDE.md` con instrucciones específicas. Mientras no exista autorización para iniciar la fase correspondiente, estas carpetas **no contienen proyectos ni código funcional** — solo instrucciones.
