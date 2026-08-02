# Contribuir a Centinela

Este es un proyecto de un solo desarrollador (hackathon), construido con Claude Code bajo un flujo Git formal para trazabilidad y calidad.

## Flujo de trabajo

1. Todo trabajo parte de un **issue** en GitHub que describe objetivo, alcance y criterios de aceptación.
2. Se crea una rama desde `develop` con el patrón `tipo/<issue>-descripcion-corta` (ver [`docs/governance/branching-strategy.md`](docs/governance/branching-strategy.md)).
3. Los commits siguen [Conventional Commits](https://www.conventionalcommits.org/) (ver [`docs/governance/commit-conventions.md`](docs/governance/commit-conventions.md)).
4. Al finalizar, se abre un **Pull Request** hacia `develop` usando la plantilla del repositorio.
5. El PR debe pasar el workflow de validación antes de considerarse listo para revisión.
6. El merge requiere **aprobación humana explícita** — Claude Code nunca hace merge de un PR por su cuenta.

## Ramas protegidas

`main` y `develop` están protegidas: no se permite push directo, force-push ni eliminación. Todo cambio llega mediante Pull Request.

## Reglas del proyecto

- Nunca se usan datos reales de ninguna empresa o persona (ver [`CLAUDE.md`](CLAUDE.md)).
- Nunca se incluyen secretos o credenciales.
- Las fases del proyecto se ejecutan de forma secuencial, con autorización explícita antes de cada una.
- Los cambios de infraestructura Azure se hacen solo mediante Azure CLI y Bicep, nunca manualmente.

## Definition of Done

Ver [`docs/governance/definition-of-done.md`](docs/governance/definition-of-done.md).
