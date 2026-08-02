# Plan de contingencia — Centinela

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|--------|---------|------------|
| Microsoft Foundry no disponible en la región/suscripción | Alto — bloquea el proveedor de IA principal | Usar `FakeModelGateway` como contingencia funcional (ver [ADR-003](../architecture/adr/ADR-003-model-gateway.md)) |
| Cuotas o permisos insuficientes en Azure | Alto — bloquea despliegue de recursos | Validar cuotas y permisos antes de cada fase que cree recursos; documentar bloqueos en `docs/evidence/` |
| Presupuesto (USD 50) excedido | Medio | Preferir SKUs gratuitos/bajos, apagar recursos no usados, revisar costo antes de escalar |
| Indisponibilidad regional (East US 2) | Medio | Usar Central US como región alternativa |
| Funciones de seguridad de GitHub no disponibles en el plan actual | Bajo | Documentar la limitación en el reporte de evidencia; no simular su activación |
| Falta de tiempo para completar todas las fases antes de la demo | Medio | Priorizar MVP de Chat Web sobre canales o funcionalidades adicionales |

## Principio general

Ante cualquier bloqueo, se detiene el trabajo de la fase afectada, se documenta el bloqueo en `docs/evidence/`, y se espera autorización o decisión humana antes de continuar. No se improvisan soluciones que introduzcan datos reales, credenciales o cambios no autorizados en Azure.
