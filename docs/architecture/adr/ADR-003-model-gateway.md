# ADR-003: Abstracción de proveedor de IA mediante IModelGateway

## Estado

Aceptada — 2026-08-02

## Contexto

Centinela necesita interactuar con modelos de IA para las capacidades de sus agentes, pero al momento de esta decisión no se ha validado la disponibilidad de Microsoft Foundry en la región/suscripción del proyecto, ni se ha aprobado la selección de un modelo específico. Además, el desarrollo mediante Claude Code se realiza a través de un **proxy asignado para trazabilidad del desarrollo**, el cual es un mecanismo distinto y no debe confundirse con el proveedor de IA que usará la aplicación en tiempo de ejecución.

## Decisión

- Se define una abstracción de dominio, `IModelGateway` (y su equivalente `IEmbeddingGateway` para embeddings), que desacopla la lógica de agentes/plugins/skills de cualquier proveedor de IA concreto.
- **Microsoft Foundry** es el proveedor candidato principal para la implementación de `IModelGateway`, **sujeto a validación de disponibilidad** en la región y suscripción del proyecto.
- Se define `FakeModelGateway` como implementación de contingencia, para permitir desarrollo y pruebas funcionales mientras no exista un proveedor de IA validado y aprobado.
- El proxy usado para trazabilidad del desarrollo con Claude Code **no es** la implementación de `IModelGateway` de la aplicación; es una herramienta de desarrollo, no de runtime de producto.
- No se selecciona ni se despliega ningún modelo de IA para la aplicación sin **aprobación humana explícita previa**.
- No se presenta Microsoft Foundry, Claude o servicios de embeddings como disponibles en la aplicación hasta que su disponibilidad haya sido validada explícitamente.

## Alternativas consideradas

- **Acoplar el dominio directamente a un SDK de un proveedor específico**: descartado por reducir flexibilidad y dificultar cambiar de proveedor si Foundry no está disponible.
- **Usar el proxy de desarrollo como proveedor de IA de la aplicación**: descartado porque el proxy existe para trazabilidad del desarrollo con Claude Code, no como componente de runtime del producto; mezclar ambos conceptos generaría confusión arquitectónica y de gobierno.

## Consecuencias

- El dominio de la aplicación permanece independiente del proveedor de IA finalmente elegido.
- Permite avanzar en el desarrollo de agentes/plugins/skills usando `FakeModelGateway` mientras se resuelve la disponibilidad de Foundry (ver pendientes en [`docs/evidence/preflight-report.md`](../../evidence/preflight-report.md)).
- Exige mantener sincronizados los contratos de `IModelGateway`/`IEmbeddingGateway` con cualquier implementación real que se apruebe posteriormente.
- La implementación concreta de estas interfaces en código (`src/`) se realiza en una fase posterior explícitamente autorizada.
