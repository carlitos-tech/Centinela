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
| Backend (.NET, Clean Architecture) | `src/` | Sin código funcional (pendiente de fase) |
| Frontend (Chat Web) | `web/` | Sin código funcional (pendiente de fase) |
| Infraestructura (Bicep) | `infra/` | Sin plantillas funcionales (pendiente de fase) |
| Base de datos | `database/` | Sin scripts funcionales (pendiente de fase) |

## Administración de infraestructura

Azure CLI como mecanismo principal de administración; Bicep como mecanismo declarativo de IaC (ver [ADR-002](adr/ADR-002-azure-cli-bicep.md)).

## Modelo de IA

Microsoft Foundry es el proveedor candidato principal, sujeto a validación de disponibilidad. `FakeModelGateway` sirve como contingencia funcional mientras no exista un proveedor validado. Ningún modelo se selecciona o despliega sin aprobación humana explícita (ver [ADR-003](adr/ADR-003-model-gateway.md)).

## Seguridad

Ver [`docs/governance/security-rules.md`](../governance/security-rules.md).

## Historial de decisiones

Ver [`decision-log.md`](decision-log.md) y [`adr/`](adr/).
