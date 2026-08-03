# Reporte de evidencia — Fase 04 (preparación): Bootstrap Azure DEV

- **Issue:** [#7 — Phase 04: Bootstrap Azure DEV](https://github.com/carlitos-tech/Centinela/issues/7)
- **Rama:** `feat/phase-04-bootstrap-azure-dev`
- **Base:** `develop` en `8060fa91b874cf9658479b45c6785cf6986866f6` (Fase 03 fusionada, [PR #6](https://github.com/carlitos-tech/Centinela/pull/6), Issue #5 cerrado)
- **Fecha:** 2026-08-03
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

## 8. Script de despliegue protegido (`deploy-dev.ps1`) — creado, no ejecutado

`infra/scripts/deploy-dev.ps1` se agregó con cinco guardas independientes antes de poder alcanzar
`az deployment sub create` (único lugar del repositorio donde aparece ese comando):

1. Requiere el switch `-Apply`.
2. Requiere `-ConfirmationPhrase` exactamente igual a `AUTORIZO_DESPLIEGUE_CENTINELA_DEV`.
3. Requiere que la suscripción activa sea exactamente `SuscripcionClaudeCode`.
4. Requiere `-Environment dev` (único valor permitido) y `-Location` en `eastus2`/`centralus`.
5. Revalida `bicep build`/`lint` + `az deployment sub validate` + `az deployment sub what-if`
   inmediatamente antes de crear; cualquier fallo (código de salida distinto de 0, vía
   `Invoke-AzCommand`) aborta antes del `create`.

El script nunca usa `--confirm-with-what-if`: `what-if` y `create` son pasos explícitamente
separados. La lógica de guarda se extrajo a funciones puras/inyectables
(`infra/scripts/lib/DeployGuard.ps1`, `infra/scripts/lib/DeployOrchestrator.ps1`) para permitir
pruebas exhaustivas sin tocar Azure CLI real.

**Evidencia de las pruebas de guarda** (`infra/scripts/tests/Test-DeployDevGuard.ps1`), ejecutadas
en esta sesión — 6/6 escenarios se comportaron como se esperaba:

```text
[PASS] Falta -Apply: Blocked=True CreateInvocations=0
[PASS] Frase incorrecta: Blocked=True CreateInvocations=0
[PASS] Suscripcion incorrecta: Blocked=True CreateInvocations=0
[PASS] Entorno no permitido: Blocked=True CreateInvocations=0
[PASS] Fallo de az en revalidacion: Blocked=True CreateInvocations=0
[PASS] CONTROL: todo correcto: Blocked=False CreateInvocations=1
EXIT CODE: 0
```

Los 5 escenarios bloqueados nunca invocan el scriptblock de `create` (contador en 0); el escenario
de control confirma que la prueba no pasa trivialmente por un error del propio arnés. **El script
`deploy-dev.ps1` no fue ejecutado contra Azure real en ningún momento de esta sesión.**

## 9. Validación de código y de Bicep

| Comando | Resultado |
|---|---|
| `dotnet build Centinela.slnx --configuration Release` | Éxito — 0 advertencias, 0 errores |
| `dotnet test Centinela.slnx --configuration Release` | **149/149 OK** (133 unit + 16 integración) — sin cambios frente a la Fase 03, consistente con que esta etapa no modificó código C# |
| `az bicep build --file infra/main.bicep` | Éxito — 0 advertencias, 0 errores, tras los cambios de nombres/endurecimiento |
| `az bicep lint --file infra/main.bicep` | Éxito — 0 hallazgos |

## 10. `az deployment sub validate` / `what-if` (East US 2)

Ambos comandos son de solo lectura/previsualización. Se usaron credenciales de descarte
(`sqladmindiscard` / contraseña generada aleatoriamente en memoria, nunca reutilizable, exportadas
solo como variables de entorno del proceso y eliminadas inmediatamente después). La salida cruda
incluyó el Subscription ID real como parte de los Resource IDs devueltos por Azure; esa salida fue
capturada en una variable y redactada (patrón GUID → `<GUID-REDACTADO>`) **antes** de mostrarse en
cualquier lugar — nunca se imprimió ni se guardó el valor real.

| Comando | Resultado |
|---|---|
| `az deployment sub validate --location eastus2 ...` | `provisioningState: "Succeeded"` (exit code 0) |
| `az deployment sub what-if --location eastus2 ... --result-format ResourceIdOnly` | **9 cambios, los 9 `Create`, 0 `Delete`, 0 `Modify`, 0 aplicados** |

Recursos previstos en el `what-if` (1 resource group + 8 recursos, nombres reales sanitizados de
identificadores de suscripción):

- `resourceGroups/rg-novacasa-centinela-dev`
- `Microsoft.Insights/components/appi-novacasa-centinela-dev`
- `Microsoft.KeyVault/vaults/kv-novacas-<sufijo>`
- `Microsoft.OperationalInsights/workspaces/log-novacasa-centinela-dev`
- `Microsoft.Sql/servers/sql-novacasa-centinela-dev-<sufijo>`
- `Microsoft.Sql/servers/.../databases/sqldb-novacasa-centinela-dev`
- `Microsoft.Storage/storageAccounts/stnovacasac<sufijo>`
- `Microsoft.Web/serverfarms/plan-novacasa-centinela-dev`
- `Microsoft.Web/sites/app-novacasa-centinela-dev-<sufijo>-api`

**Ninguna asignación RBAC, ningún recurso de Microsoft Foundry/Azure AI Search, y ninguna regla de
firewall de Azure SQL** en la previsualización — consistente con `enableFoundry=false`,
`enableAiSearch=false` y `enableSqlAllowAzureServicesRule=false`. Sin `Delete` ni `Modify`
inesperado. **Cero cambios aplicados**: `what-if` es exclusivamente una previsualización.

## Confirmaciones

- No se creó ningún recurso de Azure.
- No se ejecutó `az group create`, `az deployment sub create` ni `az deployment group create`.
- No se registró ningún proveedor de Azure (`az provider register` nunca se ejecutó).
- No se creó ni modificó ninguna asignación RBAC.
- No se creó ningún secreto en Azure Key Vault ni en ningún otro servicio.
- No se creó ninguna regla de firewall de Azure SQL.
- No se desplegó backend ni frontend a Azure.
- No se modificó ningún recurso de Azure existente.
- `deploy-dev.ps1` fue creado y probado en su lógica de guarda, pero nunca ejecutado contra Azure.
- No se fusionó ningún Pull Request de esta fase.
- No se cerró el Issue #7.
- No se tocó la rama `main`.
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
