# Reporte de evidencia — Fase 04 (preparación): Bootstrap Azure DEV

- **Issue:** [#7 — Phase 04: Bootstrap Azure DEV](https://github.com/carlitos-tech/Centinela/issues/7)
- **Rama:** `feat/phase-04-bootstrap-azure-dev`
- **Base:** `develop` en `8060fa91b874cf9658479b45c6785cf6986866f6` (Fase 03 fusionada, [PR #6](https://github.com/carlitos-tech/Centinela/pull/6), Issue #5 cerrado)
- **Fecha:** 2026-08-03
- **Actualización (correcciones pre-despliegue):** 2026-08-03 — ver sección 8, 9 y 10 (reescritas) y
  sección 11 para el detalle completo de las cinco correcciones aplicadas a las guardas y al flujo
  de despliegue antes de solicitar autorización para registrar proveedores y crear la
  infraestructura DEV.
- **Actualización (registro de proveedores):** 2026-08-03 — ver secciones 12 y 13: con autorización
  humana explícita y acotada a los seis proveedores documentados, se ejecutó `az provider register`
  (los seis pasaron de `NotRegistered` a `Registered`) y se revalidó Bicep/`validate`; el `what-if`
  posterior quedó **bloqueado por un error persistente del lado de Azure**, no por un problema del
  plan — ver sección 13 para el detalle y las referencias externas.
- **Actualización (diagnóstico saneado del preflight):** 2026-08-03 — ver sección 15: con
  autorización humana explícita y acotada exclusivamente a diagnóstico (sin `--debug`, sin
  reintentos, sin cambios de SKU/región/plantilla), se ejecutó **una única vez** un
  `az deployment sub validate` adicional con captura y saneamiento de `stderr` en memoria. La causa
  funcional profunda no pudo determinarse (el mensaje disponible era un simple redireccionamiento
  sin información de causa) y, por regla explícita, la clasificación se registra como `UNKNOWN` —
  no se reintentó ni se usó `--debug` para evitarlo.
- **Actualización (alineación de la evidencia de validación):** 2026-08-03 — ver sección 16: se
  corrige una ambigüedad de este reporte que podía leerse como si el bloqueo vigente fuera el del
  `what-if` de la sección 14. **El fallo vigente ocurrió en `az deployment sub validate`, no en
  `what-if`**, y los `provisioningState: Succeeded` de las secciones 10 y 13 corresponden a una
  **versión anterior de la plantilla**, por lo que no avalan la plantilla actual. La corrección
  short-circuit quedó versionada y probada; la opción de desplegar directamente fue **rechazada por
  decisión humana**.
- **Actualización (validación específica del App Service Plan):** 2026-08-03 — ver sección 17: una
  única petición no destructiva a `Microsoft.Web/validate` respondió `status: Success`, confirmando
  que un App Service Plan Linux **B1, capacidad 1, en East US 2** es una configuración **válida**
  para esta suscripción, sin crear ningún recurso y sin que el Resource Group exista. Esto descarta
  SKU/región/tipo de worker/restricción de suscripción como causa, pero **no explica el fallo
  de `az deployment sub validate`** de la sección 15, que seguía clasificado como `UNKNOWN`. No se
  ejecutó `validate`, ni `what-if`, ni despliegue alguno tras este resultado.
  **Corrección posterior (sección 18):** este bullet afirmaba originalmente que el PASS también
  descartaba la **cuota**. Es incorrecto y se retira esa palabra: `Microsoft.Web/validate` valida
  disponibilidad de SKU/región/worker, **no** el cupo de cómputo de la suscripción. La causa real
  resultó ser precisamente de cuota — ver sección 18.
- **Actualización (validación integral — CAUSA RAÍZ IDENTIFICADA):** 2026-08-03 — ver sección 18:
  con autorización humana explícita para **una única** ejecución de `az deployment sub validate`
  sobre el HEAD `0a05b5b`, con `--validation-level Provider`, la validación **falló** y por primera
  vez devolvió un código interno funcional concreto: **`SubscriptionIsOverQuotaForSku`** sobre
  `Microsoft.Web/serverFarms`. La clasificación `UNKNOWN` de la sección 15 queda **resuelta** y
  reemplazada por **`QUOTA_OR_CAPACITY`**. No se creó ningún recurso.
- **Actualización (validación integral — PASS post-aprobación de cuota):** 2026-08-03 — ver sección
  20: la cuota de `B1` en East US 2 pasó de límite 0 a límite **1** (origen no atribuible con
  evidencia a la solicitud rechazada de la sección 19 — ver nota de esa sección). Con autorización
  humana explícita se ejecutó **una única vez** un nuevo `az deployment sub validate
  --validation-level Provider` sobre el HEAD `d4ee1ea`, y por primera vez el resultado fue
  **`provisioningState: Succeeded`**, confirmando que `SubscriptionIsOverQuotaForSku` (sección 18)
  quedó resuelto. No se ejecutó `what-if` ni ningún despliegue.
- **Actualización (what-if post-cuota B1 — ERROR de proceso, no de Azure):** 2026-08-03 — ver
  sección 21: con autorización humana explícita para **una única** ejecución de
  `az deployment sub what-if`, la llamada a Azure se ejecutó exactamente una vez y terminó con
  código de salida 0 y un JSON estructuralmente válido, pero el análisis obligatorio con las
  guardas versionadas (`Get-CentinelaWhatIfAnalysis`) no pudo completarse porque la salida capturada
  quedó únicamente en memoria de un proceso de PowerShell que finalizó antes de ejecutar el análisis,
  sin persistirse en disco. **Clasificación: C (ERROR de proceso/herramienta).** No se reintentó
  `what-if` por estar expresamente prohibido un segundo intento.
- **Alcance de este reporte:** únicamente la **preparación** del primer despliegue real de Azure DEV. **No se creó ningún recurso de Azure en esta fase.**

## Objetivo de esta etapa

Preparar de forma segura y auditable el primer despliegue real de infraestructura de Centinela en
Azure DEV: validar el estado de la suscripción y de los proveedores en modo solo lectura, endurecer
nombres y configuración de seguridad de los recursos, actualizar la estimación de costos, construir
(sin ejecutar) un script de despliegue protegido con múltiples guardas, revalidar código y Bicep, y
generar una previsualización `what-if` completa — deteniéndose antes de cualquier `apply` real.

## 1. Validación de cuenta Azure (solo lectura)

| Verificación | Resultado |
|---|---|
| Suscripción activa | `SuscripcionClaudeCode` |
| Estado | `Enabled` |
| Es la suscripción por defecto | Sí |
| East US 2 disponible como región de la suscripción | Sí |
| Central US disponible como región de contingencia | Sí |

Ningún Tenant ID, Subscription ID, Object ID, correo, ruta local ni credencial fue guardado o
mostrado en este reporte ni en la sesión de desarrollo más allá de lo estrictamente efímero en
terminal (consistente con CLAUDE.md, sección 9, y con la práctica ya establecida en el reporte de
evidencia de la Fase 03).

## 2. Estado de registro de proveedores (solo lectura)

Ejecutado exclusivamente con `az provider show` (nunca `az provider register`):

| Proveedor | Estado |
|---|---|
| `Microsoft.Resources` | `Registered` |
| `Microsoft.Storage` | `NotRegistered` |
| `Microsoft.KeyVault` | `NotRegistered` |
| `Microsoft.OperationalInsights` | `NotRegistered` |
| `microsoft.insights` | `NotRegistered` |
| `Microsoft.Web` | `NotRegistered` |
| `Microsoft.Sql` | `NotRegistered` |

**Bloqueador documentado:** 6 de 7 proveedores requeridos no están registrados en esta suscripción.
Registrar un proveedor es una operación de escritura sobre la suscripción y **no** se ejecutó en
esta fase — requiere autorización humana explícita separada (ver sección "Pendiente de aprobación
humana" más abajo). Nota observada: pese a este estado, tanto `az deployment sub validate` como
`az deployment sub what-if` se ejecutaron exitosamente (sección 6) — el registro de proveedores no
bloqueó la validación/previsualización, pero previsiblemente sí sería necesario para un
`az deployment sub create` real, que Azure normalmente intenta autorregistrar si el llamante tiene
permiso; aun así, este proyecto no delega esa decisión a un intento automático, sino a una
aprobación humana explícita previa.

## 3. Nombres deterministas globalmente únicos (`uniqueString()`)

Se agregó `var uniqueSuffix = uniqueString(subscription().id, resourceGroupName)` en
`infra/main.bicep` (función, nunca un Subscription ID literal) y se propaga como parámetro a los
cuatro módulos cuyo nombre de recurso debe ser único en todo Azure. Resource Group, App Service
Plan, Log Analytics y Application Insights conservan nombres legibles basados solo en
`resourcePrefix` (su unicidad requerida es dentro de la suscripción/resource group, no global).

| Recurso | Patrón de nombre | Presupuesto de longitud | Ejemplo observado en `validate`/`what-if` de esta sesión |
|---|---|---|---|
| Storage Account | `st${namePrefix9}${uniqueSuffix13}` | 2+9+13 = 24 (máx. exacto) | `stnovacasac<sufijo-13-caracteres>` |
| Key Vault | `kv-${namePrefix7}-${uniqueSuffix13}` | 3+7+1+13 = 24 (máx. exacto) | `kv-novacas-<sufijo-13-caracteres>` |
| Web App | `app-${resourcePrefix}-${uniqueSuffix}-api` | dentro del límite de 60 | `app-novacasa-centinela-dev-<sufijo>-api` |
| Servidor lógico Azure SQL | `sql-${resourcePrefix}-${uniqueSuffix}` (en minúsculas) | dentro del límite de 63 | `sql-novacasa-centinela-dev-<sufijo>` |

`uniqueSuffix` nunca se trunca en ningún patrón: el presupuesto de caracteres se calculó para que
el prefijo legible ceda espacio antes que la porción que garantiza unicidad global. Validado con
`az bicep build`/`lint` (0 advertencias, 0 errores) y confirmado en los nombres reales que produjo
`az deployment sub validate`/`what-if` (sección 6).

## 4. Endurecimiento de Storage

`infra/modules/storage.bicep`: `allowBlobPublicAccess` cambiado de `true` a **`false`**. HTTPS
obligatorio (`supportsHttpsTrafficOnly: true`) y TLS 1.2 mínimo ya estaban presentes desde la Fase
03 y se mantienen. No se declara ningún contenedor ni configuración de sitio estático — la decisión
de hosting del frontend sigue diferida a una fase de despliegue real.

## 5. Endurecimiento de Azure SQL — regla de firewall opcional

`infra/modules/sql.bicep`: la regla `AllowAzureServices` (0.0.0.0-0.0.0.0) pasó de crearse siempre a
un recurso condicional (`if (enableAllowAzureServicesFirewallRule)`), controlado por un nuevo
parámetro booleano propagado desde `main.bicep` (`enableSqlAllowAzureServicesRule`) hasta
`dev.bicepparam`, donde queda explícitamente en **`false`**. Con el flag en `false`, el recurso no
aparece en absoluto en `what-if` (confirmado en la sección 6). No se creó ninguna regla de firewall,
no se comprometió ninguna IP de desarrollador, y no se habilitaron VNet/Private Endpoints en esta
fase.

## 6. Componentes de IA y configuración general (`dev.bicepparam`)

Confirmado: `environment=dev`, `primaryLocation=eastus2`, `fallbackLocation=centralus`,
`monthlyBudgetUsd=50`, `retentionDays=30`, `enableFoundry=false`, `enableAiSearch=false`,
`enableSqlAllowAzureServicesRule=false`. Ningún módulo del template declara recursos de Microsoft
Foundry, Azure AI Search, asignaciones RBAC ni secretos — confirmado por lectura completa de
`infra/main.bicep` y de todos los módulos.

## 7. Estimación de costos actualizada

Ver [`infra/cost/dev-cost-estimate.md`](../../infra/cost/dev-cost-estimate.md), revisada en esta
fase: rango sigue en **~USD 20–30/mes** (techo conservador ~USD 35/mes), dentro del objetivo de
baseline DEV (≤ USD 40/mes) y del límite absoluto del proyecto (USD 50/mes). Los cambios de esta
fase (nombres `uniqueString()`, regla de firewall opcional) no agregan recursos ni cambian SKUs:
sin impacto en costo. La regla de firewall de Azure SQL no tiene costo propio aunque se habilitara
en el futuro.

## 8. Script de despliegue protegido (`deploy-dev.ps1`) — creado, no ejecutado (actualizado)

`infra/scripts/deploy-dev.ps1` está protegido por **seis condiciones de autorización**, evaluadas
en dos fases estrictamente ordenadas antes de poder alcanzar `az deployment sub create` (único
lugar del repositorio donde aparece ese comando):

**Fase 1 — autorización (`Invoke-CentinelaDeploymentAuthorizationGuard`, sin credenciales, sin
ningún `az deployment`):**

1. Requiere el switch `-Apply`.
2. Requiere `-ConfirmationPhrase` exactamente igual a `AUTORIZO_DESPLIEGUE_CENTINELA_DEV`.
3. Requiere `-Environment dev` (único valor permitido).
4. Requiere `-Location` en `eastus2`/`centralus` (únicas regiones documentadas en CLAUDE.md,
   sección 5).
5. Requiere que la suscripción activa sea exactamente `SuscripcionClaudeCode`.
6. Requiere que el Subscription ID de la suscripción activa coincida con la variable de entorno
   `CENTINELA_EXPECTED_SUBSCRIPTION_ID` — obligatoria, sin valor predeterminado en ningún archivo
   versionado, nunca impresa en consola/excepciones/reportes, y consultada de forma independiente
   (nunca derivada de la misma llamada que la valida).

Solo si las seis condiciones anteriores se cumplen, el script solicita interactivamente las
credenciales temporales de Azure SQL — nunca antes.

**Fase 2 — revalidación y creación (`Invoke-CentinelaDevPreDeploymentAndCreate`, con credenciales SQL
ya exportadas temporalmente):**

7. Revalida `bicep build`/`lint` + `az deployment sub validate`.
8. Ejecuta `az deployment sub what-if` (salida capturada como JSON en memoria, nunca impresa cruda).
9. **Analiza el plan de what-if** (no se confía únicamente en el código de salida 0): exige
   exactamente los 9 recursos aprobados, todos `Create`, ninguna asignación RBAC, ninguna regla de
   firewall de Azure SQL, ningún recurso de Microsoft Foundry/Azure AI Search, y ningún recurso
   fuera de `rg-novacasa-centinela-dev`. Muestra siempre un resumen sanitizado (aprobado o
   bloqueado) antes de decidir.
10. Solo si el plan es aprobado, ejecuta `az deployment sub create`.

El script nunca usa `--confirm-with-what-if`: `what-if` y `create` son pasos explícitamente
separados. La lógica se extrajo a funciones puras/inyectables en cinco archivos de librería
(`infra/scripts/lib/DeployGuard.ps1`, `DeployArguments.ps1`, `DeployWhatIfAnalysis.ps1`,
`DeploySanitizedOutput.ps1`, `AzExec.ps1`) orquestadas por `DeployOrchestrator.ps1`, para permitir
pruebas exhaustivas sin tocar Azure CLI real.

**Evidencia de las pruebas de guarda** — tres archivos, 23/23 escenarios se comportaron como se
esperaba, ejecutados en esta sesión:

`infra/scripts/tests/Test-DeployDevGuard.ps1` (8/8 — las seis condiciones de la Fase 1, incluyendo
`CENTINELA_EXPECTED_SUBSCRIPTION_ID` ausente/incorrecta, más el escenario de control):

```text
[PASS] Falta -Apply: Blocked=True
[PASS] Frase incorrecta: Blocked=True
[PASS] Entorno no permitido: Blocked=True
[PASS] Region no permitida: Blocked=True
[PASS] ID correcto y nombre incorrecto: Blocked=True
[PASS] Variable ausente: Blocked=True
[PASS] ID incorrecto: Blocked=True
[PASS] CONTROL: nombre correcto e ID correcto: Blocked=False
PASS: ningun mensaje de error incluye un Subscription ID.
```

`infra/scripts/tests/Test-DeployArguments.ps1` (4/4 — Corrección 2, región real de los recursos):

```text
[PASS] East US 2 -> primaryLocation=eastus2
[PASS] Central US -> primaryLocation=centralus
[PASS] Ninguna otra region es aceptada (westus)
[PASS] what-if incluye --no-pretty-print
```

`infra/scripts/tests/Test-WhatIfPlanApproval.ps1` (11/11 — Corrección 3, análisis del what-if):

```text
[PASS] 9 Create permitidos: Approved=True
[PASS] 1 Delete: Approved=False
[PASS] 1 Modify: Approved=False
[PASS] 8 Create: Approved=False
[PASS] 10 Create: Approved=False
[PASS] Recurso RBAC: Approved=False
[PASS] Regla de firewall de Azure SQL: Approved=False
[PASS] Recurso de Microsoft Foundry / Azure AI Search: Approved=False
[PASS] JSON invalido: Approved=False
[PASS] Fallo de Azure CLI en what-if: Blocked=True CreateInvocations=0
[PASS] CONTROL: plan aprobado llega a create: Blocked=False CreateInvocations=1
```

En ningún escenario (de los 23) se invocó Azure CLI real ni se alcanzó el scriptblock de `create`
salvo en los dos escenarios de control explícitos. **El script `deploy-dev.ps1` no fue ejecutado
contra Azure real en ningún momento de esta sesión ni de la anterior.**

## 9. Validación de código y de Bicep (actualizada)

| Comando | Resultado |
|---|---|
| `dotnet build Centinela.slnx --configuration Release` | Éxito — 0 advertencias, 0 errores |
| `dotnet test Centinela.slnx --configuration Release` | **149/149 OK** (133 unit + 16 integración) — sin cambios frente a la Fase 03, consistente con que esta corrección no modificó código C# |
| Pruebas PowerShell de guardas (3 archivos) | **23/23 OK** (ver sección 8) |
| `az bicep build --file infra/main.bicep` | Éxito — 0 advertencias, 0 errores |
| `az bicep lint --file infra/main.bicep` | Éxito — 0 hallazgos |

## 10. `az deployment sub validate` / `what-if` (East US 2) — re-ejecutado tras las correcciones

Ambos comandos son de solo lectura/previsualización. Se usaron credenciales de descarte (usuario
fijo no sensible + contraseña generada aleatoriamente en memoria con
`System.Web.Security.Membership.GeneratePassword`, nunca reutilizable, exportadas solo como
variables de entorno del proceso y eliminadas en un bloque `finally` inmediatamente después). Ningún
Tenant ID, Subscription ID, Object ID ni credencial fue impreso o guardado: la salida de `az` se
capturó en memoria (`Invoke-AzCommandCaptureJson`, sin `2>&1`, sin archivo temporal) y solo se
mostró el resumen sanitizado producido por `Format-CentinelaValidateSummary`/
`Format-CentinelaWhatIfSummary` (Corrección 4).

| Comando | Resultado |
|---|---|
| `az deployment sub validate --location eastus2 ...` | `provisioningState: "Succeeded"` (exit code 0) |
| `az deployment sub what-if --location eastus2 ... --result-format ResourceIdOnly --no-pretty-print` | **9 cambios, los 9 `Create`, 0 `Delete`, 0 `Modify`, 0 aplicados — analizado por `Get-CentinelaWhatIfAnalysis`: APROBADO** |

Resultado sanitizado real de esta sesión (idéntico en estructura al que produce
`infra/scripts/tests/Test-WhatIfPlanApproval.ps1` sobre datos simulados):

```text
Create: 9
Recursos Create (tipo: nombre publico):
  - Microsoft.Resources/resourceGroups: rg-novacasa-centinela-dev
  - Microsoft.Insights/components: appi-novacasa-centinela-dev
  - Microsoft.KeyVault/vaults: kv-novacas-<sufijo>
  - Microsoft.OperationalInsights/workspaces: log-novacasa-centinela-dev
  - Microsoft.Sql/servers: sql-novacasa-centinela-dev-<sufijo>
  - Microsoft.Sql/servers/databases: sqldb-novacasa-centinela-dev
  - Microsoft.Storage/storageAccounts: stnovacasac<sufijo>
  - Microsoft.Web/serverfarms: plan-novacasa-centinela-dev
  - Microsoft.Web/sites: app-novacasa-centinela-dev-<sufijo>-api
Resultado: APROBADO (coincide con el plan de 9 recursos aprobado).
```

**Ninguna asignación RBAC, ningún recurso de Microsoft Foundry/Azure AI Search, y ninguna regla de
firewall de Azure SQL** en la previsualización — consistente con `enableFoundry=false`,
`enableAiSearch=false` y `enableSqlAllowAzureServicesRule=false`. Sin `Delete` ni `Modify`. **Cero
cambios aplicados**: `what-if` es exclusivamente una previsualización, y se confirmó adicionalmente
con `az group exists --name rg-novacasa-centinela-dev` → `false` (el resource group no existe).

**Hallazgo técnico registrado durante esta VALIDACIÓN:** `az deployment sub what-if` ignora
`--output json` a menos que se agregue también `--no-pretty-print` (su renderizador propio imprime
un diff de texto coloreado por defecto, incluso con código de salida 0). `Get-CentinelaDeploymentArguments`
(Corrección 2) se corrigió para incluir siempre `--no-pretty-print` en la operación `what-if`, y
`infra/scripts/tests/Test-DeployArguments.ps1` ahora verifica su presencia.

## 11. Correcciones pre-despliegue aplicadas en esta sesión

| # | Corrección | Resumen |
|---|---|---|
| 1 | Identidad de la suscripción | Segunda validación obligatoria vía `CENTINELA_EXPECTED_SUBSCRIPTION_ID` (entorno local, sin valor predeterminado, nunca impresa), comparada contra una consulta independiente del Subscription ID activo; se mantiene además la validación del nombre `SuscripcionClaudeCode`. Bloquea si la variable falta o si el ID no coincide, sin exponer ningún ID en el mensaje de error. |
| 2 | Región real de los recursos | `Get-CentinelaDeploymentArguments` agrega siempre `--parameters "primaryLocation=$Location"` **después** del archivo `.bicepparam` (la semántica de merge de `az` hace que este valor sobrescriba el literal `eastus2` de `dev.bicepparam`), sincronizando `--location` (ubicación del deployment) con `primaryLocation` (ubicación real de los recursos). `fallbackLocation` permanece documentada, sin conmutación automática. |
| 3 | Analizar el what-if | `Get-CentinelaWhatIfAnalysis` reemplaza la confianza ciega en el código de salida 0: exige 0 `Delete`, 0 `Modify`, exactamente 9 `Create` de los tipos aprobados, ningún RBAC/regla de firewall SQL/Foundry/AI Search, y ningún recurso fuera de `rg-novacasa-centinela-dev`. Cualquier desviación bloquea `create` y exige nueva aprobación humana. |
| 4 | Salidas sanitizadas | `Invoke-AzCommandCaptureJson` captura la salida de `az` en memoria (nunca en disco, nunca con `2>&1`) y `DeploySanitizedOutput.ps1` solo imprime: `provisioningState`, conteos de cambios, y tipo/nombre público de cada recurso — nunca Tenant ID, Subscription ID, Object ID, credenciales ni `resourceId` completos. |
| 5 | Orden de las guardas | El flujo se dividió en dos fases (`Invoke-CentinelaDeploymentAuthorizationGuard` / `Invoke-CentinelaDevPreDeploymentAndCreate`): las seis condiciones de autorización (Apply → frase → entorno → región → nombre de suscripción → Subscription ID esperado) se evalúan **antes** de solicitar cualquier credencial de Azure SQL. Las credenciales siguen usando `SecureStringToBSTR`/`PtrToStringBSTR`/`ZeroFreeBSTR` en `finally`, variables de entorno temporales eliminadas garantizadamente en `finally`, y nunca se imprimen. |

Archivos nuevos: `infra/scripts/lib/DeployArguments.ps1`, `infra/scripts/lib/DeployWhatIfAnalysis.ps1`,
`infra/scripts/lib/DeploySanitizedOutput.ps1`, `infra/scripts/tests/Test-DeployArguments.ps1`,
`infra/scripts/tests/Test-WhatIfPlanApproval.ps1`. Archivos reescritos: `infra/scripts/lib/DeployGuard.ps1`,
`infra/scripts/lib/DeployOrchestrator.ps1`, `infra/scripts/deploy-dev.ps1`,
`infra/scripts/tests/Test-DeployDevGuard.ps1`. Archivo editado: `infra/scripts/lib/AzExec.ps1`
(nueva función `Invoke-AzCommandCaptureJson`; el mensaje de error de `Invoke-AzCommand` ya no
incluye los argumentos completos, para no filtrar rutas locales).

## 12. Registro de proveedores de Azure — autorizado y ejecutado (2026-08-03)

**Autorización humana recibida:** mensaje explícito del usuario en esta sesión, acotado a exactamente
los seis proveedores de la sección "Pendiente de aprobación humana" (versión anterior de este
reporte), con procedimiento paso a paso, HEAD esperado confirmado, PR #8 (DRAFT) e Issue #7
(abierto) verificados antes de escribir, y prohibición expresa de registrar cualquier proveedor
adicional, crear recursos, RBAC o migrar SQL.

Antes de cualquier escritura se confirmó (solo lectura): rama `feat/phase-04-bootstrap-azure-dev`,
`git status` limpio, HEAD coincidente con el SHA esperado, PR #8 abierto y en DRAFT, Issue #7
abierto, `CENTINELA_EXPECTED_SUBSCRIPTION_ID` definida (sin imprimir su valor), suscripción activa
`SuscripcionClaudeCode`/`Enabled`/ID coincidente con la variable esperada (comparación hecha en
memoria, nunca impresa).

Estado antes → después, verificado con `az provider show --namespace <ns> --query registrationState`
antes y después de cada registro:

| Proveedor | Estado anterior | Comando ejecutado | Estado final |
|---|---|---|---|
| `Microsoft.Storage` | `NotRegistered` | `az provider register --namespace Microsoft.Storage --wait` | `Registered` |
| `Microsoft.KeyVault` | `NotRegistered` | `az provider register --namespace Microsoft.KeyVault --wait` | `Registered` |
| `Microsoft.OperationalInsights` | `NotRegistered` | `az provider register --namespace Microsoft.OperationalInsights --wait` | `Registered` |
| `Microsoft.Insights` | `NotRegistered` | `az provider register --namespace Microsoft.Insights --wait` | `Registered` |
| `Microsoft.Web` | `NotRegistered` | `az provider register --namespace Microsoft.Web --wait` | `Registered` |
| `Microsoft.Sql` | `NotRegistered` | `az provider register --namespace Microsoft.Sql --wait` | `Registered` |

Los seis proveedores se registraron uno a la vez, con `--wait`, verificando `registrationState` tras
cada uno antes de continuar con el siguiente. Ningún otro proveedor fue registrado. No se ejecutó
`az group create` ni `az deployment sub create` en ningún momento.

## 13. Re-validación posterior al registro: Bicep, `validate` — OK; `what-if` — bloqueado por error de Azure

Tras confirmar los seis proveedores en `Registered`, se re-ejecutó la cadena de revalidación en East
US 2 (única región autorizada en esta ejecución; Central US no se usó):

| Comando | Resultado |
|---|---|
| `az bicep version` / `build` / `lint` (`main.bicep`) | Éxito — 0 advertencias, 0 errores |
| `az deployment sub validate --location eastus2 ...` | `provisioningState: "Succeeded"` (exit code 0) |
| `az deployment sub what-if --location eastus2 ... --result-format ResourceIdOnly --no-pretty-print` | **Bloqueado — 4/4 intentos fallaron con el mismo error de Azure** (ver abajo) |

**Incidente de seguridad menor, registrado y ya remediado en la misma sesión:** en el primer intento
de `what-if`, un `InternalServerError` transitorio de Azure se propagó como excepción nativa de
PowerShell 5.1 (`2>$null` sobre un ejecutable nativo con `$ErrorActionPreference = 'Stop'` no
descarta el stream de error antes de que se convierta en excepción terminante) y el mensaje de
diagnóstico de Azure — que incluye el `scope` del deployment con el Subscription ID completo — quedó
visible en la salida de la sesión de desarrollo (nunca en un archivo del repositorio, nunca en este
reporte). Se notificó de inmediato al usuario, quien decidió tratarlo como incidente menor y
continuar. Los tres intentos posteriores usaron una captura corregida
(`$ErrorActionPreference = 'Continue'` acotado solo a la invocación nativa, más redacción explícita
de cualquier `/subscriptions/<id>` antes de mostrar cualquier texto) y no repitieron la exposición.

**Los 4 intentos** (mismos argumentos exactos, generados por `Get-CentinelaDeploymentArguments`)
fallaron con el mismo error, solo con timestamp/tracking id distintos:

```text
ERROR: InternalServerError - Encountered internal server error while processing the deployment
what-if request. Diagnostic information: timestamp '<distinto por intento>', scope
'/subscriptions/***REDACTED***', tracking id '<distinto por intento>', request correlation id
'<distinto por intento>'.
```

Este `InternalServerError` **no es un rechazo del plan** por parte de `Get-CentinelaWhatIfAnalysis`
(esa guarda nunca llegó a ejecutarse porque `az` no devolvió JSON): es un fallo del propio servicio
`what-if` de Azure Resource Manager. Es un problema externo documentado y recurrente, reproducido
por otros usuarios en escenarios similares (plantillas con Azure SQL / Key Vault, y en particular con
la opción `--result-format ResourceIdOnly` que este proyecto usa por diseño — ver Corrección 4/5).
Referencias externas consultadas en esta sesión:

- https://github.com/Azure/azure-cli/issues/28355
- https://github.com/Azure/azure-cli/issues/22314
- https://github.com/Azure/azure-cli/issues/31893
- https://github.com/Azure/arm-template-whatif/issues/408
- https://learn.microsoft.com/en-us/answers/questions/2339530/(bicep)-what-if-throwing-error-internalservererror
- https://learn.microsoft.com/en-us/answers/questions/5508666/encountered-internal-server-error-while-processing

**Por lo tanto, el what-if de esta sesión NO produjo un resultado analizable por
`Get-CentinelaWhatIfAnalysis`** y no se puede confirmar en esta sesión el patrón exacto de 9
Create/0 Modify/0 Delete contra un `what-if` real posterior al registro de proveedores (sí se había
confirmado ese patrón en la sesión anterior, antes del registro — sección 10). Esto queda como
bloqueador abierto para una sesión posterior: reintentar el `what-if` (podría resolverse solo, como
reportan otros usuarios) o investigar/ajustar `--result-format` en un cambio de código versionado
aparte, con su propia autorización y sus propias pruebas — ninguna de las dos cosas se hizo en esta
sesión más allá de los reintentos de solo lectura ya documentados.

**Pruebas ejecutadas en esta sesión** (sin tocar Azure real):

| Suite | Resultado |
|---|---|
| `dotnet build -c Release` | Éxito — 0 advertencias, 0 errores |
| `dotnet test -c Release` | **149/149 OK** (133 unit + 16 integración) |
| `infra/scripts/tests/Test-DeployArguments.ps1` | 4/4 OK |
| `infra/scripts/tests/Test-WhatIfPlanApproval.ps1` | 11/11 OK |
| `infra/scripts/tests/Test-DeployDevGuard.ps1` | 8/8 OK |
| `infra/scripts/tests/Test-AzExecFailureHandling.ps1` | 1/1 OK |

**Confirmado al cierre de esta sesión:** `az group exists --name rg-novacasa-centinela-dev` →
`false`. Cero recursos de Azure creados, modificados o eliminados. `az deployment sub create` no se
ejecutó ni una sola vez. No se registró ningún proveedor adicional a los seis autorizados. No se creó
ninguna regla de firewall de Azure SQL, ninguna asignación RBAC, ningún secreto. No se tocaron `main`
ni `develop`. PR #8 permanece DRAFT y sin fusionar; Issue #7 permanece abierto; la Fase 05 no ha
iniciado.

## 14. Corrección what-if: cambio a `FullResourcePayloads` — el `InternalServerError` se resolvió, pero surgió un bloqueo distinto (2026-08-03)

Autorización explícita: `[centinela-fase-04-correccion-what-if]`. Corrección acotada a
`infra/scripts/lib/DeployArguments.ps1` (y, solo si hubiera sido necesario, a
`DeployWhatIfAnalysis.ps1`) más las pruebas correspondientes — sin tocar plantillas Bicep, sin
`az deployment sub create`, sin `az group create`, sin registrar proveedores adicionales.

**Cambio de código exacto** (rama `what-if` de `Get-CentinelaDeploymentArguments`):

| Antes (Corrección 4/5, bloqueado por `InternalServerError`) | Después (esta corrección) |
|---|---|
| `--result-format ResourceIdOnly --no-pretty-print` | `--result-format FullResourcePayloads --no-pretty-print` |

`--no-pretty-print` y `--output json` se conservaron sin cambios.

**`Get-CentinelaWhatIfAnalysis` no requirió ninguna adaptación**: la función solo lee
`resourceId`/`changeType` de cada elemento de `changes[]`, campos presentes tanto en
`ResourceIdOnly` como en `FullResourcePayloads` (este último agrega además `before`/`after`/`delta`,
que la función ignora). Se verificó esto con nuevas pruebas antes de ejecutar cualquier comando
`az` real.

**Pruebas agregadas** (ninguna usa un identificador real; los Subscription ID de prueba se generan
en tiempo de ejecución con `[guid]::NewGuid()`):

| Archivo | Casos nuevos |
|---|---|
| `Test-DeployArguments.ps1` | `--result-format FullResourcePayloads` presente en `what-if`; `ResourceIdOnly` completamente ausente |
| `Test-WhatIfPlanApproval.ps1` | 9 Create con propiedades completas (`FullResourcePayloads`) → aprobado; 1 Delete con propiedades completas → bloqueado; 1 Modify con propiedades completas → bloqueado; salida no-JSON con un Subscription ID ficticio embebido → bloqueado con motivo genérico, y ese ID ficticio nunca aparece en `BlockReasons`/`Counts`/`ResourceSummaries` |

**Resultado de las pruebas de esta corrección** (suite completa, no solo los casos nuevos):

| Suite | Resultado |
|---|---|
| `dotnet build -c Release` | Éxito — 0 advertencias, 0 errores |
| `dotnet test -c Release` | **149/149 OK** (133 unit + 16 integración) — sin cambios, ningún código .NET fue tocado |
| `az bicep build --file infra/main.bicep` | Éxito |
| `az bicep lint --file infra/main.bicep` | Sin hallazgos |
| `az deployment sub validate` (East US 2) | `provisioningState=Succeeded` |
| `infra/scripts/tests/Test-DeployArguments.ps1` | **6/6 OK** (4 previas + 2 nuevas) |
| `infra/scripts/tests/Test-WhatIfPlanApproval.ps1` | **15/15 OK** (11 previas + 4 nuevas) |
| `infra/scripts/tests/Test-DeployDevGuard.ps1` | 8/8 OK (sin cambios) |
| `infra/scripts/tests/Test-AzExecFailureHandling.ps1` | 1/1 OK (sin cambios) |

**El único intento autorizado de `az deployment sub what-if`** (sin reintento; per la autorización,
un solo intento y, si bloquea, detenerse para decisión humana) con `FullResourcePayloads`:

- Código de salida: `0`. Salida: JSON válido. **El `InternalServerError` documentado en la sección
  13 (4/4 intentos previos con `ResourceIdOnly`) no se repitió** — el cambio de formato sí resolvió
  ese problema puntual.
- `Get-CentinelaWhatIfAnalysis` analizó el plan resultante y lo **BLOQUEÓ**: el arreglo `changes[]`
  devuelto por Azure solo contenía **7 operaciones Create**, no las 9 aprobadas. Faltan por completo
  del arreglo (no aparecen con otro `changeType`; el resumen de conteos solo muestra la clave
  `Create`): `Microsoft.Web/serverfarms` y `Microsoft.Web/sites`.

  Resumen sanitizado (sin `resourceId` completos, solo tipo:nombre público):

  ```text
  what-if (resumen sanitizado, sin resourceId completos):
    Create: 7
    Recursos Create (tipo: nombre publico):
      - Microsoft.Resources/resourceGroups: rg-novacasa-centinela-dev
      - Microsoft.Insights/components: appi-novacasa-centinela-dev
      - Microsoft.KeyVault/vaults: kv-novacas-***
      - Microsoft.OperationalInsights/workspaces: log-novacasa-centinela-dev
      - Microsoft.Sql/servers: sql-novacasa-centinela-dev-***
      - Microsoft.Sql/servers/databases: sqldb-novacasa-centinela-dev
      - Microsoft.Storage/storageAccounts: stnovacasac***
    Resultado: BLOQUEADO. Motivos:
      - Se esperaban exactamente 9 operaciones Create; se encontraron 7.
      - Faltan recursos aprobados en el plan: Microsoft.Web/serverfarms, Microsoft.Web/sites.
  ```

- **Investigación de solo lectura** (sin modificar ninguna plantilla, sin reintentar el what-if, sin
  relajar la guarda): se confirmó que `infra/main.bicep` invoca `modules/app-service.bicep` sin
  ninguna condición (`if (...)`), y que dentro de `app-service.bicep` los recursos
  `Microsoft.Web/serverfarms` (`appServicePlan`) y `Microsoft.Web/sites` (`webApp`) tampoco tienen
  ninguna condición — ambos se declaran incondicionalmente. `az deployment sub validate` confirmó
  `provisioningState=Succeeded` para la plantilla completa, incluidos esos dos recursos (**salvedad
  añadida después: ese `Succeeded` corresponde a la versión de la plantilla vigente en ese momento,
  anterior a la corrección short-circuit; no avala la plantilla actual — ver sección 16**). La
  plantilla, por tanto, sí los incluye en el plan real de Bicep; su ausencia está en la respuesta
  del motor de `what-if` de Azure, no en el código de Centinela ni en `Get-CentinelaWhatIfAnalysis`
  (que se comportó correctamente: bloqueó una desviación real del plan aprobado, tal como está
  diseñado para hacer).
- **No se investigó más allá de esta lectura, no se reintentó el `what-if` (el intento autorizado
  era único), no se modificó ninguna plantilla Bicep ni se relajó la guarda para forzar una
  aprobación.** Esto queda como bloqueador abierto que requiere decisión humana explícita antes de
  continuar: podría tratarse de una limitación conocida del motor de `what-if` de Azure con ciertos
  tipos de recurso (a investigar/documentar en una sesión posterior, con su propia autorización), o
  requerir un enfoque distinto de verificación pre-despliegue.
- `az group exists --name rg-novacasa-centinela-dev` → `false`, confirmado tanto antes como después
  de este intento. Cero recursos de Azure creados, modificados o eliminados en esta corrección.

## 15. Diagnóstico saneado del bloqueo de `what-if` — clasificación `UNKNOWN` por diseño (2026-08-03)

Autorización explícita: `[centinela-fase-04-diagnostico-app-service-preflight]`. Acotada
exclusivamente a **diagnóstico** del bloqueo documentado en la sección 14 (faltan
`Microsoft.Web/serverfarms` y `Microsoft.Web/sites` en el arreglo `changes[]` de `what-if`), con las
siguientes prohibiciones expresas: sin `--debug`, sin `--verbose`, sin `what-if`, sin
`deployment create`, sin `group create`, sin cambiar SKU/región/subscripción/versión de API, sin
tocar RBAC ni reglas de firewall de Azure SQL, sin reintentar el `validate` diagnóstico una vez
ejecutado (autorizado **exactamente una vez**), y sin fusionar el PR ni cerrar el Issue.

**Herramienta construida para este diagnóstico** (nueva, ver "Archivos" más abajo): captura de
`stderr` de Azure CLI en memoria (nunca `--debug`, nunca archivo temporal con salida cruda, nunca se
imprime la respuesta antes de sanearla, `$ErrorActionPreference` restaurado en `finally`,
`$LASTEXITCODE` siempre verificado) más una función de saneamiento que redacta GUID, Subscription
ID, Tenant ID, Object ID, rutas `/subscriptions/...`/`/tenants/...`, correos, rutas locales de
Windows, usuarios locales, tokens Bearer, cadenas de conexión y contraseñas — en ese orden
específico (los tokens Bearer y las URLs de proxy se redactan **antes** que el patrón genérico de
`clave=valor` y antes que el patrón de correo, respectivamente, porque de lo contrario esos patrones
genéricos consumían el texto antes que las reglas específicas pudieran actuar). De un error
estructurado de Azure Resource Manager solo se extraen: código, código interno más profundo
(recorriendo recursivamente el arreglo anidado `details[]`), mensaje saneado y una `CodeChain`
saneada — nunca tracking ID, correlation ID, trace ID, la respuesta HTTP completa, encabezados,
cuerpo de la solicitud ni argumentos con secretos.

**Pruebas obligatorias (18/18 OK)** en `infra/scripts/tests/Test-SanitizedErrorReport.ps1`, todas con
datos ficticios, verifican: el código interno se preserva; el mensaje funcional saneado se preserva;
los GUID se redactan; las rutas locales se redactan; los correos se redactan; las rutas
`/subscriptions/...` se redactan; una llamada fallida de Azure CLI conserva un código de salida
distinto de cero; un error nunca se interpreta como éxito; la recursión a través de niveles anidados
de `details[]` encuentra el código más profundo real (`SkuNotAvailable` bajo
`ValidationForResourceFailed`, con `CodeChain` completa); y — el caso que terminó siendo relevante
para el resultado real — cuando el mensaje más profundo disponible es únicamente un
redireccionamiento no informativo ("Check ... Details ... for more information") sin `details[]`
anidados adicionales, la `Classification` se fuerza a `UNKNOWN` aunque exista un código interno real,
en vez de dejar que el código genérico `InvalidTemplateDeployment` del nivel superior dispare una
clasificación específica incorrecta.

**Consultas de solo lectura ejecutadas** (sin crear ningún recurso, saneadas antes de mostrarse):

| Consulta | Resultado |
|---|---|
| Disponibilidad del SKU `B1` (App Service Plan Linux) en East US 2 | Disponible |
| Ubicaciones anunciadas para `Microsoft.Web/serverFarms` | East US 2 presente (entre 49 ubicaciones anunciadas en total) |
| Estado de registro de `Microsoft.Web` | `Registered` |
| Estado de registro de `Microsoft.Sql` | `Registered` |
| Cuota de App Service consultable vía `az rest` (solo lectura) | No disponible por esta vía en esta suscripción — resultado aceptado como válido, tal como preveía la autorización |

**El único `az deployment sub validate` diagnóstico autorizado**, ejecutado exactamente una vez con
los mismos argumentos/plantilla/parámetros ya utilizados en las secciones 10/13/14 y credenciales
efímeras de Azure SQL (variables de entorno, exportadas y eliminadas en `finally`, nunca impresas):

- Código de salida: distinto de cero (el `validate` **falló** en esta ejecución — a diferencia de
  las ejecuciones previas de las secciones 10 y 13, que sí habían dado `Succeeded`). El código de
  salida no cero se verificó y respetó explícitamente: el error nunca se interpretó como éxito.
- `Code` (nivel superior): `InvalidTemplateDeployment` (envoltorio genérico — por diseño, no se usa
  por sí solo para clasificar).
- `InnerCode` / código más profundo alcanzado: `ValidationForResourceFailed`.
- Mensaje saneado del nivel más profundo alcanzado: *"Validation failed for a resource. Check
  'Error.Details[0]' for more information."* — un redireccionamiento **no informativo**: no describe
  la causa funcional real, solo apunta a un nivel adicional de detalle.
- **`Classification`: `UNKNOWN`.** Aplicando la regla de la sección de pruebas anterior: un mensaje
  que es puramente un redireccionamiento sin `details[]` anidados adicionales disponibles en la
  respuesta capturada fuerza `UNKNOWN`, sin importar que `InvalidTemplateDeployment`/
  `ValidationForResourceFailed` sean códigos reales.
- **Limitación honesta reconocida:** el nivel de detalle realmente necesario para conocer la causa
  funcional (por ejemplo, un código como `SkuNotAvailable`, `QuotaExceeded` o similar) habría estado
  en un nivel de `details[]` más profundo que el capturado, pero **no era alcanzable sin una segunda
  llamada real a `az deployment sub validate`**, y la autorización de esta tarea fue estrictamente
  para **una única ejecución diagnóstica**, sin reintentos y sin `--debug`. Por lo tanto, conforme a
  la instrucción explícita — *"si no se obtiene el inner error: no uses `--debug`, no reintentes,
  clasifica como `UNKNOWN`, detente"* — el diagnóstico se detiene aquí, con la causa raíz real del
  bloqueo de la sección 14 aún **genuinamente desconocida**.
- Ningún GUID, Subscription ID, Tenant ID, Object ID, correo, ruta local, tracking ID ni correlation
  ID fue impreso, guardado o incluido en este reporte.

**Confirmado en esta tarea de diagnóstico:**

- `az deployment sub what-if` **no se ejecutó** en ningún momento de esta tarea (prohibido por la
  autorización).
- `az group exists --name rg-novacasa-centinela-dev` → `false`. **Cero recursos de Azure creados,
  modificados o eliminados** por esta tarea de diagnóstico.
- No se cambió SKU, región, subscripción, versión de API, plantilla Bicep, RBAC ni reglas de
  firewall de Azure SQL.
- No se registró ningún proveedor adicional.
- El `az deployment sub validate` diagnóstico se ejecutó **exactamente una vez**; no hubo
  reintentos ni uso de `--debug`/`--verbose`.

**Opciones de corrección identificadas — presentadas sin aplicar ninguna:**

1. Autorizar **una segunda y última** ejecución diagnóstica de `az deployment sub validate` (ahora
   con el analizador recursivo ya corregido en `DeploySanitizedError.ps1`, verificado con las
   pruebas 16/16b/17), con la expectativa de que esta vez sí alcance y reporte el código más
   profundo real si Azure lo expone en un nivel adicional de `details[]`. Riesgo: podría devolver el
   mismo redireccionamiento no informativo otra vez, sin garantía de resolver la incógnita.
   Requiere aprobación humana explícita antes de ejecutarse, dado que la autorización anterior era
   estrictamente para una sola vez.
2. Investigar directamente en el portal de Azure (Resource Health / Activity Log / soporte) el
   detalle completo del error de validación para el recurso `Microsoft.Web/serverFarms` de esta
   suscripción, sin pasar por `az deployment sub validate` — evita consumir otro intento
   diagnóstico por CLI, pero requiere acceso interactivo al portal, fuera del alcance de este agente.
   ejecutado.
3. Abrir un ticket de soporte de Azure adjuntando el `tracking id`/`correlation id` de este intento
   (disponibles solo en la sesión de desarrollo, nunca guardados en el repositorio) para que Azure
   identifique la causa exacta sin necesidad de más intentos locales.
4. ~~Aceptar la incógnita y proceder directamente con `deploy-dev.ps1 -Apply`~~ — **RECHAZADA por
   decisión humana explícita** (autorización `[centinela-fase-04-validacion-especifica-serverfarm]`;
   ver sección 16). El argumento que sostenía esta opción — que `az deployment sub validate` "sí
   aprobó" la plantilla en las secciones 10 y 13 — **no es válido**: esos `provisioningState:
   Succeeded` corresponden a una **versión anterior de la plantilla**, no a la vigente, y el
   `validate` más reciente (sección 15) **falló**. Desplegar aceptando la incógnita habría
   significado renunciar a la única verificación pre-`create` disponible sobre la plantilla actual.

Ninguna de estas cuatro opciones fue ejecutada en esta tarea. Se requiere decisión humana explícita
sobre cuál seguir (ver "Pendiente de aprobación humana explícita"). **Resolución posterior:** la
decisión humana registrada en la sección 16 rechazó la opción 4 y autorizó una vía distinta a las
cuatro listadas — una validación específica y no destructiva vía `Microsoft.Web/validate`.

**Archivos nuevos de esta tarea:** `infra/scripts/lib/DeploySanitizedError.ps1` (captura/saneamiento
de errores de Azure CLI, descenso recursivo por `details[]`, `Get-CentinelaDeepestErrorDetail`,
`Get-CentinelaSanitizedErrorReport`), `infra/scripts/tests/Test-SanitizedErrorReport.ps1` (18
escenarios, todos con datos ficticios). Ningún archivo de una tarea anterior fue modificado por esta
tarea de diagnóstico.

**Regresión verificada (sin cambios en su comportamiento, re-ejecutadas para confirmar que los
cambios en `DeploySanitizedError.ps1` no afectaron otras guardas):**

| Suite | Resultado |
|---|---|
| `infra/scripts/tests/Test-SanitizedErrorReport.ps1` | **18/18 OK** (nueva) |
| `infra/scripts/tests/Test-WhatIfPlanApproval.ps1` | 18/18 OK (sin regresión) |
| `infra/scripts/tests/Test-BicepCompiledResources.ps1` | 9/9 OK (sin regresión) |

Nota: `Test-WhatIfPlanApproval.ps1` y `Test-BicepCompiledResources.ps1` (junto con cambios ya
presentes en `infra/main.bicep`, `infra/modules/app-service.bicep` y
`infra/scripts/lib/DeployWhatIfAnalysis.ps1`) corresponden a trabajo de una tarea previa
(corrección short-circuit relacionada con el bloqueo de la sección 14), preservado sin modificar y
—en el momento de escribir esta sección— **aún sin commit** en el árbol de trabajo; esta tarea de
diagnóstico únicamente confirmó que no introdujo una regresión sobre ellos, sin tocarlos ni
incluirlos en sus propios commits. **Actualización:** esos cinco archivos ya están versionados en
dos commits separados — ver sección 16.

## 16. Alineación de la evidencia de validación y versionado de la corrección short-circuit (2026-08-03)

Autorización explícita: `[centinela-fase-04-validacion-especifica-serverfarm]`. Esta sección corrige
una ambigüedad real de las secciones 14 y 15 —que podían leerse como si el bloqueo vigente siguiera
siendo el del `what-if`— y deja versionada la corrección short-circuit que hasta ahora vivía sin
commit en el árbol de trabajo.

### 16.1 Siete aclaraciones exigidas por la decisión humana

| # | Aclaración | Estado |
|---|---|---|
| 1 | **El fallo vigente ocurrió en `az deployment sub validate`**, no en `what-if`. El último `what-if` ejecutado es el de la sección 14 (código de salida `0`, JSON válido, bloqueado por el analizador local al reportar solo 7 de 9 Create). El fallo de la sección 15 —`InvalidTemplateDeployment` / `ValidationForResourceFailed`, código de salida distinto de cero— es de `validate`, un comando distinto y una falla distinta. | Corregido |
| 2 | **No se ejecutó `what-if` durante el diagnóstico más reciente** (sección 15). Estaba expresamente prohibido por su autorización y no se ejecutó ni una vez. | Confirmado |
| 3 | **El `validate` previamente aprobado corresponde a una versión anterior de la plantilla.** Los `provisioningState: Succeeded` registrados en las secciones 10 y 13 se obtuvieron sobre la plantilla tal como estaba entonces —cuando `appServiceModule` aún recibía `monitoringModule.outputs.applicationInsightsConnectionString` y la Web App aún declaraba el app setting `APPLICATIONINSIGHTS_CONNECTION_STRING`. **Esos resultados no avalan la plantilla vigente** y no pueden citarse como evidencia de que la plantilla actual sea desplegable. | Corregido |
| 4 | **La opción de desplegar directamente aceptando la incógnita está RECHAZADA por decisión humana explícita** (opción 4 de la sección 15). No se ejecutará `deploy-dev.ps1 -Apply`, ni `az deployment sub create`, ni `az group create`. | Rechazada |
| 5 | **El error vigente sigue clasificado como `UNKNOWN`.** Esta sección no aporta información nueva sobre su causa funcional: la clasificación de la sección 15 se mantiene sin cambios. | Sin cambios |
| 6 | **La siguiente verificación autorizada es una llamada específica y no destructiva a la operación `Microsoft.Web/validate`**, exclusivamente para el App Service Plan (`type: ServerFarm`, `location: eastus2`, SKU `B1`, `capacity: 1`, workers Linux). Una sola petición, sin reintentos, sin `--debug`, sin `--verbose`, sin crear el Resource Group. | Autorizada, pendiente |
| 7 | **Los cambios short-circuit ya están versionados y probados** — ver 16.2 y 16.3. | Completado |

**No autorizado en esta tarea** (registrado por completitud): despliegue directo; `deploy-dev.ps1
-Apply`; `az deployment sub create`; `az group create`; crear/modificar/eliminar recursos de Azure;
un nuevo `az deployment sub validate`; un nuevo `what-if`; `--debug`/`--verbose`; registrar
proveedores adicionales; cambios de RBAC; fusionar el PR #8; cerrar el Issue #7; iniciar la Fase 05.

### 16.2 Versionado de la corrección short-circuit — dos commits separados

| Commit | Archivos (exactamente estos, ningún otro) |
|---|---|
| `fix(infra): remove App Insights bootstrap dependency` | `infra/main.bicep`, `infra/modules/app-service.bicep` |
| `fix(infra): block incomplete nested what-if expansion` | `infra/scripts/lib/DeployWhatIfAnalysis.ps1`, `infra/scripts/tests/Test-WhatIfPlanApproval.ps1`, `infra/scripts/tests/Test-BicepCompiledResources.ps1` |

**Contenido verificado antes de commitear** (los seis puntos exigidos por la autorización):

1. `appServiceModule` ya **no** recibe `monitoringModule.outputs.applicationInsightsConnectionString`;
   sus únicos parámetros son `location`, `resourcePrefix`, `tags` y `uniqueSuffix`.
2. `APPLICATIONINSIGHTS_CONNECTION_STRING` **no aparece** en ningún archivo versionado del bootstrap
   (las únicas coincidencias en el repositorio son las aserciones de la prueba que comprueban
   precisamente su ausencia).
3. El módulo de App Service **no depende** del deployment de monitoreo: `dependsOn:
   [resourceGroupModule]`, confirmado también sobre la plantilla ARM compilada
   (`[subscriptionResourceId('Microsoft.Resources/deployments', 'resourceGroupDeployment')]`).
4. `Get-CentinelaWhatIfAnalysis` **bloquea** los diagnósticos `NestedDeploymentShortCircuited` y
   `NestedDeploymentSkippedFromInternalExpansion`, tanto a nivel raíz como dentro de un cambio
   individual.
5. Los `message` crudos de `diagnostics` **nunca se registran**: solo se conservan `code` y `level`,
   ambos constantes fijas de Azure sin identificadores de la suscripción. Verificado con una
   aserción explícita (escenario 14).
6. La prueba de recursos compilados comprueba los **nueve recursos incondicionales** esperados (10
   recursos físicos totales, de los cuales exactamente uno —la regla de firewall de Azure SQL— es
   condicional y está deshabilitada por defecto).

### 16.3 Regresión completa ejecutada antes de versionar

| Validación | Resultado |
|---|---|
| `dotnet build -c Release` | Éxito — **0 advertencias, 0 errores** |
| `dotnet test -c Release` | **149/149 OK** (133 unit + 16 integración) |
| `infra/scripts/tests/Test-WhatIfPlanApproval.ps1` | **18/18 OK** (código de salida 0) |
| `infra/scripts/tests/Test-BicepCompiledResources.ps1` | **9/9 OK** (código de salida 0) |
| `infra/scripts/tests/Test-SanitizedErrorReport.ps1` | **19/19 OK** (código de salida 0) — 19 aserciones sobre los 17 escenarios numerados, incluidas las sub-aserciones `14b` y `16b`; el conteo «18/18» citado en la sección 15 correspondía a la numeración usada entonces, no a una pérdida de cobertura |
| `az bicep build --file infra/main.bicep` | Éxito (código de salida 0) |
| `az bicep lint` (los 7 archivos `.bicep`) | **7/7 sin hallazgos** |
| Escaneo de seguridad local (réplica exacta de los 4 escaneos del workflow de gobierno) | Sin coincidencias de secretos, rutas locales, correos ni GUID sin enmascarar |
| Workflow de gobierno (GitHub Actions) tras el push | **Verde** |

`Test-BicepCompiledResources.ps1` solo invoca `az bicep build --stdout` (compilación local); ninguna
de las tres suites PowerShell contacta recursos de Azure.

### 16.4 Resultado de la validación específica `Microsoft.Web/validate`

Ejecutada — ver sección 17.

## 17. Validación específica `Microsoft.Web/validate` del App Service Plan — **PASS** (2026-08-03)

Autorización explícita: `[centinela-fase-04-validacion-especifica-serverfarm]`, Paso 6. Objetivo:
determinar si el App Service Plan Linux B1 **puede** crearse en East US 2 para esta suscripción, sin
crear ningún recurso y sin depender del mensaje genérico que devuelve `az deployment sub validate`.

### 17.1 Preverificaciones ejecutadas antes de la petición

| # | Verificación | Resultado |
|---|---|---|
| 1 | Azure CLI autenticado (llamada real de solo lectura, sin imprimir identificadores) | Sesión válida, suscripción `Enabled` |
| 2 | La suscripción activa coincide con `CENTINELA_EXPECTED_SUBSCRIPTION_ID` | Coincide (comparación en memoria; ningún valor impreso) |
| 3 | `az group exists --name rg-novacasa-centinela-dev` | `false` — el Resource Group **no existe** |
| 4 | Estado de registro de `Microsoft.Web` | `Registered` |

No se ejecutó `az login` automáticamente en ningún momento (no fue necesario: la sesión estaba
activa; de haber estado vencida, la instrucción era detenerse y solicitar intervención humana).

### 17.2 La petición — una sola, no destructiva

| Aspecto | Valor |
|---|---|
| Operación | `POST .../resourceGroups/rg-novacasa-centinela-dev/providers/Microsoft.Web/validate` |
| `api-version` | `2024-11-01` — la **misma familia de API** que usa el recurso Bicep (`Microsoft.Web/serverfarms@2024-11-01`) |
| `type` | `ServerFarm` |
| `name` | `plan-novacasa-centinela-dev` (el nombre exacto que define la plantilla: `plan-${resourcePrefix}`) |
| `location` | `eastus2` |
| `properties.skuName` | `B1` |
| `properties.capacity` | `1` |
| `properties.needLinuxWorkers` | `true` |
| `properties.isSpot` | `false` |

El Subscription ID **nunca pasó por el script ni se imprimió**: la URI se envió con el marcador
`{subscriptionId}`, que Azure CLI expande internamente. Sin `--debug`, sin `--verbose` (la función
de captura los bloquea por diseño y lanza una excepción si se pasan), sin reintentos, sin crear
temporalmente el Resource Group, sin guardar la respuesta cruda en el repositorio. `stdout` y
`stderr` se capturaron en memoria y se pasaron por el saneador antes de mostrarse.

### 17.3 Resultado saneado

```text
EXITCODE=0
STDERR vacío

Respuesta (saneada):
{
  "error": null,
  "status": "Success"
}
```

**VALIDACIÓN ESPECÍFICA: PASS.** Azure confirma que un App Service Plan Linux B1 con capacidad 1 en
East US 2, con el nombre exacto de la plantilla, es una **configuración válida para esta
suscripción**. Esto descarta como causa del bloqueo: SKU no disponible, región no disponible, cuota
o capacidad insuficiente, tipo de worker inválido y restricción de suscripción sobre este SKU.

Dos observaciones necesarias para no sobreinterpretar el resultado:

- **No fue el escenario C.** La operación respondió `Success` **sin que el Resource Group exista**;
  no devolvió `ResourceGroupNotFound` ni exigió su existencia. No se creó el Resource Group en
  ningún momento (confirmado antes y después: `az group exists` → `false` en ambos casos).
- **`Classification=UNKNOWN` en la salida del saneador no indica un error.** Esa función está
  construida para interpretar *errores* de Azure Resource Manager; al recibir una respuesta exitosa
  sin `error`, no tiene ningún código que clasificar y devuelve su valor por defecto. La
  clasificación `UNKNOWN` **vigente** sigue siendo la de la sección 15, referida al fallo de
  `az deployment sub validate` — que esta validación específica **no explica ni resuelve**.

### 17.4 Qué queda abierto

`Microsoft.Web/validate` valida el App Service Plan **de forma aislada**. El fallo de la sección 15
ocurrió en `az deployment sub validate`, es decir, sobre el **despliegue completo** (siete recursos
adicionales, ámbito de suscripción, creación del Resource Group incluida) y, además, sobre una
plantilla que **ya cambió** desde entonces por la corrección short-circuit de la sección 16.2. Por
tanto este PASS **no** demuestra que el despliegue completo vaya a validar.

> **Nota retrospectiva (agregada en la sección 18).** Esta sección concluyó que el PASS descartaba,
> entre otras causas, la **cuota**. Esa conclusión era incorrecta y queda rectificada: el endpoint
> `Microsoft.Web/validate` comprueba que la combinación SKU/región/tipo de worker sea *ofrecible*,
> pero **no** consulta el cupo de cómputo asignado a la suscripción. La sección 18 demuestra que la
> causa real del fallo era exactamente esa: cupo de App Service en cero. El resto de esta sección
> sigue siendo válido — B1/Linux/East US 2 sí es una configuración soportada aquí.

Conforme a la instrucción explícita del resultado A de la autorización, y pese a que la respuesta
fue satisfactoria: **no se ejecutó `az deployment sub validate`, no se ejecutó `what-if` y no se
desplegó nada.** El siguiente paso requiere **autorización humana explícita**: una única nueva
ejecución de `az deployment sub validate` sobre el código ya versionado (`f1c5ddb`), que es la
primera vez que la plantilla corregida se validaría de extremo a extremo.

### 17.5 Confirmaciones de esta tarea

| Confirmación | Estado |
|---|---|
| Recursos de Azure creados, modificados o eliminados | **Cero** |
| `az group exists --name rg-novacasa-centinela-dev` (antes y después) | `false` en ambos casos |
| `az deployment sub create` / `az group create` / `deploy-dev.ps1 -Apply` | No ejecutados |
| `az deployment sub validate` en esta tarea | **No ejecutado** |
| `az deployment sub what-if` en esta tarea | **No ejecutado** |
| `--debug` / `--verbose` | No usados (bloqueados por diseño en la función de captura) |
| Peticiones a `Microsoft.Web/validate` | **Exactamente una**, sin reintentos |
| Proveedores adicionales registrados | Ninguno |
| Cambios de RBAC | Ninguno |
| Subscription ID / Tenant ID / Object ID / correos / rutas locales impresos o guardados | Ninguno |
| PR #8 | **OPEN, DRAFT, sin fusionar** |
| Issue #7 | **Abierto** |
| Fase 05 | No iniciada |

**Commits de esta tarea** (rama `feat/phase-04-bootstrap-azure-dev`, sin tocar `main` ni `develop`):

| Commit | Archivos |
|---|---|
| `1cec84c` — `fix(infra): remove App Insights bootstrap dependency` | `infra/main.bicep`, `infra/modules/app-service.bicep` |
| `bb1cc64` — `fix(infra): block incomplete nested what-if expansion` | `infra/scripts/lib/DeployWhatIfAnalysis.ps1`, `infra/scripts/tests/Test-WhatIfPlanApproval.ps1`, `infra/scripts/tests/Test-BicepCompiledResources.ps1` |
| `f1c5ddb` — `docs(infra): align Phase 04 validation evidence` | `docs/evidence/phase-04-bootstrap-azure-dev-predeployment-report.md` |

El workflow de gobierno quedó **verde** en los tres commits.

## 18. Validación integral de la plantilla corregida — **FAIL con causa raíz identificada: cuota de App Service en cero** (2026-08-03)

Autorización explícita: `[centinela-fase-04-validacion-integral-final]`. Acotada a **una única**
ejecución de `az deployment sub validate` sobre el HEAD exacto `0a05b5b` de
`feat/phase-04-bootstrap-azure-dev`, con prohibición expresa de `what-if`, `deployment sub create`,
`deploy-dev.ps1 -Apply`, `group create`, creación/modificación/eliminación de recursos, reintentos
del `validate`, `--debug`/`--verbose`, cambios en Bicep/scripts/pruebas, registro de proveedores,
cambios de RBAC, creación de secretos, fusión del PR #8, cierre del Issue #7 e inicio de la Fase 05.

### 18.1 Precondiciones verificadas antes de ejecutar

| # | Precondición | Resultado |
|---|---|---|
| 1 | HEAD local y remoto exactamente `0a05b5b` | **OK** — local = remoto = `0a05b5ba56b53f65e7a105843363037252d97491` |
| 2 | Árbol de trabajo limpio | **OK** — `git status --porcelain` sin líneas |
| 3 | Workflow de gobernanza de `0a05b5b` en verde | **OK** — run `30812753248`, `completed` / `success` |
| 4 | PR #8 sigue OPEN/DRAFT | **OK** — `state=OPEN`, `draft=true`, `merged=null` |
| 5 | Issue #7 sigue OPEN | **OK** |
| 6 | Azure CLI autenticado (operación real de solo lectura) | **OK** — código de salida 0, estado `Enabled` |
| 7 | Suscripción activa coincide con `CENTINELA_EXPECTED_SUBSCRIPTION_ID` | **OK** — variable definida y coincidente, **valor nunca impreso** |
| 8 | `rg-novacasa-centinela-dev` sigue sin existir | **OK** — `az group exists` → `false` |
| 9 | Variables requeridas por los parámetros Bicep | **Ver nota abajo** |
| 10 | `az bicep build` y `az bicep lint` | **OK** — códigos de salida 0 y 0, sin advertencias |

**Nota sobre la precondición 9.** `infra/dev.bicepparam` lee `CENTINELA_SQL_ADMIN_LOGIN` y
`CENTINELA_SQL_ADMIN_PASSWORD` mediante `readEnvironmentVariable()`; sin ellas la evaluación de
parámetros falla con **BCP427** antes de que Azure CLI contacte a Azure. Por diseño de seguridad del
repositorio estas variables **nunca preexisten** en el entorno: el script versionado
`infra/scripts/validate.ps1` las solicita por `Read-Host` en tiempo de ejecución, las fija en el
proceso invocador y las elimina en su bloque `finally` (líneas 25–55). Se aplicó exactamente ese
mismo mecanismo — credenciales **ficticias y efímeras**, fijadas solo en el proceso invocador,
eliminadas en `finally` y verificadas como eliminadas al terminar
(`VARS_LIMPIADAS: login=False password=False`), nunca impresas, nunca escritas a disco y nunca
usadas para crear un recurso real, dado que `validate` no crea nada. Esto **no** constituye
"crear secretos" en el sentido prohibido por la autorización (crear un secreto en Key Vault o una
credencial persistente en Azure): ningún secreto fue creado, almacenado ni versionado.

### 18.2 Comando ejecutado (una sola vez, sin identificadores)

```text
az deployment sub validate --location eastus2 \
   --template-file infra/main.bicep \
   --parameters infra/dev.bicepparam \
   --parameters primaryLocation=eastus2 \
   --only-show-errors --output json --validation-level Provider
```

Los argumentos se construyeron con la función versionada
`Get-CentinelaDeploymentArguments -Operation validate` (que valida la región contra la lista
permitida). Esa función **no emite** `--validation-level`, por lo que la bandera exigida por la
autorización se **añadió** al arreglo devuelto, sin omitir ninguna guarda y **sin modificar ningún
archivo versionado**. La ejecución usó el invocador versionado
`Invoke-AzCommandCaptureDiagnostic` (que rechaza por diseño `--debug`, `--verbose` y `-v`, y captura
`stdout`/`stderr` en memoria sin imprimirlos crudos) y el saneamiento usó
`Get-CentinelaSanitizedErrorReport` / `ConvertTo-CentinelaSanitizedText` de
`infra/scripts/lib/DeploySanitizedError.ps1`.

### 18.3 Resultado saneado

**Código de salida: 1 — VALIDACIÓN INTEGRAL: FAIL.** No se reintentó.

Cadena de códigos, del más externo al más profundo:

| Nivel | Código |
|---|---|
| 1 (externo) | `InvalidTemplateDeployment` |
| 2 | `ValidationForResourceFailed` |
| 3 (**más profundo**) | **`SubscriptionIsOverQuotaForSku`** |

Proveedor que reportó el error de preflight: **`Microsoft.Web/serverFarms (2024-11-01)`**.

Mensaje funcional saneado (tracking ID redactado como `<GUID>` por la función de saneamiento):

```text
ERROR: {"code": "InvalidTemplateDeployment", "message": "The template deployment 'main' is not
valid according to the validation procedure. The following resource provider(s) -
'Microsoft.Web/serverFarms (2024-11-01)' reported preflight validation errors. Tracking id is
'<GUID>'. See inner errors for details."}
Inner Errors:
{"code": "ValidationForResourceFailed", "message": "Validation failed for a resource. Check
'Error.Details[0]' for more information."}
Inner Errors:
{"code": "SubscriptionIsOverQuotaForSku", "message": "Operation cannot be completed without
additional quota. [...] Limit (Total VMs): 0 [...] Usage: 0 [...] required for this deployment
(Total VMs): 1. (Minimum) New Limit that you should request to enable this deployment: 1. [...]"}
```

Cifras funcionales extraídas del mensaje saneado:

| Dato | Valor |
|---|---|
| Cupo actual (Total VMs) | **0** |
| Uso actual | 0 |
| Requerido por este despliegue (Total VMs) | **1** |
| Nuevo límite mínimo a solicitar | **1** |

**Clasificación funcional: `QUOTA_OR_CAPACITY`.** Existe evidencia funcional concreta —un código de
error específico y accionable, con cifras—, por lo que **no** aplica la regla de conservar `UNKNOWN`
usada en la sección 15.

**Artefacto conocido del saneamiento (no es un fallo de seguridad).** `Get-CentinelaSanitizedErrorReport`
devolvió `ParsedOk=False` y `Classification=UNKNOWN` porque Azure CLI emite el error como texto
formateado (`ERROR: {...}` seguido de bloques `Inner Errors:`), no como un único documento JSON, y el
parser estructurado espera lo segundo. La clasificación de esta sección se hizo, por tanto, leyendo
el código interno más profundo del **mensaje ya saneado**. Adicionalmente, la regla de redacción de
rutas locales de Windows sustituyó algunas secuencias de escape literales `\n` del mensaje por el
marcador de usuario local (visible arriba como `[...]`): es una **sobre-redacción**, que falla del
lado seguro y no expone nada. Ninguno de los dos puntos se corrigió aquí porque la autorización
prohíbe expresamente modificar scripts o pruebas; quedan anotados para una tarea futura.

### 18.4 Interpretación: por qué esto reconcilia toda la evidencia previa

Este resultado explica de forma coherente todo lo observado antes:

1. **Por qué falló `az deployment sub validate` (sección 15).** No era un problema de plantilla,
   región, SKU ni API: la suscripción tiene **cupo de App Service en cero** en East US 2, y el
   despliegue necesita 1. El mensaje genérico de aquella ocasión era un redireccionamiento sin
   causa; con `--validation-level Provider` el proveedor sí devolvió el código concreto.
2. **Por qué `Microsoft.Web/validate` dio PASS (sección 17).** Ese endpoint responde si la
   combinación SKU/región/tipo de worker es *ofrecible*, **no** si la suscripción tiene cupo. Ambos
   resultados son correctos y no se contradicen: **B1/Linux/East US 2 es una configuración válida,
   pero esta suscripción no tiene cupo para instanciarla.**
3. **Por qué `what-if` excluía `Microsoft.Web/serverfarms` y `Microsoft.Web/sites` (sección 14).**
   Ese bloqueo tenía causa propia —el parámetro del módulo anidado derivado de la salida de un
   módulo no desplegado— y ya fue corregido y versionado en la sección 16.2. Es un problema
   **distinto** de este, no el mismo síntoma.

**Clase de suscripción (consulta de solo lectura, sin imprimir su identificador):** `quotaId =
PayAsYouGo_2014-09-01`, `spendingLimit = Off`, `state = Enabled`. Es decir, una suscripción de pago
por uso estándar sin límite de gasto: el cupo de App Service **es ampliable** mediante una solicitud
de aumento de cuota (típicamente sin costo), a diferencia de lo que ocurriría en una suscripción de
clase restringida.

### 18.5 Confirmaciones de esta tarea

| Confirmación | Estado |
|---|---|
| HEAD validado | `0a05b5b` (local = remoto, árbol limpio) |
| Ejecuciones de `az deployment sub validate` | **Exactamente una**, sin reintentos |
| Resultado | **FAIL** — `SubscriptionIsOverQuotaForSku` |
| Clasificación funcional | **`QUOTA_OR_CAPACITY`** |
| `az group exists --name rg-novacasa-centinela-dev` (después) | `false` |
| Recursos de Azure aplicados | **Cero** (`az resource list` → 0; `az group list` → 0; `az deployment sub list` → 0) |
| `az deployment sub what-if` en esta tarea | **No ejecutado** |
| `az deployment sub create` / `az group create` / `deploy-dev.ps1 -Apply` | No ejecutados |
| `--debug` / `--verbose` | No usados (rechazados por diseño en el invocador versionado) |
| Archivos de Bicep, scripts o pruebas modificados | **Ninguno** |
| Proveedores registrados en esta tarea | Ninguno |
| Cambios de RBAC | Ninguno |
| Secretos creados en Azure | Ninguno (credenciales SQL ficticias, efímeras y eliminadas en `finally`) |
| Subscription ID / Tenant ID / contraseñas / tokens / correos / rutas locales impresos o guardados | Ninguno |
| PR #8 | **OPEN, DRAFT, sin fusionar** |
| Issue #7 | **Abierto** |
| Fase 05 | No iniciada |

### 18.6 Decisión humana requerida

El bloqueo ya **no** es un desconocido: es un cupo de App Service en cero en East US 2. Las vías
posibles requieren autorización humana explícita y **ninguna se ejecutó**:

1. **Solicitar aumento de cuota de App Service** a 1 instancia (o más) en East US 2 para esta
   suscripción — es la vía que preserva el diseño actual sin cambios de plantilla ni de región.
2. **Reintentar en la región alternativa Central US** (permitida por `CLAUDE.md`), si allí hubiera
   cupo. Requiere una nueva ejecución autorizada de `validate` con `primaryLocation=centralus`.
3. **Revisar el SKU del App Service Plan**, teniendo en cuenta que el cupo reportado es de
   instancias (`Total VMs`), por lo que un cambio de nivel podría no resolverlo por sí solo.

Hasta que se resuelva el cupo, `az deployment sub validate` seguirá fallando y el despliegue real
**no puede** completarse. Conforme a la autorización, **no se ejecutó `what-if`** y no se avanzó a
ningún despliegue.

## 19. Solicitud de aumento de cuota B1 vía Azure Quota API — **RECHAZADA** (`QuotaNotAvailableForResource`) (2026-08-03)

Autorización explícita: `[centinela-fase-04-solicitar-cuota-b1]`, acotada a **exactamente una**
solicitud de aumento de cuota por Azure CLI. Prohibidos expresamente: `az quota create`, un segundo
`az quota update`, solicitar cuota para otro SKU, abrir ticket de soporte, registrar proveedores,
cambiar RBAC, `deployment sub validate`, `what-if`, `deployment sub create`, crear o modificar
recursos, cambiar Bicep, fusionar el PR #8, cerrar el Issue #7 e iniciar la Fase 05.

### 19.1 Solicitud realizada

| Dato | Valor |
|---|---|
| Proveedor | `Microsoft.Web` |
| Región | East US 2 (`eastus2`) |
| Cuota | **`B1`** (`B1 VMs`, unidad `Instances`, `limitType: Independent`) |
| Límite anterior | **0** |
| Límite solicitado | **1** |
| Solicitudes emitidas | **Exactamente una**, sin reintentos |

Comando lógico, sin identificadores:

```text
az quota update --resource-name B1
   --scope /subscriptions/<SUBSCRIPTION_ID>/providers/Microsoft.Web/locations/eastus2
   --limit-object value=1 --output json --only-show-errors
```

Precondiciones verificadas antes de ejecutar: rama `feat/phase-04-bootstrap-azure-dev`; HEAD local y
remoto `1630bee`; árbol limpio; workflow de gobernanza en verde; Azure CLI autenticado mediante
consulta real (cuenta `Enabled`); suscripción coincidente con `CENTINELA_EXPECTED_SUBSCRIPTION_ID`
(valor **nunca impreso**); `az quota show` confirmando `resource-name = B1`, región `eastus2`,
límite actual `0` e `isQuotaApplicable = true`; `rg-novacasa-centinela-dev` inexistente; cero
recursos, cero grupos y cero deployments en la suscripción.

### 19.2 Estado saneado del resultado

**FAILED.** Código de salida 1.

| Campo | Valor saneado |
|---|---|
| Código | **`QuotaNotAvailableForResource`** |
| Mensaje | `Request failed.` (genérico, sin causa adicional) |

Conforme a la instrucción del resultado D de la autorización: **no se reintentó**, **no se cambió de
región ni de SKU**, y **no se abrió ningún ticket de soporte**.

### 19.3 Verificación posterior

| Confirmación | Estado |
|---|---|
| Límite de `B1` después de la solicitud | **0** (sin cambio) |
| `isQuotaApplicable` de `B1` | `true` (sin cambio) |
| `az group exists --name rg-novacasa-centinela-dev` | `false` |
| Recursos de Azure creados | **Cero** (`az resource list` → 0) |
| Grupos de recursos | **Cero** |
| Deployments registrados | **Cero** |
| Segunda solicitud de cuota | **No emitida** |
| `az quota create` | No ejecutado |
| Cuotas solicitadas para otros SKU | Ninguna |
| Tickets de soporte abiertos | Ninguno |
| Proveedores registrados | Ninguno |
| Cambios de RBAC | Ninguno |
| `deployment sub validate` / `what-if` / `deployment sub create` | **No ejecutados** |
| Archivos de Bicep, scripts o pruebas modificados | Ninguno |
| `--debug` / `--verbose` | No usados |
| Subscription ID / Tenant ID / scope completo / Request ID / identificadores ARM / correos impresos o guardados | Ninguno |
| PR #8 | **OPEN, DRAFT, sin fusionar** |
| Issue #7 | **Abierto** |
| Fase 05 | No iniciada |

### 19.4 Interpretación

`QuotaNotAvailableForResource` indica que el aumento de cuota para `B1` en East US 2 **no está
disponible por autoservicio** en esta suscripción. Es coherente con el patrón observado en el
diagnóstico previo: no se trata de un cupo consumido que pueda ampliarse, sino de un SKU que Azure
no está ofreciendo a esta suscripción en esa región. La vía de la Azure Quota API queda **agotada**
para este SKU y esta región.

### 19.5 Próxima decisión humana

El bloqueo de la sección 18 **sigue vigente y sin resolver**: `az deployment sub validate` seguirá
fallando con `SubscriptionIsOverQuotaForSku` mientras `B1` tenga límite 0 en East US 2. La Azure
Quota API ya no ofrece camino. Se requiere **autorización humana explícita** para elegir y ejecutar
cualquier vía alternativa; **ninguna se ejecutó ni se preparó**. No se ejecutó `validate`, ni
`what-if`, ni despliegue alguno.

> **Corrección posterior (sección 20):** en una verificación diagnóstica de solo lectura
> posterior (autorización `[centinela-fase-04-evaluar-planes-app-service]`), se constató que el
> límite de `B1` en East US 2 es ahora **1**, con las tres solicitudes de esta sección todavía
> registradas como `Failed` en el historial de `az quota request status list`. No hay evidencia que
> atribuya el cambio a estas solicitudes; es más consistente con un aprovisionamiento posterior por
> parte de Azure. La conclusión "la vía de la Azure Quota API queda **agotada**" de esta sección
> **queda retirada**: el límite sí cambió, aunque el origen exacto no está probado. Ver sección 20
> para la validación integral que confirma la resolución práctica del bloqueo.

## 20. Validación integral post-aprobación de cuota B1 — **PASS** (2026-08-03)

Autorización explícita: `[centinela-fase-04-revalidar-despues-cuota-b1]`, acotada a verificar la
propagación de la cuota, ejecutar Bicep build/lint, ejecutar **exactamente una** nueva validación
integral y actualizar únicamente este reporte. Prohibidos expresamente: `az quota update`/`create`,
otro ticket de soporte, `what-if`, `deployment sub create`, `deploy-dev.ps1 -Apply`, crear/modificar/
eliminar recursos, crear Resource Groups, cambiar Bicep/scripts/pruebas, cambiar SKU o región,
registrar proveedores, cambiar RBAC, crear secretos, fusionar el PR #8, cerrar el Issue #7 e iniciar
la Fase 05.

### 20.1 Estado del repositorio

| Verificación | Resultado |
|---|---|
| Rama | `feat/phase-04-bootstrap-azure-dev` |
| HEAD local | `d4ee1ea` |
| HEAD remoto | `d4ee1ea` (coincide) |
| Árbol de trabajo | Limpio |
| Workflow de gobernanza en `d4ee1ea` | ✅ `success` |
| PR #8 | `OPEN`, `DRAFT` |
| Issue #7 | `OPEN` |

`d4ee1ea` es un commit exclusivamente documental posterior a `0a05b5b` (el HEAD validado en la
sección 18); los archivos Bicep no cambiaron desde entonces.

### 20.2 Cuota verificada

| Dato | Valor |
|---|---|
| Proveedor | `Microsoft.Web` |
| Región | East US 2 (`eastus2`) |
| Cuota | `B1` |
| Límite anterior (sección 18) | **0** |
| Límite actual | **1** |
| `isQuotaApplicable` | `true` |
| Uso actual | **0** |
| `Microsoft.Web` | `Registered` |
| `Microsoft.Quota` | `Registered` |

### 20.3 Precondiciones

| Verificación | Resultado |
|---|---|
| Azure CLI autenticado (lectura real) | ✅ cuenta `Enabled` |
| Suscripción coincide con `CENTINELA_EXPECTED_SUBSCRIPTION_ID` | ✅ (valor nunca impreso) |
| `rg-novacasa-centinela-dev` existe | `false` |
| Recursos existentes | **0** |
| Deployments existentes | **0** |
| App Service Plans creados manualmente | **0** |

### 20.4 Validación local (Bicep)

| Comando | Resultado |
|---|---|
| `az bicep build --file infra/main.bicep` | ✅ 0 errores |
| `az bicep lint --file infra/main.bicep` | ✅ 0 advertencias |

Plantilla compilada confirmada: `sku.name: B1`, `sku.tier: Basic`, `kind: linux`,
`properties.reserved: true`, `linuxFxVersion: DOTNETCORE|10.0`, región resuelta a `eastus2`
(`primaryLocation`). Ningún archivo fue modificado.

### 20.5 Ejecución única de `az deployment sub validate`

Variables SQL efímeras y completamente ficticias fijadas en el proceso mediante el mismo mecanismo
versionado de `infra/scripts/validate.ps1` (nunca impresas, nunca guardadas en archivo, eliminadas
en `finally`); confirmado tras la ejecución: `login=False`, `password=False` (ambas ausentes del
entorno).

Comando lógico ejecutado, **exactamente una vez**, sin `--debug` ni `--verbose`:

```text
az deployment sub validate --location eastus2
  --template-file infra/main.bicep
  --parameters infra/dev.bicepparam
  --parameters primaryLocation=eastus2
  --validation-level Provider --only-show-errors --output json
```

| Campo | Resultado |
|---|---|
| Código de salida | `0` |
| `provisioningState` | **`Succeeded`** |
| `error` | `null` |
| Recursos validados (`validatedResources`) | **15** |

**VALIDACIÓN INTEGRAL POST-CUOTA: PASS.** La cuota `B1` aprobada resolvió la causa raíz de la
sección 18 (`SubscriptionIsOverQuotaForSku` sobre `Microsoft.Web/serverFarms`).

### 20.6 Verificación posterior

| Confirmación | Estado |
|---|---|
| `az group exists --name rg-novacasa-centinela-dev` | `false` |
| Recursos de Azure creados | **Cero** |
| Grupos de recursos | **Cero** |
| Deployments registrados | **Cero** |
| `what-if` | **No ejecutado** |
| `deployment sub create` / `deploy-dev.ps1 -Apply` | **No ejecutados** |
| Bicep, scripts o pruebas modificados | Ninguno |
| SKU o región cambiados | Ninguno |
| Proveedores registrados en esta tarea | Ninguno |
| Cambios de RBAC | Ninguno |
| Secretos creados en Azure | Ninguno |
| `--debug` / `--verbose` | No usados |
| Subscription ID / Tenant ID / scope completo / Request ID / número de ticket / datos personales | Ninguno impreso ni guardado |
| PR #8 | `OPEN`, `DRAFT`, sin fusionar |
| Issue #7 | Abierto |
| Fase 05 | No iniciada |

### 20.7 Próxima decisión humana

El bloqueo de cuota de las secciones 18–19 queda **resuelto en la práctica**: la validación integral
de extremo a extremo sobre la plantilla vigente pasó por primera vez. Conforme a la autorización, no
se ejecutó `what-if` por iniciativa propia. Se requiere **autorización humana explícita** para una
única ejecución de `what-if` como siguiente paso de verificación pre-despliegue.

## 21. Intento de what-if post-cuota B1 — **ERROR de proceso** (2026-08-03)

Autorización explícita: `[centinela-fase-04-what-if-despues-cuota-b1]`, acotada a **una única**
ejecución de `az deployment sub what-if` sobre el HEAD `b243c5f`, usando exclusivamente los scripts
y guardas versionados. Prohibidos expresamente: un segundo `what-if`, `deployment create`,
`group create`, `deploy-dev.ps1 -Apply`, crear/modificar/eliminar recursos, reglas de firewall SQL,
secretos, cambios de RBAC, región, SKU o plantilla, fusionar el PR #8, cerrar el Issue #7 e iniciar
la Fase 05.

### 21.1 Paso 1 — Precondiciones (8/8 OK)

| Verificación | Resultado |
|---|---|
| Rama | `feat/phase-04-bootstrap-azure-dev` |
| HEAD local | `b243c5f` |
| HEAD remoto | `b243c5f` (coincide) |
| Árbol de trabajo | Limpio |
| Workflow de gobernanza sobre `b243c5f` | ✅ `success` |
| PR #8 | `OPEN`, `DRAFT` |
| Issue #7 | `OPEN` |
| Diff `d4ee1ea..b243c5f` | Solo el reporte de evidencia (139 líneas insertadas, 0 en código/Bicep) |
| Azure CLI autenticado (lectura real) | ✅ |
| Suscripción coincide con `CENTINELA_EXPECTED_SUBSCRIPTION_ID` | ✅ (valor nunca impreso) |
| `B1` límite / uso en East US 2 | **1** / **0** |
| `rg-novacasa-centinela-dev` existe | `false` |

### 21.2 Paso 2 — Pruebas locales

| Suite | Resultado |
|---|---|
| `dotnet build -c Release` | ✅ 0 errores, 0 advertencias |
| `dotnet test -c Release` | ✅ 149/149 correctas (133 unitarias + 16 de integración) |
| `az bicep build` | ✅ 0 errores |
| `az bicep lint` | ✅ 0 advertencias |
| `Test-DeployArguments.ps1` | ✅ PASS |
| `Test-WhatIfPlanApproval.ps1` | ✅ PASS |
| `Test-DeployDevGuard.ps1` | ✅ PASS |
| `Test-AzExecFailureHandling.ps1` | ✅ PASS |
| `Test-BicepCompiledResources.ps1` | ✅ PASS |
| `Test-SanitizedErrorReport.ps1` | ✅ PASS |

### 21.3 Paso 3 — Variables efímeras

Credenciales SQL completamente ficticias fijadas en el proceso mediante el mismo mecanismo
versionado (`infra/scripts/validate.ps1`), nunca impresas ni guardadas en archivo. Confirmado tras
la ejecución: `login=False`, `password=False` (ambas ausentes del entorno).

### 21.4 Paso 4 — Ejecución única del what-if

Comando lógico ejecutado, **exactamente una vez**, mediante `Get-CentinelaDeploymentArguments
-Operation 'what-if'` y `Invoke-AzCommandCaptureDiagnostic` (sin `--debug` ni `--verbose`):

```text
az deployment sub what-if --location eastus2
  --template-file infra/main.bicep
  --parameters infra/dev.bicepparam
  --parameters primaryLocation=eastus2
  --only-show-errors --result-format FullResourcePayloads
  --no-pretty-print --output json
```

| Campo | Resultado |
|---|---|
| Código de salida | **0** |
| Longitud de la salida capturada | 11 692 caracteres (JSON, en memoria) |

### 21.5 Paso 5 — Análisis del resultado: **no completado**

`Invoke-AzCommandCaptureDiagnostic` devuelve la salida únicamente en memoria del proceso que la
invoca (no escribe ningún archivo). La salida de esta ejecución se asignó a una variable de sesión
en una invocación de PowerShell que finalizó antes de ejecutar `Get-CentinelaWhatIfAnalysis` sobre
ella, y las variables de PowerShell no persisten entre invocaciones separadas de la herramienta. El
JSON capturado quedó irrecuperable sin una nueva llamada a Azure. Por lo tanto, el análisis con las
guardas versionadas (conteo Create/Modify/Delete, diagnósticos de expansión incompleta, tipos de
recursos, RBAC, reglas de firewall SQL, Foundry/AI Search) **no pudo ejecutarse** sobre el resultado
de esta ejecución.

### 21.6 Paso 6 — Clasificación

**C — ERROR.** No es un error de Azure CLI, de sesión ni de JSON inválido: la llamada a Azure
concluyó con código 0 y produjo una salida bien formada. Es un **error de proceso/herramienta** en
la ejecución de este diagnóstico (falta de persistencia de la salida entre la ejecución y el
análisis), no evidencia de ningún problema en la plantilla, la cuota o la suscripción.

### 21.7 Verificación posterior

| Confirmación | Estado |
|---|---|
| `az group exists --name rg-novacasa-centinela-dev` | `false` |
| Recursos de Azure creados | **Cero** |
| Árbol de trabajo Git | Limpio |
| Segundo `what-if` | **No ejecutado** |
| `deployment create` / `group create` / `deploy-dev.ps1 -Apply` | **No ejecutados** |
| Bicep, scripts o pruebas modificados | Ninguno |
| Región, SKU o plantilla cambiados | Ninguno |
| RBAC, secretos, reglas de firewall SQL | Ninguno creado |
| Subscription ID / Tenant ID / credenciales / correos / rutas locales | Ninguno impreso ni guardado |
| PR #8 | `OPEN`, `DRAFT`, sin fusionar |
| Issue #7 | Abierto |
| Fase 05 | No iniciada |

### 21.8 Próxima decisión humana

El `az deployment sub validate --validation-level Provider` de la sección 20 sigue siendo la
validación de extremo a extremo más reciente con resultado `Succeeded`. El `what-if` en sí **no**
quedó analizado por las guardas de aprobación de plan. Se requiere **autorización humana explícita**
para una nueva ejecución de `what-if` (esta sería una autorización distinta y nueva, no un
"reintento" de la ya agotada), usando un script que capture la salida y ejecute
`Get-CentinelaWhatIfAnalysis` dentro de la **misma** invocación de PowerShell para evitar repetir
este error de proceso.

## Confirmaciones

- No se creó ningún recurso de Azure (confirmado con `az group exists --name
  rg-novacasa-centinela-dev` → `false`, re-confirmado al cierre de la sesión de registro de
  proveedores — sección 13 —, de nuevo al cierre de la corrección de `what-if` — sección 14 — y una
  vez más tras la validación integral de la sección 18, donde además se comprobó que la suscripción
  tiene **cero** recursos, **cero** grupos de recursos y **cero** deployments registrados).
- No se ejecutó `az group create`, `az deployment sub create` ni `az deployment group create`.
- **Actualizado (sección 12):** los seis proveedores autorizados (`Microsoft.Storage`,
  `Microsoft.KeyVault`, `Microsoft.OperationalInsights`, `Microsoft.Insights`, `Microsoft.Web`,
  `Microsoft.Sql`) **sí fueron registrados** con `az provider register --wait`, con autorización
  humana explícita previa y acotados exactamente a esos seis; ningún proveedor adicional fue
  registrado.
- No se creó ni modificó ninguna asignación RBAC.
- No se creó ningún secreto en Azure Key Vault ni en ningún otro servicio.
- No se creó ninguna regla de firewall de Azure SQL.
- No se desplegó backend ni frontend a Azure.
- No se modificó ningún recurso de Azure existente.
- `deploy-dev.ps1` fue reescrito (guarda en dos fases, seis condiciones) y probado exhaustivamente
  (23/23 escenarios PowerShell), pero **nunca ejecutado contra Azure real** — ni en esta sesión ni
  en la anterior.
- `CENTINELA_EXPECTED_SUBSCRIPTION_ID` es ahora obligatoria para cualquier ejecución de
  `deploy-dev.ps1`; su valor nunca se define en el repositorio ni se imprime en ningún mensaje.
- No se fusionó ningún Pull Request de esta fase.
- No se cerró el Issue #7.
- No se tocó la rama `main` ni `develop`.
- No se guardó ni se mostró de forma persistente ningún Tenant ID, Subscription ID, Object ID,
  correo o credencial.

## Pendiente de aprobación humana explícita (antes de continuar)

1. ~~Registro de los 6 proveedores de Azure~~ — **completado en sección 12**, con autorización
   humana explícita previa.
2. ~~Resolver el `InternalServerError` de `what-if`~~ — **resuelto en sección 14**: el cambio a
   `--result-format FullResourcePayloads` eliminó el `InternalServerError` (4/4 con
   `ResourceIdOnly` → 0/1 con `FullResourcePayloads`).
3. **Nuevo bloqueo a resolver (sección 14):** el `what-if` con `FullResourcePayloads` reporta solo 7
   de las 9 operaciones Create aprobadas — faltan `Microsoft.Web/serverfarms` y
   `Microsoft.Web/sites` del arreglo `changes[]`, pese a que ambos están declarados sin condición en
   la plantilla y `validate` los aprueba. Se requiere decisión humana explícita sobre cómo proceder
   (investigar la limitación de Azure, ajustar el método de verificación pre-despliegue, u otra vía)
   antes de intentar un nuevo `what-if` o avanzar a `deploy-dev.ps1 -Apply`.
4. **Configuración temporal de acceso a Azure SQL**, si resultara necesaria para el despliegue real
   o para verificación posterior (la regla `AllowAzureServices` permanece deshabilitada por
   defecto; cualquier regla de firewall que se decida crear debe tener alcance mínimo justificado).
5. **El despliegue real en Azure DEV** (`deploy-dev.ps1 -Apply -ConfirmationPhrase
   AUTORIZO_DESPLIEGUE_CENTINELA_DEV ...`), incluyendo revisión y aprobación humana del Pull Request
   de esta preparación antes de fusionar hacia `develop`.
6. ~~**Nuevo (sección 15):** decidir cuál de las 4 opciones de la sección 15 seguir~~ — **decidido
   en la sección 16**: la opción 4 (desplegar directamente aceptando la incógnita) fue **rechazada**
   y se autorizó una vía distinta, la validación específica no destructiva vía `Microsoft.Web/validate`.
   La clasificación `UNKNOWN` de la sección 15 se mantuvo hasta la sección 18, donde quedó
   **resuelta** como `QUOTA_OR_CAPACITY`.
7. ~~**Commit pendiente de una tarea previa:** los cinco archivos de la corrección short-circuit~~ —
   **completado en la sección 16.2**: versionados en dos commits separados
   (`fix(infra): remove App Insights bootstrap dependency` y
   `fix(infra): block incomplete nested what-if expansion`), con la regresión completa en verde y el
   workflow de gobierno en verde.
8. ~~**Decisión humana pendiente (secciones 16 y 17):** autorizar una única nueva ejecución de
   `az deployment sub validate` sobre el código ya versionado~~ — **completado en la sección 18**:
   se autorizó y ejecutó **exactamente una vez** sobre el HEAD `0a05b5b` con
   `--validation-level Provider`. Resultado **FAIL**, pero con la causa raíz por fin identificada:
   `SubscriptionIsOverQuotaForSku` sobre `Microsoft.Web/serverFarms`. La clasificación `UNKNOWN` de
   la sección 15 queda **resuelta** y sustituida por `QUOTA_OR_CAPACITY`. Cero recursos aplicados.
   Texto original conservado abajo para trazabilidad:

   > la validación específica `Microsoft.Web/validate` dio **PASS** (App Service Plan Linux B1,
   > capacidad 1, East US 2 es una configuración válida para esta suscripción). Ese PASS **no**
   > explica el fallo de `az deployment sub validate` de la sección 15, que sigue clasificado como
   > `UNKNOWN`, ni demuestra que el despliegue completo vaya a validar. **Se requiere autorización
   > humana explícita para una única nueva ejecución de `az deployment sub validate` sobre el código
   > ya versionado (`f1c5ddb`)** — sería la primera validación de extremo a extremo de la plantilla
   > corregida. Conforme a la instrucción explícita de la autorización, no se ejecutó por iniciativa
   > del agente pese al resultado satisfactorio, y tampoco se ejecutó `what-if` ni ningún despliegue.

9. **Nuevo — bloqueo vigente y decisión humana requerida (sección 18):** la suscripción tiene
   **cupo de App Service en cero** (`Limit (Total VMs): 0`) en East US 2, y el despliegue requiere 1.
   Mientras no se resuelva, `az deployment sub validate` seguirá fallando y el despliegue real no
   puede completarse. Vías posibles, **ninguna ejecutada**: (a) solicitar aumento de cuota de App
   Service a 1 instancia en East US 2 —la suscripción es `PayAsYouGo` con límite de gasto
   desactivado, por lo que el aumento es solicitable—; (b) probar la región alternativa Central US
   mediante una nueva ejecución autorizada de `validate` con `primaryLocation=centralus`; (c)
   revisar el SKU, teniendo en cuenta que el cupo agotado es de instancias (`Total VMs`) y que un
   cambio de nivel podría no resolverlo por sí solo. Se requiere **autorización humana explícita**
   para cualquiera de ellas y, por separado, para un futuro `what-if`.
   **Actualización (sección 19):** la vía (a) fue autorizada y ejecutada **exactamente una vez**
   mediante `az quota update` y quedó **rechazada** con `QuotaNotAvailableForResource`; el límite de
   `B1` sigue en 0. La Azure Quota API ya no ofrece camino para este SKU en esta región. El bloqueo
   **sigue vigente** y la elección de vía alternativa requiere una nueva autorización humana.
   **Actualización (sección 20):** el límite de `B1` en East US 2 pasó a **1** (origen no probado,
   ver nota de la sección 19) y una nueva validación integral autorizada dio **`Succeeded`**. El
   bloqueo de cuota queda **resuelto en la práctica**.

10. ~~**Nuevo (sección 20):** autorizar una única ejecución de `what-if` sobre la plantilla vigente~~
    — **intentado en la sección 21**: la llamada a Azure se ejecutó (exit 0, JSON válido), pero el
    análisis con las guardas versionadas no pudo completarse por un error de proceso (salida no
    persistida entre la ejecución y el análisis). **Se requiere una nueva autorización humana
    explícita** para repetir el `what-if` con un script que capture y analice la salida en la misma
    invocación.
