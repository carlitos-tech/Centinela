# Overview de arquitectura — Centinela

## Jerarquía funcional

```text
Proyecto → Agentes → Plugins → Skills → Artifacts
```

- **Proyecto**: Centinela, la plataforma completa.
- **Agentes**: unidades de orquestación especializadas por dominio de conversación.
- **Plugins**: capacidades reutilizables que un agente puede invocar.
- **Skills**: funciones concretas dentro de un plugin.
- **Artifacts**: salidas o efectos concretos producidos (respuestas, documentos, acciones).

## Principios

- Clean Architecture: dominio → aplicación → infraestructura → presentación, con dependencias apuntando siempre hacia el dominio.
- SOLID, DRY, KISS.
- Acceso a modelos de IA abstraído mediante `IModelGateway` / `IEmbeddingGateway` (ver [ADR-003](adr/ADR-003-model-gateway.md)).

## Componentes previstos (alto nivel)

| Componente | Carpeta | Estado |
|------------|---------|--------|
| Backend (.NET, Clean Architecture) | `src/` | Fase 02: walking skeleton local implementado ([PR #4](https://github.com/carlitos-tech/Centinela/pull/4), pendiente de aprobación) |
| Frontend (Chat Web) | `web/` | Fase 02: walking skeleton local implementado ([PR #4](https://github.com/carlitos-tech/Centinela/pull/4), pendiente de aprobación) |
| Infraestructura (Bicep) | `infra/` | Fase 03: plantillas Bicep de DEV validadas localmente (`bicep build`/`lint`, `deployment sub validate`/`what-if`); ningún recurso creado |
| Base de datos | `database/` | Sin scripts funcionales (pendiente de fase) |

### Implementación real de la Fase 02

La Fase 02 implementa un único agente (`CustomerServiceOrchestrator`) y un único plugin (`CustomerServicePlugin`, con 7 Skills), operando enteramente en memoria y contra datos ficticios locales (`src/Centinela.Infrastructure/Data/catalog.json`, `policies.json`). No existen todavía otros agentes o plugins: cualquier referencia a componentes de fases posteriores es solo planeación, no implementación. Ver [`docs/evidence/phase-02-walking-skeleton-report.md`](../evidence/phase-02-walking-skeleton-report.md) para el detalle completo (mapeo de reglas antialucinación, pruebas, escenarios verificados).

### Implementación real de la Fase 03

La Fase 03 implementa `IAzureCliCommandGateway` (`src/Centinela.Application/Abstractions/AzureCli/`, `src/Centinela.Infrastructure/AzureCli/`): la única vía permitida en el código de Centinela para ejecutar Azure CLI, con una allowlist tipada y cerrada de operaciones de solo lectura/validación, argumentos siempre pasados como tokens discretos, auditoría con `CorrelationId` y redacción automática de la salida (GUID, correos, rutas locales, credenciales). En paralelo, se crearon las plantillas Bicep de DEV (`infra/main.bicep` y módulos), validadas localmente sin crear ningún recurso real ni registrar proveedores. Ningún componente de la aplicación (backend/frontend) invoca todavía este gateway en producción: es infraestructura de administración, no parte del flujo de conversación del Chat Web. Ver [`docs/evidence/phase-03-azure-cli-gateway-iac-report.md`](../evidence/phase-03-azure-cli-gateway-iac-report.md).

## Administración de infraestructura

Azure CLI como mecanismo principal de administración, exclusivamente a través de `IAzureCliCommandGateway`; Bicep como mecanismo declarativo de IaC (ver [ADR-002](adr/ADR-002-azure-cli-bicep.md)).

## Modelo de IA

Microsoft Foundry es el proveedor candidato principal, sujeto a validación de disponibilidad. En la Fase 02, `FakeModelGateway` (`src/Centinela.Infrastructure/Gateways/FakeModelGateway.cs`) es la **única implementación registrada** de `IModelGateway`: no llama a ningún servicio de IA real, no usa tokens ni claves, y solo aplica plantillas fijas sobre hechos extraídos del catálogo/políticas locales. Ningún modelo de IA real se selecciona o despliega sin aprobación humana explícita (ver [ADR-003](adr/ADR-003-model-gateway.md)).

## Seguridad

Ver [`docs/governance/security-rules.md`](../governance/security-rules.md).

## Historial de decisiones

Ver [`decision-log.md`](decision-log.md) y [`adr/`](adr/).
