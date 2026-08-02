# Registro de decisiones — Centinela

Bitácora resumida de decisiones relevantes. Las decisiones arquitectónicas formales se documentan como ADR en [`adr/`](adr/).

| Fecha | Decisión | Motivo | Referencia |
|-------|----------|--------|------------|
| 2026-08-02 | Adoptar jerarquía `Proyecto → Agentes → Plugins → Skills → Artifacts` como modelo de arquitectura multiagente | Base funcional definida en la arquitectura maestra del proyecto | [ADR-001](adr/ADR-001-multiagent-architecture.md) |
| 2026-08-02 | Azure CLI como mecanismo principal de administración y Bicep como IaC declarativo | Evitar cambios manuales no trazables sobre Azure | [ADR-002](adr/ADR-002-azure-cli-bicep.md) |
| 2026-08-02 | Abstraer el acceso a modelos de IA mediante `IModelGateway`, con Microsoft Foundry como candidato principal sujeto a validación y `FakeModelGateway` como contingencia | Evitar acoplar el dominio a un proveedor no validado; el proxy de desarrollo no es el proveedor de IA de la aplicación | [ADR-003](adr/ADR-003-model-gateway.md) |
| 2026-08-02 | No crear archivo `LICENSE` en la Fase 01 | Pendiente de decisión del desarrollador | — |
| 2026-08-02 | No versionar `docs/00-contexto-inicial/` en el repositorio público | Contiene el nombre de proyecto obsoleto ("Atenea CX Platform") y no forma parte del alcance autorizado de archivos de la Fase 01; se conserva solo localmente | — |
