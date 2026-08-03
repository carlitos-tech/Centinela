# Reporte de evidencia — Fase 03: Azure CLI Command Gateway y Bicep IaC

- **Issue:** [#5 — Phase 03: Azure CLI Command Gateway and Bicep IaC](https://github.com/carlitos-tech/Centinela/issues/5)
- **Rama:** `feat/phase-03-azure-cli-gateway-iac`
- **ADR relacionado:** [ADR-002 — Azure CLI como mecanismo principal de administración y Bicep como IaC declarativo](../architecture/adr/ADR-002-azure-cli-bicep.md)
- **Fecha:** 2026-08-02

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
- El único recurso condicionado a una asignación RBAC (`keyVaultSecretsUserAssignment` en
  `key-vault.bicep`) está detrás de un flag explícito (`enableRoleAssignments`, por defecto
  `false`) y de un `principalId` vacío por defecto — con los valores por defecto de
  `dev.bicepparam`, ese recurso **no se declara** en ningún despliegue de esta fase.
- Componentes de IA (Microsoft Foundry, Azure AI Search) están explícitamente deshabilitados
  (`enableFoundry = false`, `enableAiSearch = false`) y no se modela ningún costo ni recurso activo
  para ellos — consistente con que la selección de proveedor de IA aún no tiene aprobación humana
  (ver ADR-003).

### 3. Estimación de costos

Ver [`infra/cost/dev-cost-estimate.md`](../../infra/cost/dev-cost-estimate.md) para el detalle
completo por recurso y fuentes. Resumen: **rango estimado ~USD 20–30/mes** (techo conservador
~USD 35/mes), dentro del objetivo de baseline DEV (≤ USD 40/mes) y del límite absoluto del proyecto
(USD 50/mes, CLAUDE.md sección 5).

## Validación local ejecutada

Todas las siguientes operaciones son de solo lectura / validación / previsualización — **ninguna
crea, modifica ni elimina recursos de Azure, ni registra proveedores, ni crea/modifica asignaciones
RBAC, ni crea secretos**:

| Comando | Resultado |
|---|---|
| `az bicep build --file infra/main.bicep` | Éxito — 0 advertencias, 0 errores |
| `az bicep lint --file infra/main.bicep` | Éxito — 0 hallazgos |
| `az deployment sub validate --location eastus2 --template-file infra/main.bicep --parameters infra/dev.bicepparam` | `provisioningState: "Succeeded"` |
| `az deployment sub what-if` (mismos parámetros) | Previsualización: 10 cambios de recursos a crear (`Create`), 0 aplicados |

Las credenciales SQL usadas para estas validaciones fueron valores de descarte (no reales, no
reutilizables), exportados solo como variables de entorno del proceso que ejecutó la validación y
eliminados inmediatamente después; no quedaron persistidos en ningún archivo ni en el historial de
comandos versionado.

**Nota de manejo de datos:** la salida cruda de `az deployment sub validate`/`what-if` incluyó el
Subscription ID y, en la previsualización de Key Vault, el Tenant ID reales de la suscripción de
desarrollo usada para validar. Esa salida fue **efímera** (no se escribió a ningún archivo
versionado ni a este reporte) y se descarta deliberadamente aquí, de acuerdo con CLAUDE.md sección
9. El campo `administratorLoginPassword` del `what-if` fue enmascarado automáticamente por Azure CLI
(`"*******"`).

## Pruebas

| Proyecto | Total | Con error | Omitidas |
|---|---|---|---|
| `Centinela.UnitTests` | 129 | 0 | 0 |
| `Centinela.IntegrationTests` | 14 | 0 | 0 |
| **Total** | **143** | **0** | **0** |

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
  solicitud nula lanza `ArgumentNullException`.
- `AzureCliOutputRedactorTests`: enmascarado de GUID, correos, claves de cadena de conexión
  (`AccountKey=`, `SharedAccessKey=`, `Password=`, `Pwd=`), tokens Bearer, campos JSON de secretos,
  rutas locales Windows/Unix, texto plano sin cambios, combinación de varios patrones a la vez.
- `AzureCliGatewayIntegrationTests`: ejecuta el gateway real contra el binario `az` real
  exclusivamente con operaciones de solo lectura de la allowlist; se omite automáticamente en
  tiempo de ejecución (sin fallar) si `az` no está disponible en el entorno. Incluye timeout muy
  corto → `TimedOut = true`, token pre-cancelado → `OperationCanceledException`, y rechazo de una
  forma hipotética de "create" sin tocar el proceso real.

## Workflow de gobernanza

`.github/workflows/governance.yml` se actualizó para que el paso de "proyectos funcionales
prematuros" permita archivos `.bicep`/`.bicepparam` **dentro de `infra/`** (siguen bloqueados fuera
de esa carpeta), mientras `database/*.sql` permanece bloqueado sin cambios. El escaneo de
secretos/datos sensibles ganó tres exclusiones puntuales y documentadas en el propio workflow:

- Los archivos de prueba del redactor (`AzureCliOutputRedactorTests.cs`,
  `AzureCliCommandGatewayTests.cs`) contienen, deliberadamente, ejemplos de GUID/correo/ruta local
  **ficticios** en texto plano como entrada de prueba, para verificar que el redactor los
  enmascara — se excluyen puntualmente esos dos archivos (no `tests/` completo) de los escaneos de
  ruta/correo/GUID.
- `infra/modules/key-vault.bicep` referencia el `roleDefinitionId` de un rol integrado de Azure
  (Key Vault Secrets User): un GUID público y documentado por Microsoft, idéntico en cualquier
  tenant, no un Tenant ID ni Subscription ID — se excluye puntualmente ese archivo del escaneo de
  GUID.

Todas las demás validaciones del workflow (archivos de gobierno requeridos, ausencia de
`.claude/settings.local.json` versionado, ausencia de `.env` con valores, bloqueo de `database/`)
quedan sin cambios.

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
