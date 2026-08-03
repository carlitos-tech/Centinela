# Matriz de trazabilidad — Centinela

Relaciona fases del proyecto, issues, ADRs y evidencia. Se actualiza al cierre de cada fase.

| Fase | Issue | Rama | ADRs relacionados | Evidencia | Estado |
|------|-------|------|--------------------|-----------|--------|
| Fase 00 — Preflight | — | — | — | [`docs/evidence/preflight-report.md`](../evidence/preflight-report.md) | PASS CON OBSERVACIONES |
| Fase 01 — Gobierno del repositorio | [#1](https://github.com/carlitos-tech/Centinela/issues/1) | `chore/phase-01-repository-governance` | ADR-001, ADR-002, ADR-003 | [`docs/evidence/phase-01-governance-report.md`](../evidence/phase-01-governance-report.md) | En curso |
| Fase 02 — Walking skeleton local | [#3](https://github.com/carlitos-tech/Centinela/issues/3) | `feat/phase-02-local-walking-skeleton` | ADR-001, ADR-003 | [`docs/evidence/phase-02-walking-skeleton-report.md`](../evidence/phase-02-walking-skeleton-report.md) | Implementada — [PR #4](https://github.com/carlitos-tech/Centinela/pull/4) abierto, pendiente de aprobación humana (sin fusionar) |
| Fase 03 — Azure CLI Command Gateway y Bicep IaC | [#5](https://github.com/carlitos-tech/Centinela/issues/5) | `feat/phase-03-azure-cli-gateway-iac` | ADR-002 | [`docs/evidence/phase-03-azure-cli-gateway-iac-report.md`](../evidence/phase-03-azure-cli-gateway-iac-report.md) | Implementada — pendiente de apertura de Pull Request y aprobación humana (sin fusionar) |

## Notas

- Las fases posteriores (02 en adelante) se agregan a esta matriz únicamente cuando son autorizadas e iniciadas.
- No se registran en esta matriz recursos de Azure creados fuera de una fase explícitamente autorizada para ello.
