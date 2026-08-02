# Guion inicial de demo — Centinela

Borrador preliminar. Se refinará conforme avancen las fases posteriores del MVP.

## Contexto de apertura

Presentar NovaCasa S.A.S. como pyme ficticia y el problema que Centinela resuelve: atención al cliente ágil vía Chat Web asistida por agentes de IA.

## Flujo previsto

1. Mostrar la arquitectura multiagente (`Proyecto → Agentes → Plugins → Skills → Artifacts`) de forma visual.
2. Abrir el canal Chat Web (`http://localhost:4200`, walking skeleton local de la Fase 02) y realizar consultas típicas de un cliente ficticio de NovaCasa S.A.S.:
   - Precio, disponibilidad y características de un producto existente (p. ej. Lámpara Aurora).
   - Consulta de política local (devoluciones).
   - Recomendación con candidatos válidos del catálogo (`Necesito algo para la cocina con presupuesto de 150.000`).
   - Solicitud fuera de catálogo (`Recomiéndame un escritorio gamer con presupuesto de 100.000`) — mostrar que escala a atención humana sin inventar productos.
   - Queja de cliente molesto — mostrar el escalamiento obligatorio a atención humana.
3. Mostrar cómo `CustomerServiceOrchestrator` → `CustomerServicePlugin` resuelven cada consulta usando Skills, y consultar la traza de ejecución vía `GET /api/traces/{traceId}`.
4. Mostrar trazabilidad: issue #3 → [PR #4](https://github.com/carlitos-tech/Centinela/pull/4) → [reporte de evidencia](../evidence/phase-02-walking-skeleton-report.md).
5. Cierre: resumen de gobierno, seguridad y control de costos aplicado durante el desarrollo; aclarar que `FakeModelGateway` no es IA real y que esta fase no usa Azure.

## Pendiente

Este guion se ampliará cuando fases posteriores (canal adicional, modelo de IA real validado, infraestructura Azure) sean explícitamente autorizadas e implementadas. La Fase 02 (walking skeleton local) ya está implementada y descrita arriba, pero el [PR #4](https://github.com/carlitos-tech/Centinela/pull/4) permanece sin fusionar hasta aprobación humana explícita.
