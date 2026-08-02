# Plan de implementación — Centinela

## Objetivo del reto

Construir, como demostración de hackathon, una plataforma multiagente de atención al cliente para una pyme **ficticia**, **NovaCasa S.A.S.**, que responda consultas de clientes mediante un canal de Chat Web, con arquitectura extensible (`Proyecto → Agentes → Plugins → Skills → Artifacts`), gobierno documental sólido, infraestructura como código auditable y trazabilidad completa del desarrollo — todo dentro de un presupuesto y un tiempo acotados.

## Alcance del MVP

- **Canal único:** Chat Web. No se agregan canales adicionales (WhatsApp, correo, voz u otros) sin una fase dedicada y autorización explícita.
- **Dominio:** atención al cliente conversacional sobre catálogo y procesos ficticios de NovaCasa S.A.S.
- **Datos:** exclusivamente ficticios. Ningún dato real de clientes, empresas, productos, transacciones o personas se introduce en ninguna fase.
- **Proveedor de IA:** **Microsoft Foundry** es el candidato principal, sujeto a validación de disponibilidad en la región/suscripción del proyecto y a **aprobación humana explícita previa** antes de cualquier selección o despliegue de modelo. Mientras no exista un proveedor validado y aprobado, el desarrollo y las pruebas funcionales avanzan mediante `FakeModelGateway`, una implementación de contingencia que satisface el contrato `IModelGateway` sin depender de un proveedor real.
- **Persistencia:** Azure SQL como motor de base de datos, administrado mediante migraciones versionadas; forma parte del alcance del proyecto (no de esta fase de gobierno).
- **Retención de datos:** máximo 30 días para datos generados durante la demostración (conversaciones, logs de aplicación), salvo evidencia de fase, que se conserva de forma indefinida en `docs/evidence/`.
- **Tiempo de respuesta objetivo:** máximo 10 segundos por interacción conversacional en el flujo principal del Chat Web.
- **Presupuesto máximo:** USD 50 para todo el proyecto.
- **Región Azure principal:** East US 2. **Región de contingencia:** Central US, si East US 2 no tiene capacidad o disponibilidad de los servicios requeridos.

## Principio rector: fases secuenciales

El proyecto se construye por fases **estrictamente secuenciales**, nunca mezcladas ni paralelizadas. Cada fase:

1. Requiere **autorización humana explícita** antes de iniciar.
2. Produce evidencia verificable en `docs/evidence/`.
3. Se entrega mediante un Pull Request dedicado, que **requiere aprobación humana explícita antes de fusionarse** — nunca se hace merge automático ni sin revisión.
4. No adelanta trabajo de una fase futura mientras la fase actual está en curso.

Esta compuerta de aprobación entre fases aplica a **todas** las fases listadas a continuación, incluidas las que aún no tienen fecha ni alcance detallado definitivo: el alcance exacto de cada fase se confirma en el mensaje de autorización que la inicia, no en este documento.

## Fases del proyecto

### Fase 00 — Preflight

Verificación de prerrequisitos del entorno de desarrollo (herramientas, acceso a Azure CLI, acceso a GitHub, funcionamiento del proxy de trazabilidad) antes de tocar el repositorio de forma sustantiva. **Resultado:** PASS CON OBSERVACIONES; pendientes trasladados a fases posteriores (permisos y cuotas de Azure, disponibilidad regional, disponibilidad de Microsoft Foundry, selección de modelos de IA/embeddings, estimación de costo detallada, confirmación operativa de exclusividad del canal Chat Web).

### Fase 01 — Gobierno del repositorio

Establecimiento de la estructura documental, plantillas de GitHub, `CLAUDE.md` raíz y por carpeta, Architecture Decision Records iniciales, protección de ramas, funciones de seguridad básicas de GitHub y un workflow de validación de gobierno (no de CI/CD de aplicación). No incluye código funcional ni recursos de Azure. **Compuerta de aprobación:** aprobación humana del Pull Request de gobierno antes de fusionar y antes de iniciar la Fase 02.

### Fase 02 — Fundamentos de dominio y arquitectura

Definición del esqueleto de Clean Architecture (capas de dominio, aplicación, infraestructura, presentación) para la solución, sin integraciones externas reales todavía. Incluye las interfaces de abstracción (`IModelGateway`, `IEmbeddingGateway`) y su implementación de contingencia `FakeModelGateway`, siguiendo SOLID, DRY y KISS. **Resultado esperado:** solución compilable con estructura de proyecto y pruebas unitarias mínimas, sin conexión a Azure. **Compuerta de aprobación:** aprobación humana del PR de fundamentos de arquitectura.

### Fase 03 — Infraestructura como código (Bicep) y bootstrap de Azure

Definición de plantillas Bicep para los recursos de Azure requeridos por el MVP (grupo de recursos, base de datos, servicios de mensajería/orquestación según se determine), validadas con `bicep build` y `az deployment ... validate`, y ejecutadas primero en modo `what-if`. Ningún recurso se crea sin aprobación humana explícita previa. **Resultado esperado:** infraestructura base desplegada en East US 2 (o Central US como contingencia), dentro del presupuesto de USD 50, con evidencia de `what-if` y despliegue real. **Compuerta de aprobación:** aprobación humana explícita antes de cualquier `apply` real y antes de fusionar el PR de infraestructura.

### Fase 04 — Capa de datos y migraciones

Modelado de datos ficticios de NovaCasa S.A.S. sobre Azure SQL, con migraciones versionadas y reproducibles. Sin datos reales de ninguna empresa o persona en ningún script o semilla de datos. **Resultado esperado:** esquema de base de datos desplegado y migrado de forma reproducible, con datos de prueba enteramente ficticios. **Compuerta de aprobación:** aprobación humana del PR de capa de datos.

### Fase 05 — Orquestación multiagente

Implementación de la capa de agentes según la jerarquía `Proyecto → Agentes → Plugins → Skills → Artifacts`, consumiendo `IModelGateway`/`IEmbeddingGateway` (inicialmente contra `FakeModelGateway` si el proveedor de IA aprobado aún no está disponible). **Resultado esperado:** orquestación funcional de al menos un agente de atención al cliente end-to-end en un entorno controlado (sin UI todavía). **Compuerta de aprobación:** aprobación humana del PR de orquestación.

### Fase 06 — Plugins y Skills del dominio

Desarrollo de los plugins y skills específicos del caso de uso de NovaCasa S.A.S. (consultas de catálogo, procesos de atención ficticios), siguiendo la jerarquía de arquitectura y sin introducir capas adicionales sin una ADR. **Resultado esperado:** conjunto mínimo de plugins/skills necesarios para el guion de demostración, con pruebas significativas. **Compuerta de aprobación:** aprobación humana del PR de plugins/skills.

### Fase 07 — Chat Web (frontend y API de conversación)

Implementación del único canal del MVP: una interfaz de Chat Web conectada a la orquestación de agentes mediante una API de conversación. **Resultado esperado:** flujo conversacional completo, extremo a extremo, con tiempo de respuesta objetivo máximo de 10 segundos por interacción. **Compuerta de aprobación:** aprobación humana del PR de Chat Web.

### Fase 08 — Integración, pruebas end-to-end y endurecimiento de seguridad

Pruebas de integración y end-to-end sobre el flujo completo, revisión de reglas de seguridad (`docs/governance/security-rules.md`), escaneo de secretos y datos sensibles, y verificación de que ningún dato real haya sido introducido en ninguna fase anterior. **Resultado esperado:** suite de pruebas significativa pasando en verde, sin umbrales de cobertura reducidos artificialmente, y reporte de seguridad sin hallazgos abiertos de severidad alta. **Compuerta de aprobación:** aprobación humana del PR de endurecimiento.

### Fase 09 — Preparación de la demostración

Ejecución del guion de demostración (`docs/demo/demo-script-initial.md`) contra el entorno desplegado, validación del `demo-scorecard.md`, y activación del `contingency-plan.md` si algún componente no está disponible el día de la demostración. **Resultado esperado:** demostración ensayada y reproducible, con plan de contingencia probado. **Compuerta de aprobación:** aprobación humana antes de considerar el entorno "listo para demo".

### Fase 10 — Evidencia final y cierre del proyecto

Consolidación de toda la evidencia de fases (`docs/evidence/`), verificación de que ningún dato real, secreto, ruta local o identificador completo de Azure quedó versionado en ningún punto del historial, y cierre formal de los issues de fase abiertos. **Resultado esperado:** repositorio y entorno de Azure en un estado final auditable, con evidencia completa y trazable desde la Fase 00. **Compuerta de aprobación:** aprobación humana explícita de cierre del proyecto.

## Restricciones transversales (aplican a todas las fases)

- Ningún dato, usuario, producto, documento o conversación real se introduce en ninguna fase; todo es ficticio (NovaCasa S.A.S.).
- Azure CLI es el mecanismo principal de administración de recursos; Bicep es el mecanismo declarativo de IaC. No se crean recursos manualmente fuera de Bicep salvo bootstrap explícitamente autorizado.
- No se eliminan recursos, no se cambian roles RBAC y no se despliega a producción sin aprobación humana explícita.
- No se selecciona ni se despliega ningún modelo de IA sin aprobación humana explícita previa; no se presenta Foundry, Claude o servicios de embeddings como disponibles en la aplicación hasta que su disponibilidad sea validada explícitamente.
- Presupuesto máximo del proyecto: USD 50. Región principal: East US 2. Región de contingencia: Central US.
- Retención máxima de datos operativos generados por la demostración: 30 días. La evidencia de fase en `docs/evidence/` se conserva de forma indefinida.
- Tiempo de respuesta objetivo máximo del flujo conversacional: 10 segundos.
- Todo cambio funcional relevante incluye pruebas significativas; no se bajan umbrales de cobertura para hacer pasar pruebas.
- Nunca se trabaja directamente sobre `main` o `develop`; se sigue el flujo de ramas y Pull Requests descrito en `docs/governance/branching-strategy.md` y `CONTRIBUTING.md`.

## Nota sobre el origen de este documento

Este plan es una versión actualizada y saneada del plan de construcción del proyecto. No reproduce nombres de proyecto obsoletos ni información privada de documentos de planificación previos no versionados (`docs/00-contexto-inicial/`); el alcance detallado de cada fase (02 en adelante) se confirma y puede ajustarse en el mensaje de autorización explícita que da inicio a esa fase.
