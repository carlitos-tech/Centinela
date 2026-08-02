# Reporte de evidencia — Fase 02: Walking skeleton local

## Metadatos

- **Fecha/hora (America/Bogota):** 2026-08-02 (UTC-5)
- **Modelo y esfuerzo usados:** Sonnet 5, esfuerzo alto
- **Rama de trabajo:** `feat/phase-02-local-walking-skeleton` (creada desde `develop`)
- **Issue de la fase:** [#3 — Phase 02: Local walking skeleton](https://github.com/carlitos-tech/Centinela/issues/3)
- **Pull Request de la fase:** [#4](https://github.com/carlitos-tech/Centinela/pull/4) — **abierto, sin fusionar**. Este reporte documenta tanto la implementación inicial como las correcciones aplicadas en respuesta a la revisión del PR #4. **El HEAD vigente de la rama y el estado de los checks se consultan directamente en el Pull Request**, no en este documento — este reporte no registra el SHA de su propio commit contenedor.
- El check remoto configurado en el repositorio (`.github/workflows/`) es un **workflow de gobernanza** (valida estructura, convenciones, ausencia de secretos), **no** un pipeline de CI funcional que compile o ejecute pruebas. La validación funcional (build, pruebas, ejecución manual) descrita en este reporte se realizó **localmente**.

## Resultado

**PASS.** Se construyó un walking skeleton **totalmente local**: Chat Web (Angular) → API (.NET) → `CustomerServiceOrchestrator` → `CustomerServicePlugin` → 7 Skills → `FakeModelGateway` → catálogo/políticas ficticias en memoria → respuesta fundamentada con citación de fuentes → traza de ejecución en memoria. No se usó Azure, no se usó una base de datos real, no se llamó a ningún proveedor de IA real. Las 10 reglas antialucinación exigidas están implementadas de forma arquitectónica (no como prompt) y verificadas con pruebas automatizadas. Los 4 hallazgos de la revisión del PR #4 fueron corregidos con pruebas dedicadas, y Angular fue actualizado de la versión 19 a la 21 mediante `ng update` oficial. El cierre de la fase (merge del PR #4, cierre del issue #3) requiere aprobación humana explícita, que aún no se ha otorgado.

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

Frontend (`web/centinela-web`, **Angular 21 standalone**, sin NgModules): `ChatComponent` (Signals para `messages`/`loading`/`errorMessage`), `ChatService` (cliente HTTP hacia la API), `AppComponent` como shell con aviso permanente de datos ficticios de NovaCasa S.A.S.

## Reglas antialucinación (10) — implementación y verificación

| # | Regla | Dónde se aplica | Prueba que la verifica |
|---|---|---|---|
| 1 | Precio/disponibilidad/política solo desde datos locales | `SearchCatalogSkill`, `SearchPolicySkill` leen exclusivamente `ICatalogRepository`/`IPolicyRepository` (JSON local); `FakeModelGateway.SelectControlledResponse` solo usa hechos inyectados explícitamente | `FakeModelGatewayTests.SelectControlledResponse_Price_OnlyUsesInjectedFacts`, `SearchCatalogSkillTests`, `SearchPolicySkillTests` |
| 2 | Recomendaciones citan solo productos reales del catálogo, sin caer al catálogo completo cuando no hay coincidencia | `RecommendProductSkill` exige coincidencia de la necesidad del cliente contra categoría/nombre/casos de uso del producto (`TextNormalizer.ContainsAny`, con coincidencia de palabra/frase completa); si no hay coincidencia devuelve lista vacía de inmediato, sin usar el presupuesto como criterio único | `RecommendProductSkillTests` (9 casos, incluye `Recommend_ReturnsNoCandidates_WhenNeedDoesNotMatchAnyCatalogCategoryNameOrUseCase` y `Recommend_DoesNotFallBackToFullCatalog_WhenNoCategoryMatches_EvenIfBudgetFits`), integración `PostChat_RecommendationWithNoCatalogMatch_EscalatesWithNoIrrelevantProducts` |
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

- `src/Centinela.Infrastructure/Data/catalog.json`: productos ficticios con código, nombre, categoría, precio, disponibilidad, características, casos de uso, advertencias y campo `source` explícito ("Catálogo ficticio NovaCasa S.A.S. — dato de demostración"). Incluye productos en stock, agotados (`OutOfStock`) y productos fuera de las categorías típicas consultadas, usados específicamente para probar los filtros de `RecommendProductSkill`.
- `src/Centinela.Infrastructure/Data/policies.json`: políticas ficticias (devoluciones, garantía) con `topic`, `keywords` y campo `source` explícito.
- Ningún dato real de ninguna empresa o persona fue usado en ningún momento de esta fase.

## Hallazgos de la revisión del PR #4 y correcciones aplicadas

La revisión de código del PR #4 identificó 4 hallazgos, todos corregidos en esta rama con prueba dedicada:

| # | Severidad | Archivo / línea original | Hallazgo | Corrección aplicada | Prueba que lo verifica |
|---|---|---|---|---|---|
| 1 | P1 | `web/centinela-web/src/app/core/api-config.ts:5` | El puerto de la API configurado en el frontend no coincidía de forma garantizada con el puerto real de arranque de `dotnet run` (dependía del orden de perfiles en `launchSettings.json`) | Se fijó `applicationUrl` del perfil `http` (primer perfil, usado por defecto sin `--launch-profile`) en `src/Centinela.Api/Properties/launchSettings.json` a `http://localhost:5299`, coincidiendo con el valor ya versionado en `api-config.ts`. Se agregó una prueba que falla si README, `launchSettings.json` o `api-config.ts` alguna vez se desincronizan | `LocalPortConfigurationTests` (3 pruebas nuevas) |
| 2 | P1 | `src/Centinela.Application/Skills/RecommendProductSkill.cs:41` | Cuando ninguna categoría/producto/caso de uso coincidía con la necesidad del cliente, el Skill caía de vuelta al catálogo completo y recomendaba productos irrelevantes solo por ajustarse al presupuesto | Se eliminó el *fallback* al catálogo completo: sin coincidencia de necesidad (categoría, nombre o casos de uso) se devuelve lista vacía de inmediato, sin usar el presupuesto como criterio de inclusión | `RecommendProductSkillTests.Recommend_ReturnsNoCandidates_WhenNeedDoesNotMatchAnyCatalogCategoryNameOrUseCase`, `Recommend_DoesNotFallBackToFullCatalog_WhenNoCategoryMatches_EvenIfBudgetFits`, integración `PostChat_RecommendationWithNoCatalogMatch_EscalatesWithNoIrrelevantProducts` |
| 3 | P2 | `src/Centinela.Application/Skills/RecommendProductSkill.cs:56` | La extracción del presupuesto tomaba el primer número que aparecía en el mensaje, sin anclarlo a una frase de presupuesto, arriesgando interpretar como presupuesto un número no relacionado (p. ej. una cantidad de productos) | Extracción en dos etapas: primero se ubica una frase ancla de presupuesto (`presupuesto de`, `presupuesto máximo de`, `máximo de`, `máximo`, `hasta`) sobre texto normalizado; luego se busca el primer número **después** de esa ancla, soportando formatos `150000`, `150.000` y `$150.000` | `RecommendProductSkillTests.Recommend_ParsesBudget_AcrossNumberFormatsAndPhraseVariants` (6 variantes), `Recommend_DoesNotMisreadAnUnrelatedLeadingNumber_AsTheBudget` |
| 4 | P2 | `src/Centinela.Application/Common/TextNormalizer.cs:35` | `ContainsAny` usaba `string.Contains`, generando falsos positivos por coincidencia de subcadena (p. ej. "apagó" → "apago" contiene "pago", activando la política de pagos) | Reescrito con coincidencia de palabra/frase completa vía regex con límites `(?<!\w)...(?!\w)`, preservando insensibilidad a mayúsculas y tildes | `TextNormalizerTests` (6 pruebas nuevas, incluye el caso exacto "La lámpara se apagó, ¿qué hago?"), `FakeModelGatewayTests.ClassifyIntent_DoesNotMatchPolicyKeyword_AsArbitrarySubstring`, `SearchPolicySkillTests.FindByMessage_ReturnsNull_WhenKeywordOnlyMatchesAsArbitrarySubstring` |

Las respuestas individuales a cada comentario de revisión y el marcado de los hilos como resueltos se realizan después de que la corrección, su prueba y el workflow de gobernanza en verde estén confirmados sobre el mismo HEAD (ver "Acciones pendientes del desarrollador").

## Actualización de Angular 19 → 21

Realizada mediante los comandos oficiales `ng update`, avanzando por las versiones mayores necesarias (19 → 20 → 21), **sin usar `npm audit fix --force` como sustituto de la migración**:

```bash
npx ng update @angular/core@20 @angular/cli@20
npx ng update @angular/core@21 @angular/cli@21 --allow-dirty
```

(`--allow-dirty` fue necesario porque la rama ya tenía las correcciones de revisión sin commitear en el momento de ejecutar el segundo paso; es el mecanismo oficial soportado por `ng update` para ese caso, no un atajo que reemplace la migración guiada.)

- **Versión final:** `@angular/core`, `@angular/cli`, `@angular/compiler` y el resto de paquetes `@angular/*` en `21.2.19` (≥ 21.2.17 exigido). Verificado en `web/centinela-web/package.json`.
- **Compatibilidad de entorno:** Node `v24.13.1`, npm `11.8.0` — `npm install`, `ng build` y `npm test -- --watch=false` corrieron sin incidentes bajo esta versión de Node.
- **`package-lock.json`:** regenerado automáticamente por `ng update` en cada paso (incluye la fase de "Cleaning node modules directory" + "Installing packages").
- **`npm audit --omit=dev` (dependencias de producción):** **0 vulnerabilidades.**
- **`npm audit` completo (incluye dependencias de desarrollo):** 8 vulnerabilidades (6 moderadas, 2 altas), todas en herramientas de build de solo-desarrollo, transitivas a través de `@angular-devkit/build-angular` (`webpack-dev-server` → `sockjs` → `uuid`; `postcss`). Ninguna de estas dependencias se incluye en el bundle de producción generado por `ng build`. La corrección disponible (`npm audit fix --force`) instalaría `@angular-devkit/build-angular@22.x`, lo que forzaría un salto a Angular 22 — fuera del alcance solicitado para esta fase (Angular 21). **Decisión: riesgo aceptado y documentado**, dado que (a) son dependencias de solo-desarrollo, no de producción, y (b) esta fase corre exclusivamente en local, sin exposición pública del `dev-server`.
- **`ng build`:** correcto. Bundle inicial 216.76 kB (62.11 kB transferencia estimada).
- **`npm test -- --watch=false`:** 7/7 pruebas correctas (Karma + ChromeHeadless).
- Esto reemplaza la aceptación de riesgo registrada en una versión anterior de este reporte para Angular 19.2.x (`GHSA-58w9-8g37-x9v5`, `GHSA-rgjc-h3x7-9mwg`), que ya no aplica tras el upgrade.

## Escenarios conversacionales verificados

12 escenarios ejecutados en vivo contra la pila completa (API en `http://localhost:5299` + Angular en `http://localhost:4200`, ambos arrancados únicamente con `dotnet run --project src/Centinela.Api` y `npm start`, sin variables de entorno manuales), y cubiertos además por pruebas automatizadas equivalentes:

1. Consulta de precio de producto existente → respuesta fundamentada con fuente citada, sin escalamiento.
2. Consulta de disponibilidad de producto existente.
3. Consulta de características de producto existente.
4. Consulta de política (devoluciones) existente.
5. Solicitud de recomendación con candidatos válidos en catálogo (cocina, con presupuesto).
6. Solicitud de recomendación **fuera de catálogo** ("escritorio gamer", presupuesto 100.000) → cero candidatos, escalamiento a humano, cero productos irrelevantes, cero fuentes inventadas.
7. Recomendación con un número no relacionado antes de la frase de presupuesto ("Recomiéndame 2 productos de cocina con presupuesto de 150.000") → el presupuesto se interpreta correctamente como 150.000, no como 2.
8. Producto inexistente → escalamiento a humano, cero fuentes inventadas, motivo de handoff claro.
9. Queja/cliente molesto → escalamiento a humano obligatorio, resumen de handoff generado con el mensaje original preservado.
10. Mensaje con palabra que contiene una subcadena de una palabra clave de política, sin relación semántica real ("La lámpara se apagó, ¿qué hago?") → intención `Unknown`, escalamiento por baja confianza, **sin** activar por error la política de pagos.
11. Consulta de traza completa (`GET /api/traces/{traceId}`) sobre un caso resuelto → `Agent = CustomerServiceOrchestrator`, `Plugin = CustomerServicePlugin`, `SkillsUsed` incluye las 5 Skills ejecutadas (incluyendo `RecordTraceSkill` sin duplicados), `Intent`, `Sources`, `Result = Resolved` y `DurationMs` presentes.
12. `GET /health` → `200 OK`.

## Endpoints REST expuestos

- `GET /health` — verificación de disponibilidad del servicio.
- `POST /api/chat` — recibe `ChatRequest { Message }`, devuelve `ChatResult` (mensaje, intención clasificada, fuentes, `RequiresHumanHandoff`, `HandoffReason`, `TraceId`).
- `GET /api/traces/{traceId}` — devuelve la traza de ejecución en memoria para un `TraceId` dado (404 si no existe).

CORS configurado explícitamente para permitir solo el origen del Chat Web local (`http://localhost:4200`), verificado con una solicitud `OPTIONS` de preflight real.

## Pruebas automatizadas

| Proyecto | Pruebas | Resultado |
|---|---|---|
| `Centinela.UnitTests` | 54 (Skills, `FakeModelGateway`, `TextNormalizer`, configuración de puerto local) | 54/54 correctas |
| `Centinela.IntegrationTests` | 9 (`WebApplicationFactory<Program>`, extremo a extremo sobre la API real en memoria, incluye traza completa y recomendación fuera de catálogo) | 9/9 correctas |
| Frontend (`web/centinela-web`, Karma + ChromeHeadless, Angular 21) | 7 (`ChatComponent`, `AppComponent`) | 7/7 correctas |
| **Total** | **70** | **70/70 correctas** |

- Build completo en modo `Release` de `Centinela.slnx`: correcto, 0 advertencias, 0 errores.
- `ng build` de `web/centinela-web` (Angular 21): correcto.
- Las pruebas de integración usan `Microsoft.AspNetCore.Mvc.Testing` sobre un `Program` marcado como `public partial class Program;` para permitir `WebApplicationFactory<Program>`; no abren puertos de red reales ni dependen de procesos externos.

## Validación local completa

- Backend y frontend ejecutados simultáneamente en local (`http://localhost:5299` y `http://localhost:4200`), arrancados únicamente con `dotnet run --project src/Centinela.Api` y `npm start` (sin `ASPNETCORE_URLS` ni otra variable de entorno manual), confirmado con los 12 escenarios en vivo.
- Tiempo de respuesta de la API observado por debajo de 50 ms en todos los escenarios probados (respuestas locales sin llamadas de red externas).
- Cero llamadas a proveedores de IA externos: `FakeModelGateway` es la única implementación de `IModelGateway` registrada; no existe ninguna dependencia de paquete ni configuración hacia Microsoft Foundry, Azure OpenAI u otro proveedor.
- Cero secretos, cero credenciales, cero cadenas de conexión: no se usa base de datos; toda persistencia es en memoria o archivos JSON locales versionados como datos ficticios.
- Cero cambios de infraestructura Azure: ningún comando `az`, ningún archivo Bicep tocado en esta fase.
- Servidores de desarrollo (`dotnet run` en el puerto 5299, `ng serve`/`npm start` en el puerto 4200) detenidos limpiamente al cierre de esta validación; no quedan procesos en segundo plano.

## Decisiones y observaciones registradas

1. **Vinculación de puerto de la API — dos causas distintas identificadas y corregidas.**
   - Durante el desarrollo inicial, ejecutar `dotnet run --project src/Centinela.Api --no-launch-profile` vinculaba Kestrel al puerto por defecto 5000 en lugar de 5299, porque `--no-launch-profile` descarta la configuración de `launchSettings.json` que fija el puerto. No es un defecto de la aplicación: no se ejecuta con ese flag en el flujo documentado.
   - La revisión del PR #4 identificó un segundo riesgo real: sin depender de flags, `dotnet run` (sin argumentos) usa el **primer perfil** del objeto `profiles` de `launchSettings.json`, cuyo puerto no estaba explícitamente fijado a 5299 de forma verificable ni sincronizado con `api-config.ts`. Corregido fijando `applicationUrl` del perfil `http` a `http://localhost:5299` y agregando `LocalPortConfigurationTests`, que falla si README, `launchSettings.json` o `api-config.ts` se desincronizan en el futuro.
2. **Deserialización JSON en pruebas de integración.** `HttpContent.ReadFromJsonAsync<T>()` usa un `JsonSerializerOptions` propio en el cliente de prueba, independiente de la configuración `ConfigureHttpJsonOptions` del servidor. Se añadió un `JsonSerializerOptions` explícito (`PropertyNameCaseInsensitive = true` + `JsonStringEnumConverter`) en `ChatEndpointTests` para que el cliente de prueba interprete correctamente las claves en camelCase y los enums serializados como cadena que produce la API. No afecta el comportamiento real de la API frente a un cliente HTTP normal (navegador/Angular), que ya interpreta JSON de forma nativa sin este problema.
3. **`Centinela.Api.http` estaba desactualizado.** Referenciaba el puerto 5088 y el endpoint `/weatherforecast` de la plantilla por defecto de ASP.NET, nunca actualizado tras agregar los endpoints reales. Corregido para reflejar `http://localhost:5299`, `GET /health` y `POST /api/chat`.
4. **`README.md` no reflejaba el estado real de la Fase 02.** Seguía describiendo la Fase 01 como fase actual pese a que el walking skeleton ya estaba implementado. Reescrito por completo: estado de la fase, requisitos verificados, comandos de arranque sin variables de entorno manuales, URLs, ejemplos de consulta, comandos de prueba, y avisos explícitos de que `FakeModelGateway` no es IA real y que no se usa Azure.

## Confirmaciones

- No se incluyeron secretos, tokens, llaves ni cadenas de conexión.
- No se incluyó información real de ninguna empresa o persona; todos los datos de catálogo y políticas son ficticios y están explícitamente marcados como tales (campo `source` en cada registro).
- No se usó Azure, Microsoft Foundry ni ningún proveedor de IA real; `FakeModelGateway` es la única implementación de `IModelGateway`.
- No se usó base de datos real; toda persistencia es en memoria o JSON local.
- El único canal implementado es Chat Web, conforme al alcance del MVP.
- El Pull Request #4 de esta fase permanece **abierto y sin fusionar**; su fusión requiere aprobación humana explícita.
- No se inició la Fase 03.

## Acciones pendientes del desarrollador

- Ejecutar el escaneo de seguridad final sobre el conjunto completo de cambios antes del commit y push de esta corrección.
- Confirmar en verde el workflow de gobernanza sobre el HEAD que incluye estas correcciones antes de marcar resueltos los 4 hilos de revisión del PR #4.
- Revisar y aprobar (o solicitar ajustes adicionales a) este reporte y el Pull Request #4.
- Autorizar explícitamente la fusión del PR #4 y el inicio de la Fase 03 cuando corresponda; esta fase **no** avanza a Fase 03 ni se fusiona por sí misma.
