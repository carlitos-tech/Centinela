# Alcance del MVP — Centinela

## Canal

Chat Web — único canal soportado en el MVP. No se incorporan canales adicionales (WhatsApp, correo, voz) sin una fase dedicada y autorización explícita.

## Funcionalidad incluida

- Conversación de atención al cliente en lenguaje natural sobre el catálogo y procesos ficticios de NovaCasa S.A.S.
- Orquestación multiagente según la jerarquía `Proyecto → Agentes → Plugins → Skills → Artifacts`.
- Registro de evidencia y trazabilidad del desarrollo (proxy, reportes de fase).

## Explícitamente fuera de alcance del MVP

- Canales distintos a Chat Web.
- Datos reales de clientes, productos o transacciones.
- Integraciones con sistemas externos reales de producción.
- Autenticación de usuarios finales más allá de lo mínimo necesario para la demostración.
- Selección o despliegue de modelos de IA sin aprobación humana previa.

## Entorno

- Ambiente inicial: `dev`.
- Presupuesto máximo: USD 50.
- Región Azure principal: East US 2. Alternativa: Central US.

## Dependencias pendientes de validación

- Disponibilidad de Microsoft Foundry en la región/suscripción del proyecto.
- Selección final de modelo(s) de IA y de embeddings.
- Cuotas y permisos de Azure para los servicios requeridos.

Estas dependencias se resuelven en fases posteriores (ver [`docs/evidence/preflight-report.md`](../evidence/preflight-report.md)).
