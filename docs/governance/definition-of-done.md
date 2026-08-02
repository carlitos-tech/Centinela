# Definition of Done — Centinela

Un incremento de trabajo (issue, fase) se considera terminado cuando cumple lo siguiente:

## General

- [ ] Objetivo del issue/fase cumplido según sus criterios de aceptación.
- [ ] Pull Request abierto hacia `develop` con descripción completa (resumen, alcance, exclusiones, validaciones, evidencia, riesgos).
- [ ] Workflow de validación en verde, o limitaciones documentadas si algún check no está disponible.
- [ ] Aprobación humana explícita antes de merge.

## Seguridad

- [ ] Sin secretos, tokens, llaves o cadenas de conexión versionados.
- [ ] Sin correos personales, rutas locales completas, nombres de empresas reales, ni identificadores completos de Azure.
- [ ] `.claude/settings.local.json` no versionado.
- [ ] Escaneo de seguridad ejecutado antes de cada commit/push relevante.

## Calidad

- [ ] Pruebas significativas incluidas para todo cambio funcional (cuando aplique).
- [ ] Documentación actualizada (README, CLAUDE.md, ADRs, docs/ afectados).
- [ ] Sin código o proyectos funcionales creados fuera de una fase explícitamente autorizada para ello.

## Alcance del proyecto

- [ ] No se mezclan fases del proyecto.
- [ ] No se crean o modifican recursos de Azure sin autorización explícita.
- [ ] Todos los datos usados son ficticios (NovaCasa S.A.S.).
