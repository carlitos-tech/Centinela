# CLAUDE.md — src/

Esta carpeta contendrá el código backend de Centinela (.NET), organizado según Clean Architecture (dominio, aplicación, infraestructura, presentación) y la jerarquía `Proyecto → Agentes → Plugins → Skills → Artifacts`.

## Estado actual

**Sin código funcional.** Esta carpeta no debe contener proyectos `.NET`, soluciones (`.sln`), ni implementaciones hasta que la fase correspondiente del plan sea explícitamente autorizada.

## Reglas cuando se autorice el desarrollo

- Seguir Clean Architecture: dependencias apuntan siempre hacia el dominio, nunca al revés.
- Aplicar SOLID, DRY, KISS.
- Los agentes y plugins se implementan como componentes independientes y testeables, ubicables dentro de la jerarquía `Proyecto → Agentes → Plugins → Skills → Artifacts`.
- El acceso a modelos de IA se realiza exclusivamente a través de abstracciones (`IModelGateway`, `IEmbeddingGateway`), nunca acoplando el dominio a un proveedor específico (ver `docs/architecture/adr/ADR-003-model-gateway.md`).
- No se seleccionan ni despliegan modelos de IA sin aprobación humana explícita.
- Toda funcionalidad nueva incluye pruebas significativas.
- No se incluyen secretos ni cadenas de conexión en el código; se usan variables de entorno y configuración externa.
- No se procesan datos reales de ninguna empresa o persona — solo datos ficticios de NovaCasa S.A.S.
