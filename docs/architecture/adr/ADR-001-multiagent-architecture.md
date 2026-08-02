# ADR-001: Arquitectura multiagente (Proyecto → Agentes → Plugins → Skills → Artifacts)

## Estado

Aceptada — 2026-08-02

## Contexto

Centinela necesita un modelo de organización funcional que permita construir capacidades de atención al cliente de forma modular, extensible y trazable, evitando un monolito de lógica de conversación difícil de mantener o de razonar.

## Decisión

Se adopta la siguiente jerarquía como estructura funcional del proyecto:

```text
Proyecto → Agentes → Plugins → Skills → Artifacts
```

- **Proyecto**: Centinela como plataforma completa.
- **Agentes**: unidades de orquestación especializadas por dominio de conversación o intención.
- **Plugins**: capacidades reutilizables invocables por uno o más agentes.
- **Skills**: funciones concretas y acotadas dentro de un plugin.
- **Artifacts**: salidas o efectos concretos producidos por la ejecución (respuestas, documentos, acciones registradas).

Todo componente funcional del sistema debe poder ubicarse en uno de estos niveles. No se introducen capas adicionales sin una nueva ADR que lo justifique.

## Alternativas consideradas

- **Monolito de lógica conversacional único**: descartado por baja mantenibilidad y dificultad para razonar sobre responsabilidades.
- **Microservicios independientes por funcionalidad desde el inicio**: descartado para el MVP por complejidad operativa y de costo desproporcionada frente al presupuesto (USD 50) y alcance (Chat Web único).

## Consecuencias

- Favorece la extensión modular (nuevos plugins/skills) sin reescribir agentes existentes.
- Facilita pruebas unitarias por nivel (skill, plugin, agente).
- Requiere disciplina para no mezclar responsabilidades entre niveles.
- La implementación concreta de esta jerarquía en código (`src/`) se realiza en una fase posterior explícitamente autorizada.
