# Reporte de evidencia — Fase 04 (preparación): Bootstrap Azure DEV

- **Issue:** [#7 — Phase 04: Bootstrap Azure DEV](https://github.com/carlitos-tech/Centinela/issues/7)
- **Rama:** `feat/phase-04-bootstrap-azure-dev`
- **Base:** `develop` en `8060fa91b874cf9658479b45c6785cf6986866f6` (Fase 03 fusionada, [PR #6](https://github.com/carlitos-tech/Centinela/pull/6), Issue #5 cerrado)
- **Fecha:** 2026-08-03
- **Actualización (correcciones pre-despliegue):** 2026-08-03 — ver sección 8, 9 y 10 (reescritas) y
  sección 11 para el detalle completo de las cinco correcciones aplicadas a las guardas y al flujo
  de despliegue antes de solicitar autorización para registrar proveedores y crear la
  infraestructura DEV.
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

## Confirmaciones

- No se creó ningún recurso de Azure (confirmado con `az group exists --name
  rg-novacasa-centinela-dev` → `false`).
- No se ejecutó `az group create`, `az deployment sub create` ni `az deployment group create`.
- No se registró ningún proveedor de Azure (`az provider register` nunca se ejecutó).
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

1. **Registro de los 6 proveedores de Azure pendientes** (`Microsoft.Storage`, `Microsoft.KeyVault`,
   `Microsoft.OperationalInsights`, `microsoft.insights`, `Microsoft.Web`, `Microsoft.Sql`) —
   operación de escritura sobre la suscripción, no ejecutada en esta fase.
2. **Configuración temporal de acceso a Azure SQL**, si resultara necesaria para el despliegue real
   o para verificación posterior (la regla `AllowAzureServices` permanece deshabilitada por
   defecto; cualquier regla de firewall que se decida crear debe tener alcance mínimo justificado).
3. **El despliegue real en Azure DEV** (`deploy-dev.ps1 -Apply -ConfirmationPhrase
   AUTORIZO_DESPLIEGUE_CENTINELA_DEV ...`), incluyendo revisión y aprobación humana del Pull Request
   de esta preparación antes de fusionar hacia `develop`.
