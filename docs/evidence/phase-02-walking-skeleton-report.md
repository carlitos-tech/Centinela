# Reporte de evidencia — Fase 02: Walking skeleton local

## Metadatos

- **Fecha/hora (America/Bogota):** 2026-08-02 (UTC-5)
- **Modelo y esfuerzo usados:** Sonnet 5, esfuerzo alto
- **Rama de trabajo:** `feat/phase-02-local-walking-skeleton` (creada desde `develop`)
- **Issue de la fase:** [#3 — Phase 02: Local walking skeleton](https://github.com/carlitos-tech/Centinela/issues/3)
- **Pull Request de la fase:** se abre en el PASO 16, después de este reporte. **El HEAD vigente de la rama y el estado de los checks se consultan directamente en el Pull Request**, no en este documento — este reporte no registra el SHA de su propio commit contenedor.

## Resultado

**PASS.** Se construyó un walking skeleton **totalmente local**: Chat Web (Angular) → API (.NET) → `CustomerServiceOrchestrator` → `CustomerServicePlugin` → 7 Skills → `FakeModelGateway` → catálogo/políticas ficticias en memoria → respuesta fundamentada con citación de fuentes → traza de ejecución en memoria. No se usó Azure, no se usó una base de datos real, no se llamó a ningún proveedor de IA real. Las 10 reglas antialucinación exigidas están implementadas de forma arquitectónica (no como prompt) y verificadas con pruebas automatizadas. El Pull Request de esta fase permanece **sin abrir hasta el PASO 16 y sin fusionar**; el cierre de la fase (merge, cierre del issue #3) requiere aprobación humana explícita, que aún no se ha otorgado.

## Arquitectura implementada

Jerarquía exigida por `CLAUDE.md`: `Proyecto → Agentes → Plugins → Skills → Artifacts`.

| Capa | Elemento | Ubicación |
|---|---|---|
| Proyecto | Centinela (walking skeleton local) | `Centinela.slnx` |
| Agente | `CustomerServiceOrchestrator` | `src/Centinela.Application/Orchestration/CustomerServiceOrchestrator.cs` |
| Plugin | `CustomerServicePlugin` (`ICustomerServicePlugin`) | `src/Centinela.Application/Plugins/CustomerServicePlugin.cs` |
| Skills (7) | `ClassifyIntentSkill`, `SearchCatalogSkill`, `SearchPolicySkill`, `RecommendProductSkill`, `DetermineHumanHandoffSkill`, `BuildGroundedResponseSkill`, `RecordTraceSkill` | `src/Centinela.Application/Skills/` |
| Artifact | `ChatResult` (respuesta fundamentada devuelta al canal Chat Web) | `src/Centinela.Application/Contracts/ChatResult.cs` |

Clean Architecture de cuatro capas:

- **Domain** (`src/Centinela.Domain`): entidades (`Product`, `BusinessPolicy`, `Conversation`, `Message`, `ExecutionTrace`, `HumanHandoffRequest`, `SourceReference`) y enums (`CustomerIntent`, `ExecutionResult`, `MessageRole`, `ProductAvailability`). Sin dependencias externas.
- **Application** (`src/Centinela.Application`): abstracciones (`ICatalogRepository`, `IPolicyRepository`, `ITraceRepository`, `IModelGateway`, `ICustomerServicePlugin`), Skills, orquestador, contratos de E/S. Depende solo de Domain.
- **Infrastructure** (`src/Centinela.Infrastructure`): `FakeModelGateway` (implementa `IModelGateway` sin llamar a ningún servicio de IA real), repositorios en memoria (`InMemoryCatalogRepository`, `InMemoryPolicyRepository`, `InMemoryTraceRepository`) que cargan `Data/catalog.json` y `Data/policies.json`, `DependencyInjection.cs` para el registro de servicios.
- **Presentation** (`src/Centinela.Api`): API mínima de ASP.NET Core (`Program.cs`) con 3 endpoints REST, CORS restringido al origen del Chat Web (`http://localhost:4200`).

Frontend (`web/centinela-web`, Angular 19 standalone, sin NgModules): `ChatComponent` (Signals para `messages`/`loading`/`errorMessage`), `ChatService` (cliente HTTP hacia la API), `AppComponent` como shell con aviso permanente de datos ficticios de NovaCasa S.A.S.

## Reglas antialucinación (10) — implementación y verificación

| # | Regla | Dónde se aplica | Prueba que la verifica |
|---|---|---|---|
| 1 | Precio/disponibilidad/política solo desde datos locales | `SearchCatalogSkill`, `SearchPolicySkill` leen exclusivamente `ICatalogRepository`/`IPolicyRepository` (JSON local); `FakeModelGateway.SelectControlledResponse` solo usa hechos inyectados explícitamente | `FakeModelGatewayTests.SelectControlledResponse_Price_OnlyUsesInjectedFacts`, `SearchCatalogSkillTests`, `SearchPolicySkillTests` |
| 2 | Recomendaciones citan los productos consultados | `RecommendProductSkill` filtra por categoría/presupuesto/disponibilidad y devuelve solo candidatos reales del catálogo | `RecommendProductSkillTests` (4 casos), `BuildGroundedResponseSkillTests.Build_CitesEveryRecommendedProduct_...` |
| 3 | Toda respuesta cita fuentes | `BuildGroundedResponseSkill.Build` adjunta `SourceReference` por cada producto/política usado | `BuildGroundedResponseSkillTests.Build_ReturnsSourceCitingTheProduct_...`, prueba de integración `PostChat_PriceQuestionForExistingProduct_...` (`Assert.NotEmpty(result.Sources)`) |
| 4 | Información faltante nunca se inventa | Sin coincidencia en catálogo/políticas, `BuildGroundedResponseSkill` devuelve un mensaje fijo de seguridad, sin fuentes | `BuildGroundedResponseSkillTests.Build_ReturnsFixedSafetyMessageWithNoSources_When...` (3 variantes) |
| 5 | Productos inexistentes se reportan con claridad | `SearchCatalogSkill` devuelve `null`; el mensaje fijo indica explícitamente que no se encontró el producto | `SearchCatalogSkillTests.Search_ReturnsNull_WhenProductDoesNotExist`, integración `PostChat_NonexistentProduct_EscalatesToHumanWithNoInventedData` |
| 6 | Casos de baja confianza se marcan para atención humana | `DetermineHumanHandoffSkill.Determine` con intención `Unknown` siempre escala | `DetermineHumanHandoffSkillTests.Determine_Escalates_OnUnknownIntent_ForLowConfidenceCases` |
| 7 | Quejas siempre escalan | `DetermineHumanHandoffSkill.Determine` con intención `Complaint` siempre escala, sin excepción | `DetermineHumanHandoffSkillTests.Determine_AlwaysEscalates_OnComplaintIntent`, integración `PostChat_Complaint_EscalatesToHumanAndProducesHandoffSummary` |
| 8 | Clientes molestos escalan | `FakeModelGateway.ClassifyIntent` prioriza `Complaint` sobre otras palabras clave presentes en el mismo mensaje | `FakeModelGatewayTests.ClassifyIntent_PrioritizesComplaintOverPolicyKeywords` |
| 9 | Solicitudes fuera de catálogo escalan | Precio/disponibilidad/recomendación sin coincidencia local fuerzan `RequiresHumanHandoff = true` | `DetermineHumanHandoffSkillTests.Determine_Escalates_WhenPriceIntentHasNoMatchedProduct`, `..._WhenRecommendationHasNoCandidates` |
| 10 | El resumen de handoff evita que el cliente repita la información | `FakeModelGateway.SummarizeForHumanHandoff` incorpora el mensaje original del cliente en el resumen entregado al humano | `FakeModelGatewayTests.SummarizeForHumanHandoff_IncludesOriginalCustomerMessage_SoHumanDoesNotAskAgain` |

`ChatResult` expone `HandoffReason` (visible al cliente en el chat) y `HumanSummary` (uso interno para el humano, con el mensaje original preservado) como campos separados; la interfaz del chat solo muestra `HandoffReason`, nunca `HumanSummary`, evitando exponer al cliente lenguaje de resumen interno.

## Datos ficticios (NovaCasa S.A.S.)

- `src/Centinela.Infrastructure/Data/catalog.json`: productos ficticios con código, nombre, categoría, precio, disponibilidad, características, casos de uso, advertencias y campo `source` explícito ("Catálogo ficticio NovaCasa S.A.S. — dato de demostración"). Incluye productos en stock, agotados (`OutOfStock`) y un producto de categoría cocina fuera de un presupuesto típico, usados específicamente para probar los filtros de `RecommendProductSkill`.
- `src/Centinela.Infrastructure/Data/policies.json`: políticas ficticias (devoluciones, garantía) con `topic`, `keywords` y campo `source` explícito.
- Ningún dato real de ninguna empresa o persona fue usado en ningún momento de esta fase.

## Escenarios conversacionales verificados (PASO 11)

Los 7 escenarios obligatorios se ejecutaron en vivo contra la pila completa (API en `http://localhost:5299` + Angular en `http://localhost:4200`, corriendo simultáneamente) y quedaron cubiertos además por pruebas automatizadas equivalentes:

1. Consulta de precio de producto existente → respuesta fundamentada con fuente citada, sin escalamiento.
2. Consulta de disponibilidad de producto existente.
3. Consulta de características de producto existente.
4. Consulta de política (devoluciones) existente.
5. Solicitud de recomendación con candidatos válidos en catálogo.
6. Producto inexistente → escalamiento a humano, cero fuentes inventadas, motivo de handoff claro.
7. Queja/cliente molesto → escalamiento a humano obligatorio, resumen de handoff generado con el mensaje original preservado.

## Endpoints REST expuestos

- `GET /health` — verificación de disponibilidad del servicio.
- `POST /api/chat` — recibe `ChatRequest { Message }`, devuelve `ChatResult` (mensaje, intención clasificada, fuentes, `RequiresHumanHandoff`, `HandoffReason`, `TraceId`).
- `GET /api/traces/{traceId}` — devuelve la traza de ejecución en memoria para un `TraceId` dado (404 si no existe).

CORS configurado explícitamente para permitir solo el origen del Chat Web local (`http://localhost:4200`), verificado con una solicitud `OPTIONS` de preflight real.

## Pruebas automatizadas

| Proyecto | Pruebas | Resultado |
|---|---|---|
| `Centinela.UnitTests` | 32 (Skills, `FakeModelGateway`) | 32/32 correctas |
| `Centinela.IntegrationTests` | 7 (`WebApplicationFactory<Program>`, extremo a extremo sobre la API real en memoria) | 7/7 correctas |
| Frontend (`web/centinela-web`, Karma + ChromeHeadless) | 7 (`ChatComponent`, `AppComponent`) | 7/7 correctas |
| **Total** | **46** | **46/46 correctas** |

- Build completo en modo `Release` de `Centinela.slnx`: correcto, 0 advertencias, 0 errores.
- `ng build` de `web/centinela-web`: correcto.
- Las pruebas de integración usan `Microsoft.AspNetCore.Mvc.Testing` sobre un `Program` marcado como `public partial class Program;` para permitir `WebApplicationFactory<Program>`; no abren puertos de red reales ni dependen de procesos externos.

## Validación local completa (PASO 12-13)

- Backend y frontend ejecutados simultáneamente en local (`http://localhost:5299` y `http://localhost:4200`), confirmado con los 7 escenarios en vivo.
- Tiempo de respuesta de la API observado por debajo de 10 segundos en todos los escenarios probados (respuestas locales sin llamadas de red externas, típicamente milisegundos).
- Cero llamadas a proveedores de IA externos: `FakeModelGateway` es la única implementación de `IModelGateway` registrada; no existe ninguna dependencia de paquete ni configuración hacia Microsoft Foundry, Azure OpenAI u otro proveedor.
- Cero secretos, cero credenciales, cero cadenas de conexión: no se usa base de datos; toda persistencia es en memoria o archivos JSON locales versionados como datos ficticios.
- Cero cambios de infraestructura Azure: ningún comando `az`, ningún archivo Bicep tocado en esta fase.
- Servidores de desarrollo (`dotnet run` en el puerto 5299, `ng serve` en el puerto 4200) detenidos limpiamente al cierre de esta fase; no quedan procesos en segundo plano.

## Decisiones y observaciones registradas

1. **Vulnerabilidades de dependencias Angular — riesgo aceptado, no corregido en esta fase.** `npm audit --omit=dev` reporta 7 vulnerabilidades (1 moderada, 6 altas) en `@angular/core <=19.2.25` y paquetes que dependen de él (`@angular/common`, `@angular/compiler`, `@angular/forms`, `@angular/platform-browser`, `@angular/platform-browser-dynamic`, `@angular/router`): `GHSA-58w9-8g37-x9v5` (bypass de sanitización en binding bidireccional, XSS) y `GHSA-rgjc-h3x7-9mwg` (DOM clobbering / envenenamiento de caché en hidratación de cliente). No existe una versión parcheada dentro de la serie 19.2.x; la única corrección disponible es `npm audit fix --force`, que instala Angular 21 (cambio disruptivo de versión mayor). **Decisión:** no se realizó el upgrade en esta fase. Justificación: el walking skeleton no usa hidratación de cliente ni SSR (la superficie vulnerable de `GHSA-rgjc-h3x7-9mwg`) y no expone bindings bidireccionales a contenido controlado por un atacante externo en un flujo de producción real (demo local, sin datos de usuarios reales). Un upgrade mayor de Angular está fuera de proporción para el alcance de esta fase y se deja como mejora técnica documentada para una fase posterior de endurecimiento (Fase 10, según `docs/planning/implementation-plan.md`).
2. **Angular CLI 19 usado en lugar de la última versión disponible.** Se generó el proyecto con Angular 19 (`@angular/cli ^19.2.27`) por compatibilidad con el entorno de desarrollo local disponible al iniciar la fase. Queda registrado como nota técnica, no como bloqueo — no afecta el alcance funcional del walking skeleton.
3. **Corrección de vinculación de puerto de la API detectada y corregida durante el desarrollo.** Al ejecutar `dotnet run --project src/Centinela.Api --no-launch-profile`, Kestrel se vinculó al puerto por defecto 5000 en lugar del puerto 5299 configurado, porque `--no-launch-profile` descarta también la configuración de `launchSettings.json` que fija el puerto. Corregido fijando explícitamente `ASPNETCORE_URLS=http://localhost:5299` en el entorno del proceso. No fue un defecto del código de la aplicación; no se requirió ningún cambio de código para resolverlo.
4. **Deserialización JSON en pruebas de integración.** `HttpContent.ReadFromJsonAsync<T>()` usa un `JsonSerializerOptions` propio en el cliente de prueba, independiente de la configuración `ConfigureHttpJsonOptions` del servidor. Se añadió un `JsonSerializerOptions` explícito (`PropertyNameCaseInsensitive = true` + `JsonStringEnumConverter`) en `ChatEndpointTests` para que el cliente de prueba interprete correctamente las claves en camelCase y los enums serializados como cadena que produce la API. No afecta el comportamiento real de la API frente a un cliente HTTP normal (navegador/Angular), que ya interpreta JSON de forma nativa sin este problema.

## Confirmaciones

- No se incluyeron secretos, tokens, llaves ni cadenas de conexión.
- No se incluyó información real de ninguna empresa o persona; todos los datos de catálogo y políticas son ficticios y están explícitamente marcados como tales (campo `source` en cada registro).
- No se usó Azure, Microsoft Foundry ni ningún proveedor de IA real; `FakeModelGateway` es la única implementación de `IModelGateway`.
- No se usó base de datos real; toda persistencia es en memoria o JSON local.
- El único canal implementado es Chat Web, conforme al alcance del MVP.
- No se realizó merge del Pull Request de esta fase (el PR se abre en el PASO 16, posterior a este reporte).
- No se inició la Fase 03.

## Acciones pendientes del desarrollador

- Ejecutar el escaneo de seguridad final (PASO 15) antes del primer commit.
- Revisar y aprobar (o solicitar ajustes a) este reporte y el Pull Request de la Fase 02 una vez abierto.
- Decidir si se prioriza el upgrade de Angular 19 → 21 (punto 1 de "Decisiones y observaciones registradas") en una fase de endurecimiento posterior.
- Autorizar explícitamente el inicio de la Fase 03 cuando corresponda; esta fase **no** avanza a Fase 03 por sí misma.
