# Product Brief — Centinela

## Resumen

Centinela es una plataforma multiagente de atención al cliente basada en inteligencia artificial, desarrollada como demostración de hackathon con Claude Code. Automatiza y asiste la atención a clientes de una pyme ficticia, **NovaCasa S.A.S.**, a través de un chat web.

## Problema

Las pymes suelen carecer de capacidad para ofrecer atención al cliente ágil y disponible fuera de horario, con respuestas consistentes y trazables, sin incurrir en costos operativos altos.

## Solución propuesta

Una plataforma de agentes de IA que atiende consultas de clientes en un canal de Chat Web, con arquitectura extensible (`Proyecto → Agentes → Plugins → Skills → Artifacts`) que permite agregar capacidades de forma modular.

## Usuarios objetivo

- Clientes finales de NovaCasa S.A.S. que interactúan vía Chat Web.
- Equipo interno (ficticio) de NovaCasa S.A.S. que supervisa la operación.

## Alcance del MVP

Ver [`mvp-scope.md`](mvp-scope.md).

## Restricciones del proyecto

- Todos los datos son ficticios; no se usa información real de ninguna empresa o persona.
- Presupuesto máximo: USD 50.
- Región Azure principal: East US 2. Alternativa: Central US.
- Único canal: Chat Web.
- Desarrollo por fases secuenciales, con aprobación humana explícita en cada una.

## Métrica de éxito de la demostración

Ver [`docs/demo/demo-scorecard.md`](../demo/demo-scorecard.md).
