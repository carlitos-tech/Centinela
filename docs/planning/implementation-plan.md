# Plan de implementación — Centinela

## Objetivo del reto

Construir, como demostración de hackathon, una plataforma multiagente de atención al cliente para una pyme **ficticia**, **NovaCasa S.A.S.**, que responda consultas de clientes mediante un canal de Chat Web, con arquitectura extensible (`Proyecto → Agentes → Plugins → Skills → Artifacts`), gobierno documental sólido, infraestructura como código auditable y trazabilidad completa del desarrollo — todo dentro de un presupuesto y un tiempo acotados.

## Alcance del MVP

- **Canal único:** Chat Web. No se agregan canales adicionales (WhatsApp, correo, voz u otros) sin una fase dedicada y autorización explícita.
- **Dominio:** atención al cliente conversacional sobre catálogo y procesos ficticios de NovaCasa S.A.S.
- **Datos:** exclusivamente ficticios. Ningún dato real de clientes, empresas, productos, transacciones o personas se introduce en ninguna fase.
- **Proveedor de IA:** **Microsoft Foundry** es el candidato principal, sujeto a validación de disponibilidad en la región/suscripción del proyecto, a que quepa dentro del presupuesto del proyecto y a **aprobación humana explícita previa** antes de cualquier selección o despliegue de modelo. Mientras no exista un proveedor validado y aprobado, el desarrollo y las pruebas funcionales avanzan mediante `FakeModelGateway`, una implementación de contingencia que satisface el contrato `IModelGateway` sin depender de un proveedor real.
- **Persistencia:** Azure SQL es obligatorio como motor de base de datos, administrado mediante Entity Framework Core y migraciones versionadas.
- **Retención de datos:** máximo 30 días para datos operativos generados durante la demostración (conversaciones, logs de aplicación), salvo evidencia de fase, que se conserva de forma indefinida en `docs/evidence/`.
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

Verificación de prerrequisitos del entorno de desarrollo: herramientas, funcionamiento del proxy de trazabilidad, acceso a GitHub y acceso a Azure CLI. Sin creación de recursos. **Resultado histórico:** PASS CON OBSERVACIONES; pendientes trasladados a fases posteriores (permisos y cuotas de Azure, disponibilidad regional, disponibilidad de Microsoft Foundry, selección de modelos de IA/embeddings, estimación de costo detallada, confirmación operativa de exclusividad del canal Chat Web).

### Fase 01 — Gobierno del repositorio

Establecimiento de la estructura documental, plantillas de GitHub, `CLAUDE.md` raíz y por carpeta, Architecture Decision Records iniciales, protección de ramas, funciones de seguridad básicas de GitHub y un workflow de validación de gobierno (no de CI/CD de aplicación). Sin código funcional ni recursos de Azure. **Compuerta de aprobación:** aprobación humana del Pull Request de gobierno antes de fusionar y antes de iniciar la Fase 02.

### Fase 02 — Walking skeleton local

Primer flujo funcional extremo a extremo, ejecutándose **enteramente en local, sin depender de Azure**:

- Backend .NET.
- Frontend Angular.
- Customer Service Orchestrator mínimo.
- Customer Service Plugin mínimo.
- `FakeModelGateway` como proveedor de IA de esta fase.
- Catálogo ficticio local (sin base de datos gestionada todavía).
- Flujo completo: Chat Web → API → orquestador → catálogo → respuesta → traza.

**Resultado esperado:** el flujo conversacional mínimo funciona de punta a punta en el entorno local del desarrollador, con trazabilidad básica del recorrido agente/plugin. **Compuerta de aprobación:** aprobación humana del PR del walking skeleton.

### Fase 03 — Azure CLI Command Gateway e infraestructura como código

Construcción de la capa de abstracción tipada y segura sobre Azure CLI, y de las plantillas declarativas de infraestructura:

- Gateway tipado y seguro para Azure CLI (no se construyen comandos de forma libre o improvisada).
- Allowlist de comandos permitidos.
- Bloqueo de operaciones destructivas.
- Redacción de secretos en salidas y logs.
- Scripts de soporte en PowerShell/Bash.
- Módulos Bicep y sus parámetros.
- Validación (`bicep build` / `az deployment ... validate`) y ejecución en modo `what-if`.

**No se crea ningún recurso de Azure hasta que exista aprobación humana explícita.** **Compuerta de aprobación:** aprobación humana del PR del gateway e IaC, y aprobación humana explícita adicional antes de cualquier `apply` real en una fase posterior.

### Fase 04 — Bootstrap Azure DEV

Primer despliegue real de infraestructura, exclusivamente en el entorno de **desarrollo (dev)**:

- Azure SQL, Storage, Key Vault, observabilidad y cómputo mínimo.
- Región principal East US 2; Central US como contingencia si no hay capacidad.
- Microsoft Foundry y Azure AI Search se incorporan **solo si** están disponibles, caben dentro del presupuesto de USD 50 y son aprobados explícitamente por el desarrollador.
- Ejecución de `what-if` y aprobación humana explícita antes del despliegue real.

**Resultado esperado:** infraestructura base de dev desplegada y verificable, dentro del presupuesto del proyecto. **Compuerta de aprobación:** aprobación humana antes del `apply` real y antes de fusionar el PR de bootstrap.

### Fase 05 — Datos y conocimiento

Modelado de datos y base de conocimiento ficticios de NovaCasa S.A.S.:

- Azure SQL como motor de persistencia.
- Entity Framework Core para el acceso a datos.
- Migraciones versionadas y reproducibles.
- Seed de datos idempotente y enteramente ficticio: productos, precios, disponibilidad, características y políticas.
- Documentos de soporte en Excel, Word y PDF (ficticios).
- Blob Storage para binarios; metadatos y trazabilidad de esos binarios en Azure SQL.
- Fragmentación de documentos, embeddings y Azure AI Search, sujeto a disponibilidad y aprobación.
- Diseño orientado a evitar respuestas inventadas: respuestas fundamentadas en las fuentes almacenadas, con referencia a esas fuentes.

**Compuerta de aprobación:** aprobación humana del PR de datos y conocimiento.

### Fase 06 — Customer Service MVP

Capacidades conversacionales centrales del agente de atención al cliente:

- Detección de intención.
- Consulta de catálogo y de políticas.
- Recomendaciones basadas en restricciones del cliente.
- Tono de marca configurable.
- Trazabilidad de agentes, plugins, skills y fuentes consultadas en cada respuesta.
- Escalamiento a atención humana ante reclamos, clientes molestos, consultas fuera de catálogo, falta de información o baja confianza de la respuesta.
- Resumen automático de la conversación para que el cliente no tenga que repetirla al escalar.
- Objetivo máximo de respuesta: 10 segundos por interacción.

**Compuerta de aprobación:** aprobación humana del PR del MVP de atención al cliente.

### Fase 07 — Artifacts, onboarding y atención humana

Superficie de uso para el cliente final y para el equipo de atención humana:

- Chat Web como único canal del MVP.
- Panel administrativo.
- Bandeja de conversaciones escaladas.
- Asignación, respuesta humana y resolución de conversaciones escaladas.
- Carga de catálogo y de políticas.
- Configuración del tono de marca.
- Dashboard operacional y visualización de trazabilidad.
- Onboarding reproducible para una pyme (ficticia).

**Compuerta de aprobación:** aprobación humana del PR de artifacts, onboarding y atención humana.

### Fase 08 — Platform Deployment Orchestrator

Orquestador de despliegue de la plataforma, que **solo** interactúa con Azure a través del Azure CLI Command Gateway construido en la Fase 03:

- Análisis de la solución y del entorno objetivo.
- Generación de un plan de despliegue tipado.
- Validación de dependencias y permisos antes de ejecutar.
- Invocación exclusiva del Azure CLI Command Gateway para cualquier operación sobre Azure (sin comandos Azure libres o improvisados).
- Despliegue de base de datos, backend y frontend.
- Health checks y capacidad de rollback.
- Reporte de despliegue.

**Compuerta de aprobación:** aprobación humana del PR del orquestador de despliegue, y aprobación humana explícita antes de cualquier despliegue real que este orquestador ejecute.

### Fase 09 — CI/CD, seguridad y scorecard

Endurecimiento del pipeline de entrega y medición objetiva de calidad:

- GitHub Actions para compilación y pruebas.
- Escaneo de secretos y de dependencias.
- Validación de plantillas Bicep en el pipeline.
- Autenticación Azure mediante OIDC, si corresponde (sin credenciales de larga duración en el repositorio).
- Evidencias de cada ejecución del pipeline.
- Golden set de preguntas de referencia para evaluar al agente.
- Métricas de precisión de precios, disponibilidad, calidad de recomendaciones, tasa de handoff a humano, trazabilidad, latencia y groundedness (fundamentación en fuentes) de las respuestas.

**Compuerta de aprobación:** aprobación humana del PR de CI/CD, seguridad y scorecard.

### Fase 10 — Endurecimiento y demo

Cierre del proyecto y preparación de la demostración final:

- Pruebas end-to-end sobre el flujo completo.
- Revisión de seguridad.
- Prueba de rollback.
- Datos ficticios definitivos para la demo.
- Demostración ejecutada sobre el entorno Azure DEV.
- Plan de contingencia local usando `FakeModelGateway` si algún componente de Azure no está disponible el día de la demo.
- Video corto de respaldo de la demostración.
- Guion ajustado a una presentación de 3 minutos.
- Consolidación final de toda la evidencia de fases.

**Compuerta de aprobación:** aprobación humana explícita de cierre del proyecto.

## Requisitos transversales (aplican a todas las fases)

- Fases estrictamente secuenciales, cada una con aprobación humana explícita antes de iniciar y antes de fusionar su Pull Request.
- Empresa, productos, usuarios y conversaciones completamente ficticios (NovaCasa S.A.S.); ningún dato real se introduce en ninguna fase.
- Chat Web como único canal implementado en el MVP.
- Microsoft Foundry sujeto a disponibilidad, presupuesto y aprobación explícita del desarrollador; no se presenta como disponible en la aplicación hasta que su disponibilidad sea validada.
- `FakeModelGateway` como contingencia mientras no exista un proveedor de IA aprobado.
- Azure SQL obligatorio como motor de persistencia.
- Presupuesto máximo del proyecto: USD 50.
- Retención operativa máxima de datos generados por la demostración: 30 días. La evidencia de fase en `docs/evidence/` se conserva de forma indefinida.
- Región Azure principal: East US 2. Región de contingencia: Central US.
- Azure CLI como mecanismo principal ("caballo de batalla") de las operaciones sobre Azure; los comandos no se construyen de forma libre o improvisada.
- Bicep como mecanismo declarativo de infraestructura como código.
- No se eliminan recursos ni se cambian roles RBAC sin aprobación humana explícita.
- Todo cambio funcional relevante incluye pruebas significativas; no se bajan umbrales de cobertura para hacer pasar pruebas.
- Nunca se trabaja directamente sobre `main` o `develop`; se sigue el flujo de ramas y Pull Requests descrito en `docs/governance/branching-strategy.md` y `CONTRIBUTING.md`.

## Nota sobre el origen de este documento

Este plan fue alineado nuevamente con el plan maestro de Centinela para conservar el orden y los componentes exactos de todas las fases (00 a 10), tras detectarse que una versión previa de este documento no conservaba dicho orden ni todos los componentes. No reproduce nombres de proyecto obsoletos ni información privada de documentos de planificación previos no versionados (`docs/00-contexto-inicial/`); el alcance detallado de cada fase (02 en adelante) se confirma y puede ajustarse en el mensaje de autorización explícita que da inicio a esa fase.
