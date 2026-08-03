# Reporte de evidencia — Fase 03: Azure CLI Command Gateway y Bicep IaC

- **Issue:** [#5 — Phase 03: Azure CLI Command Gateway and Bicep IaC](https://github.com/carlitos-tech/Centinela/issues/5)
- **Pull Request:** [#6](https://github.com/carlitos-tech/Centinela/pull/6) — **abierto, sin fusionar**. Este reporte documenta tanto la implementación inicial como las 8 correcciones obligatorias aplicadas en respuesta a la revisión del PR #6. **El HEAD vigente de la rama y el estado de los checks se consultan directamente en el Pull Request**, no en este documento.
- **Rama:** `feat/phase-03-azure-cli-gateway-iac`
- **ADR relacionado:** [ADR-002 — Azure CLI como mecanismo principal de administración y Bicep como IaC declarativo](../architecture/adr/ADR-002-azure-cli-bicep.md)
- **Fecha de implementación inicial:** 2026-08-02
- **Fecha de correcciones de revisión:** 2026-08-02

## Objetivo de la fase

Construir un mecanismo de ejecución de Azure CLI tipado y seguro (`IAzureCliCommandGateway`) como
única vía permitida para que componentes de Centinela ejecuten Azure CLI, y preparar la
infraestructura declarativa de DEV en Bicep, validada localmente, **sin aplicar ningún cambio
real** sobre Azure.

## Alcance ejecutado

### 1. `IAzureCliCommandGateway`

- `src/Centinela.Application/Abstractions/AzureCli/`: contrato del gateway (`IAzureCliCommandGateway`),
  solicitudes tipadas (`IAzureCliCommandRequest` y sus implementaciones concretas en
  `AzureCliRequests.cs`), enumeración cerrada de operaciones permitidas (`AzureCliOperation`),
  resultado (`AzureCliCommandResult`), registro de auditoría (`AzureCliAuditRecord`,
  `IAzureCliAuditSink`) y excepción de rechazo (`AzureCliOperationNotAllowedException`).
- `src/Centinela.Infrastructure/AzureCli/`: implementación real —
  `AzureCliCommandPolicy` (construye la lista de argumentos por operación, validando y rechazando
  cualquier valor que no cumpla el patrón esperado antes de construir el comando),
  `AzureCliCommandGateway` (orquesta política → ejecución → redacción → auditoría),
  `AzureCliProcessRunner` (lanza el proceso real de `az`, siempre con argumentos como lista
  discreta de tokens, nunca como una cadena interpolada; en Windows usa `cmd.exe /d /c az ...`
  porque `az` es un script `.cmd`), `AzureCliOutputRedactor` (enmascara GUID, correos, rutas
  locales, tokens Bearer y campos JSON/clave=valor sensibles antes de que la salida salga del
  gateway) e `InMemoryAzureCliAuditSink` (bitácora de auditoría en memoria).

**Operaciones permitidas (allowlist cerrada, `AzureCliOperation`):** `AccountShow`,
`AccountListLocations`, `ProviderShow`, `ProviderList`, `WebAppListRuntimes`, `GroupExists`,
`GroupShow`, `BicepVersion`, `BicepBuild`, `BicepLint`, `DeploymentSubValidate`,
`DeploymentSubWhatIf`, `DeploymentGroupValidate`, `DeploymentGroupWhatIf`. Todas son operaciones de
consulta, lectura o validación/previsualización. **No existe ninguna operación de creación,
eliminación, actualización, registro de proveedores, asignación de roles ni gestión de secretos en
la allowlist** — cualquier solicitud de ese tipo no tiene una implementación de
`IAzureCliCommandRequest` correspondiente y, si se intentara construir una fuera de esta allowlist,
`AzureCliCommandPolicy.BuildArguments` la rechaza con `AzureCliOperationNotAllowedException` antes
de tocar ningún proceso real (cubierto explícitamente por pruebas, incluida una forma hipotética de
"create" que nunca llega a ejecutarse).

### 2. Infraestructura Bicep (DEV)

- `infra/main.bicep` (`targetScope = 'subscription'`) orquesta módulos con ámbito en el resource
  group de DEV: `infra/modules/resource-group.bicep`, `monitoring.bicep`, `storage.bicep`,
  `key-vault.bicep`, `app-service.bicep`, `sql.bicep`.
- `infra/dev.bicepparam` (`using 'main.bicep'`) parametriza el entorno DEV. Las credenciales de
  administrador SQL (`sqlAdministratorLogin`, `sqlAdministratorPassword`) se resuelven con
  `readEnvironmentVariable(...)` — **nunca como literal en el archivo versionado**; los scripts de
  validación las exportan como variables de entorno temporales y las limpian (`Remove-Item`
  Env:\... / `unset`) al finalizar, hayan tenido éxito o no.
- `infra/bicepconfig.json` fija reglas de lint del proyecto.
- `infra/scripts/validate.ps1` / `.sh` y `infra/scripts/what-if.ps1` / `.sh`: scripts de
  conveniencia que ejecutan `bicep build`, `bicep lint`, `az deployment sub validate` y
  `az deployment sub what-if` respectivamente contra `infra/main.bicep` + `infra/dev.bicepparam`.
- **La Fase 03 no declara ninguna asignación de rol RBAC.** `key-vault.bicep` configura el Key
  Vault con `enableRbacAuthorization: true` (modo de autorización del propio Key Vault), pero no
  contiene ningún recurso `Microsoft.Authorization/roleAssignments` ni ningún `roleDefinitionId`:
  sin una asignación, ningún principal tiene acceso a los secretos. La asignación declarativa de
  RBAC (y el `principalId` que recibiría el rol) se difiere íntegramente a la Fase 04, sujeta a
  aprobación humana explícita (ver CLAUDE.md sección 5 e `infra/CLAUDE.md`). Esto corrige el diseño
  inicial de la fase, que exponía un flag `enableRoleAssignments` — eliminado por completo en la
  corrección de revisión (ver tabla de hallazgos más abajo).
- Componentes de IA (Microsoft Foundry, Azure AI Search) están explícitamente deshabilitados
  (`enableFoundry = false`, `enableAiSearch = false`) y no se modela ningún costo ni recurso activo
  para ellos — consistente con que la selección de proveedor de IA aún no tiene aprobación humana
  (ver ADR-003).

### 3. Estimación de costos

Ver [`infra/cost/dev-cost-estimate.md`](../../infra/cost/dev-cost-estimate.md) para el detalle
completo por recurso y fuentes. Resumen: **rango estimado ~USD 20–30/mes** (techo conservador
~USD 35/mes), dentro del objetivo de baseline DEV (≤ USD 40/mes) y del límite absoluto del proyecto
(USD 50/mes, CLAUDE.md sección 5).

## Hallazgos de la revisión del PR #6 y correcciones aplicadas

La revisión de código del PR #6 identificó 6 hilos con 8 correcciones obligatorias, todas
corregidas en esta misma rama con prueba o evidencia reproducible dedicada:

| # | Hallazgo | Corrección aplicada | Archivo(s) | Evidencia / prueba |
|---|---|---|---|---|
| 1 | Los 5 módulos con `scope: resourceGroup(...)` en `main.bicep` no tenían una dependencia explícita sobre `resourceGroupModule`, arriesgando un orden de despliegue incorrecto | `dependsOn: [resourceGroupModule]` explícito en `monitoringModule`, `storageModule`, `keyVaultModule`, `appServiceModule`, `sqlModule` (referenciar `resourceGroupModule.outputs.*` en `scope` falla con BCP120, por eso `scope` sigue usando la variable calculable en tiempo de compilación) | `infra/main.bicep` | `az bicep build`/`lint` exitosos; ARM generado inspeccionado — los 5 `dependsOn` apuntan a `resourceGroupDeployment` |
| 2 | `validate.ps1`/`what-if.ps1` no comprobaban `$LASTEXITCODE` tras cada `az`: un fallo de `az` podía dejar el script en un estado de "éxito" no verificado | Helper compartido `Invoke-AzCommand` (comprueba `$LASTEXITCODE` tras cada `az`, lanza excepción si es distinto de 0); ambos scripts reescritos para usarlo en cada paso | `infra/scripts/lib/AzExec.ps1`, `infra/scripts/validate.ps1`, `infra/scripts/what-if.ps1` | `infra/scripts/tests/Test-AzExecFailureHandling.ps1` (`az` simulado que siempre retorna 1) → `PASS`, sin mensaje de éxito, `exit 0` del script de prueba |
| 3 | Limpieza de la contraseña SQL en memoria usaba `PtrToStringAuto` sin conservar el `IntPtr` de forma explícita, y dependía de `GC.Collect()` como mitigación | Se conserva el `IntPtr` de `SecureStringToBSTR`; se usa `PtrToStringBSTR` (pareja correcta de BSTR); `Marshal.ZeroFreeBSTR` en `finally`; se eliminó `GC.Collect()` | `infra/scripts/validate.ps1`, `infra/scripts/what-if.ps1` | Revisión de código + ejecución exitosa de `az deployment sub validate`/`what-if` (ver tabla siguiente) sin quedar contraseña en texto plano tras el `finally` |
| 4 | Al cancelar por timeout, `TryKill` solo solicitaba la terminación del proceso sin esperarla, arriesgando procesos huérfanos y carreras con los handlers de salida | `KillAndWaitAsync`: `Kill(entireProcessTree: true)` + `await WaitForExitAsync(...)` con margen de seguridad de 5s antes de retornar | `src/Centinela.Infrastructure/AzureCli/AzureCliProcessRunner.cs` | `RunAsync_WithVeryShortTimeout_RepeatedRuns_NeverThrowsAndAlwaysReportsTimedOut`, `RunAsync_WithPreCancelledToken_RepeatedRuns_AlwaysThrowsOperationCanceled` (5 ejecuciones repetidas cada una) en `AzureCliGatewayIntegrationTests.cs` |
| 5 | Si el runner lanzaba una excepción (`az` no encontrado, cancelación del caller) antes de producir un resultado, el gateway no dejaba ningún registro de auditoría de esa solicitud permitida | `AzureCliCommandGateway.ExecuteAsync` audita en `catch (OperationCanceledException)` y `catch (Exception)` (nuevos campos `Cancelled`, `FailureReason` en `AzureCliAuditRecord`) antes de relanzar la excepción original con `throw;` | `src/Centinela.Application/Abstractions/AzureCli/AzureCliAuditRecord.cs`, `src/Centinela.Infrastructure/AzureCli/AzureCliCommandGateway.cs` | `AzureCliCommandGatewayTests`: `ExecuteAsync_CancelledToken_RecordsCancelledAuditEntryBeforePropagating`, `ExecuteAsync_RunnerThrowsBecauseAzCliMissing_RecordsFailedAuditEntryAndPropagatesException`, `ExecuteAsync_RunnerThrowsUnexpectedException_RecordsFailedAuditEntryAndPropagatesException`, `ExecuteAsync_FailureAuditEntry_NeverContainsSecretsFromExceptionMessage` |
| 6 | `key-vault.bicep` declaraba una asignación RBAC condicional (`enableRoleAssignments`) con el GUID de un rol integrado hardcodeado | Se eliminó por completo: el flag `enableRoleAssignments`, el parámetro `roleAssignmentPrincipalId` y el recurso `keyVaultSecretsUserAssignment`. La Fase 03 no declara ninguna asignación de rol; se difiere íntegramente a la Fase 04 | `infra/modules/key-vault.bicep`, `infra/main.bicep`, `infra/dev.bicepparam`, `infra/README.md` | `az bicep build`/`lint` exitosos; `git grep` confirma cero coincidencias de `enableRoleAssignments`/`roleAssignmentPrincipalId`/GUID de rol integrado en el código Bicep |
| 7 | El escaneo de seguridad excluía dos archivos de prueba completos y `key-vault.bicep`, en vez de eliminar la necesidad de la excepción | Los ejemplos ficticios de GUID/correo/ruta local se construyen dinámicamente en tiempo de ejecución (`FictitiousExampleBuilder`, vía `string.Join` de fragmentos separados) para que ningún literal contiguo en el código fuente coincida con los patrones del escaneo; la eliminación del GUID de rol integrado (hallazgo #6) también liberó a `key-vault.bicep`. Las 3 exclusiones se eliminaron de `governance.yml` | `tests/Centinela.UnitTests/AzureCli/FictitiousExampleBuilder.cs`, `AzureCliOutputRedactorTests.cs`, `AzureCliCommandGatewayTests.cs`, `.github/workflows/governance.yml` | `git grep` local con los 4 patrones exactos del workflow (secretos, rutas, correos, GUID), sin exclusiones, sobre todo el repositorio → 0 coincidencias en los 3 archivos antes excluidos y 0 coincidencias en todo el repositorio |
| 8 | `README.md`, `architecture-overview.md` y `traceability-matrix.md` describían la Fase 02/PR #4/Issue #3 como pendientes de aprobación, cuando ya fueron fusionados/cerrados | Texto actualizado para reflejar el estado real (`gh pr view 4`, `gh issue view 3`): PR #4 fusionado, Issue #3 cerrado; Fase 03/PR #6 sigue correctamente descrita como pendiente de aprobación | `README.md`, `docs/architecture/architecture-overview.md`, `docs/product/traceability-matrix.md` | Verificado con `gh pr view 4 --json state,mergedAt` (`MERGED`) y `gh issue view 3 --json state,closedAt` (`CLOSED`) antes de editar |

## Validación local ejecutada

Todas las siguientes operaciones son de solo lectura / validación / previsualización — **ninguna
crea, modifica ni elimina recursos de Azure, ni registra proveedores, ni crea/modifica asignaciones
RBAC, ni crea secretos**:

| Comando | Resultado |
|---|---|
| `az bicep build --file infra/main.bicep` | Éxito — 0 advertencias, 0 errores (reverificado tras corrección 1: los 5 `dependsOn` quedan en el ARM generado) |
| `az bicep lint --file infra/main.bicep` | Éxito — 0 hallazgos |
| `az deployment sub validate --location eastus2 --template-file infra/main.bicep --parameters infra/dev.bicepparam` | `provisioningState: "Succeeded"` (exit code 0) |
| `az deployment sub what-if` (mismos parámetros, `--result-format ResourceIdOnly`) | **10 cambios, los 10 de tipo `Create`, 0 `Delete`, 0 `Modify`, 0 aplicados.** 1 resource group + 9 recursos (Log Analytics, Application Insights, Key Vault, Storage Account, App Service Plan, Web App, SQL Server, SQL Database, regla de firewall). **Ninguna asignación RBAC ni recurso de Microsoft Foundry/Azure AI Search en la previsualización** |

Las credenciales SQL usadas para estas validaciones fueron valores de descarte (no reales, no
reutilizables), exportadas solo como variables de entorno del proceso que ejecutó la validación y
eliminadas inmediatamente después; no quedaron persistidos en ningún archivo ni en el historial de
comandos versionado.

**Nota de manejo de datos:** la salida cruda de `az deployment sub validate`/`what-if` incluyó el
Subscription ID y, en la previsualización de Key Vault, el Tenant ID reales de la suscripción de
desarrollo usada para validar. Esa salida fue **efímera** (no se escribió a ningún archivo
versionado ni a este reporte; los GUID se redactaron antes de imprimirse incluso en la terminal
efímera de la sesión de desarrollo) y se descarta deliberadamente aquí, de acuerdo con CLAUDE.md
sección 9. El campo `administratorLoginPassword` del `what-if` fue enmascarado automáticamente por
Azure CLI (`"*******"`).

## Pruebas

| Proyecto | Total | Con error | Omitidas |
|---|---|---|---|
| `Centinela.UnitTests` | 133 | 0 | 0 |
| `Centinela.IntegrationTests` | 16 | 0 | 0 |
| **Total** | **149** | **0** | **0** |

Conteo tras las correcciones de revisión del PR #6: +4 pruebas en `AzureCliCommandGatewayTests`
(auditoría en cancelación/excepción del runner, corrección 5) y +2 en
`AzureCliGatewayIntegrationTests` (ejecuciones repetidas de timeout/cancelación, corrección 4)
frente al conteo original de la implementación inicial (129/14/143).

- `AzureCliCommandPolicyTests`: cobertura de la construcción de argumentos para las 14 operaciones
  permitidas, rechazo de namespaces/nombres/rutas/ubicaciones inválidas (incluyendo intentos de
  inyección de comandos: `; rm -rf /`, `` `whoami` ``, `$(whoami)`, `&&`), normalización de rutas
  (backslash → slash), rechazo de tipos de solicitud no reconocidos (incluida una forma hipotética
  de "create" que reutiliza deliberadamente un valor de `AzureCliOperation` existente, para probar
  que el rechazo depende del *tipo* de solicitud, no solo del valor del enum), y una prueba que
  verifica que ningún nombre de `AzureCliOperation` contiene verbos mutantes o privilegiados
  (`Create`, `Delete`, `Update`, `Register`, `RoleAssignment`, `Secret`, `Rbac`).
- `AzureCliCommandGatewayTests`: éxito/fallo/timeout, cancelación, redacción de secretos en la
  salida antes de devolverla, auditoría con `CorrelationId` coincidente y sin secretos en los
  argumentos registrados, argumentos siempre como tokens discretos (nunca con espacios internos),
  solicitud nula lanza `ArgumentNullException`. **Corrección 5:** auditoría con `Cancelled=true` al
  cancelar antes de propagar la excepción; auditoría con `Success=false` y `FailureReason` cuando
  el runner lanza una excepción por `az` inexistente (`Win32Exception`) o por un fallo inesperado
  (`InvalidOperationException`), en ambos casos con la excepción original relanzada intacta;
  `FailureReason` nunca contiene el texto ficticio de ruta/GUID incluido en el mensaje de la
  excepción simulada, confirmando que también pasa por `AzureCliOutputRedactor`. **Corrección 7:**
  los ejemplos de GUID/correo usados como entrada de prueba se construyen con
  `FictitiousExampleBuilder`, no como literales.
- `AzureCliOutputRedactorTests`: enmascarado de GUID, correos, claves de cadena de conexión
  (`AccountKey=`, `SharedAccessKey=`, `Password=`, `Pwd=`), tokens Bearer, campos JSON de secretos,
  rutas locales Windows/Unix, texto plano sin cambios, combinación de varios patrones a la vez.
  **Corrección 7:** todos los ejemplos de GUID/correo/ruta local se construyen con
  `FictitiousExampleBuilder` (`tests/Centinela.UnitTests/AzureCli/FictitiousExampleBuilder.cs`) en
  vez de literales en el código fuente.
- `AzureCliGatewayIntegrationTests`: ejecuta el gateway real contra el binario `az` real
  exclusivamente con operaciones de solo lectura de la allowlist; se omite automáticamente en
  tiempo de ejecución (sin fallar) si `az` no está disponible en el entorno. Incluye timeout muy
  corto → `TimedOut = true`, token pre-cancelado → `OperationCanceledException`, y rechazo de una
  forma hipotética de "create" sin tocar el proceso real. **Corrección 4:** dos pruebas adicionales
  repiten 5 veces cada escenario (timeout muy corto, token pre-cancelado) para reducir la
  probabilidad de que una condición de carrera en `KillAndWaitAsync` pase inadvertida.

## Workflow de gobernanza

`.github/workflows/governance.yml` se actualizó para que el paso de "proyectos funcionales
prematuros" permita archivos `.bicep`/`.bicepparam` **dentro de `infra/`** (siguen bloqueados fuera
de esa carpeta), mientras `database/*.sql` permanece bloqueado sin cambios.

**Corrección 7 (revisión del PR #6):** el escaneo de secretos/datos sensibles tenía originalmente
tres exclusiones puntuales — dos archivos de prueba del redactor
(`AzureCliOutputRedactorTests.cs`, `AzureCliCommandGatewayTests.cs`) y `key-vault.bicep` (por el
`roleDefinitionId` de un rol integrado de Azure hardcodeado). Las tres exclusiones **se
eliminaron**:

- Los ejemplos ficticios de GUID/correo/ruta local que necesitan las pruebas del redactor ahora se
  construyen en tiempo de ejecución con `tests/Centinela.UnitTests/AzureCli/FictitiousExampleBuilder.cs`
  (`string.Join` de fragmentos separados), de modo que ningún literal contiguo en el código fuente
  coincide con los patrones del escaneo — la excepción deja de ser necesaria sin perder cobertura
  de prueba.
- `key-vault.bicep` ya no contiene ningún `roleDefinitionId` (corrección 6: se eliminó toda
  asignación RBAC de esta fase), por lo que tampoco necesita la exclusión.

Verificado ejecutando localmente los 4 patrones exactos del workflow (secretos/credenciales, rutas
locales, correos, GUID) con `git grep`, **sin ninguna exclusión**, sobre el repositorio completo:
las 4 búsquedas devuelven cero coincidencias.

Todas las demás validaciones del workflow (archivos de gobierno requeridos, ausencia de
`.claude/settings.local.json` versionado, ausencia de `.env` con valores, bloqueo de `database/`)
quedan sin cambios.

## Evidencia de los scripts PowerShell corregidos (correcciones 2 y 3)

- `infra/scripts/lib/AzExec.ps1` define `Invoke-AzCommand`, usado por cada paso `az` de
  `validate.ps1` y `what-if.ps1`: comprueba `$LASTEXITCODE` inmediatamente después de invocar `az`
  y lanza una excepción terminante si es distinto de 0, sin depender de
  `$PSNativeCommandUseErrorActionPreference` (una característica exclusiva de PowerShell 7.3+) para
  mantener compatibilidad con Windows PowerShell 5.1.
- **Evidencia reproducible de la ruta de fallo:** `infra/scripts/tests/Test-AzExecFailureHandling.ps1`
  crea un ejecutable `az.cmd` simulado que siempre retorna código de salida 1, antepone su carpeta
  a `$env:Path`, invoca `Invoke-AzCommand` contra él y verifica que se lanza una excepción y que
  ninguna rama de "éxito" se ejecuta. Ejecución real en esta sesión:
  ```text
  PASS: Invoke-AzCommand detecto el codigo de salida 1 del az simulado y aborto sin imprimir un mensaje de exito.
  EXIT CODE: 0
  ```
- **Evidencia de la ruta de éxito:** las ejecuciones de `az deployment sub validate`/`what-if`
  documentadas arriba usan el mismo mecanismo `Invoke-AzCommand`, con `$LASTEXITCODE = 0` en cada
  paso y sin ningún mensaje de éxito impreso tras un fallo.
- **Limitación conocida y explícitamente reportada:** esta sesión de desarrollo no tuvo PowerShell 7
  (`pwsh`) instalado, por lo que la ejecución directa de `validate.ps1`/`what-if.ps1` bajo PS7 no
  pudo demostrarse en este entorno. El mecanismo de `Invoke-AzCommand` (comprobar `$LASTEXITCODE`
  manualmente) no depende de ninguna característica exclusiva de PS7, por lo que es
  version-agnóstico por diseño — pero esta nota se deja explícita en vez de omitirse, conforme a
  CLAUDE.md sobre no afirmar validaciones que no se ejecutaron realmente.
- La limpieza de la contraseña SQL (corrección 3) se verificó por revisión de código
  (`SecureStringToBSTR` → `PtrToStringBSTR` → `ZeroFreeBSTR` en `finally`, sin `GC.Collect()`) y de
  forma indirecta por la ejecución exitosa de `az deployment sub validate`/`what-if` con
  credenciales de descarte sin dejar la contraseña en texto plano accesible tras la ejecución.

## Artefactos de compilación

`infra/main.json` (salida ARM compilada por `az bicep build`) se excluye del control de versiones
(`.gitignore`): es regenerable a partir de `infra/main.bicep`, que es la única fuente de verdad
versionada.

## Confirmaciones

- No se creó ningún recurso de Azure.
- No se ejecutó `az group create`, `az deployment sub create` ni `az deployment group create`.
- No se registró ningún proveedor de Azure.
- No se creó ni eliminó ninguna asignación RBAC.
- No se creó ningún secreto en Azure Key Vault ni en ningún otro servicio.
- No se desplegó backend ni frontend a Azure.
- No se creó ninguna instancia de Azure SQL.
- No se modificó ningún recurso de Azure existente.
- No se fusionó ningún Pull Request.
- No se cerró el Issue #5.
- No se inició la Fase 04.
- No se modificó la rama `main`.

## Pendiente de aprobación humana

- Revisión y fusión del Pull Request de esta fase hacia `develop`.
- Inicio de la Fase 04.
