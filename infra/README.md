# Infraestructura DEV — Centinela (Fase 03, endurecida y preparada para despliegue en Fase 04)

Plantillas Bicep de la infraestructura declarativa de DEV. **Ningún recurso de esta carpeta ha
sido desplegado.** Se valida localmente (`bicep build`/`lint`, `az deployment sub
validate`/`what-if`) sin aplicar ningún cambio real. La Fase 04 agregó, además, un script de
despliegue real protegido (`scripts/deploy-dev.ps1`), cuyas guardas y flujo de despliegue se
corrigieron en una segunda iteración: seis condiciones de autorización en dos fases (ninguna
credencial de Azure SQL se solicita antes de superarlas), la región de `-Location` ahora controla
también la región real de los recursos (`primaryLocation`), y el plan de `what-if` se analiza
recurso por recurso antes de permitir `create` (un código de salida 0 en `what-if` ya no es
suficiente por sí solo). El script sigue **nunca ejecutado**; el despliegue real efectivo requiere
aprobación humana explícita adicional (ver `CLAUDE.md`, secciones 5 y 11, y
[`docs/evidence/phase-04-bootstrap-azure-dev-predeployment-report.md`](../docs/evidence/phase-04-bootstrap-azure-dev-predeployment-report.md)).

Requiere además que la variable de entorno `CENTINELA_EXPECTED_SUBSCRIPTION_ID` esté definida en el
entorno local antes de invocar `deploy-dev.ps1` — no tiene valor predeterminado en ningún archivo
versionado y su valor nunca se imprime.

## Estructura

```text
infra/
├── main.bicep                  # Orquestador, targetScope = 'subscription'
├── bicepconfig.json             # Configuración del linter de Bicep
├── dev.bicepparam                # Parámetros de DEV (sin secretos)
├── modules/
│   ├── resource-group.bicep      # Resource Group de DEV
│   ├── storage.bicep             # Storage Account (StorageV2, Standard_LRS)
│   ├── key-vault.bicep           # Key Vault Standard con RBAC
│   ├── monitoring.bicep          # Log Analytics + Application Insights
│   ├── app-service.bicep         # App Service Plan (Linux, B1) + Web App (.NET)
│   └── sql.bicep                 # Azure SQL logical server + database (Basic)
├── scripts/
│   ├── validate.ps1 / validate.sh   # bicep build/lint + az deployment sub validate
│   ├── what-if.ps1 / what-if.sh     # az deployment sub what-if
│   ├── deploy-dev.ps1                    # Despliegue real, protegido con guardas — nunca ejecutado
│   ├── lib/DeployGuard.ps1               # Lógica de autorización pura (6 condiciones, incl. CENTINELA_EXPECTED_SUBSCRIPTION_ID)
│   ├── lib/DeployArguments.ps1           # Argumentos de az deployment sub validate|what-if|create (region real de los recursos)
│   ├── lib/DeployWhatIfAnalysis.ps1      # Análisis obligatorio del plan de what-if (bloquea si no son exactamente los 9 recursos aprobados)
│   ├── lib/DeploySanitizedOutput.ps1     # Formato de salida sanitizado (sin Tenant/Subscription/Object ID)
│   ├── lib/AzExec.ps1                    # Ejecución de `az` con captura en memoria (sin disco, sin `2>&1`)
│   ├── lib/DeployOrchestrator.ps1        # Orquestador testeable en dos fases (autorización → credenciales → validate/what-if/create)
│   ├── tests/Test-DeployDevGuard.ps1     # Pruebas de guarda (8/8 PASS, sin Azure CLI real)
│   ├── tests/Test-DeployArguments.ps1    # Pruebas de región real de los recursos (4/4 PASS)
│   └── tests/Test-WhatIfPlanApproval.ps1 # Pruebas de análisis del what-if (11/11 PASS)
├── cost/
│   └── dev-cost-estimate.md      # Estimación de costos mensual, con fuentes citadas
└── README.md
```

## Recursos modelados

| Recurso | Propósito | Notas de costo |
|---|---|---|
| Resource Group | Contenedor de todos los recursos de DEV | Sin costo |
| Storage Account (StorageV2, Standard_LRS) | Almacenamiento general; `allowBlobPublicAccess=false` (endurecido en Fase 04); hosting de sitio estático se configura en plano de datos, fuera de este Bicep | Bajo costo |
| Key Vault (Standard, RBAC) | Gestión de secretos; sin ninguna asignación de rol RBAC (se sigue difiriendo) | Bajo costo |
| Log Analytics + Application Insights | Observabilidad | Nivel gratuito hasta 5 GB/mes |
| App Service Plan (Linux, B1) + Web App | Hosting de la API .NET | Ver `cost/dev-cost-estimate.md` |
| Azure SQL Server + Database (Basic) | Base de datos futura; regla de firewall `AllowAzureServices` convertida en opt-in (`enableSqlAllowAzureServicesRule`, `false` por defecto en Fase 04) — no se crea a menos que se habilite explícitamente | Ver `cost/dev-cost-estimate.md` |

Storage Account, Key Vault, Web App y el servidor lógico de Azure SQL usan un sufijo
determinista globalmente único (`uniqueString(subscription().id, resourceGroupName)`, agregado en
Fase 04) para evitar colisiones de nombre en Azure; Resource Group, App Service Plan, Log
Analytics y Application Insights conservan nombres legibles.

**Microsoft Foundry** y **Azure AI Search** están documentados como componentes opcionales
deshabilitados (`enableFoundry = false`, `enableAiSearch = false` en `dev.bicepparam`): no se
declara ningún recurso activo para ellos en esta fase.

## Parámetros de `dev.bicepparam`

`environment=dev`, `primaryLocation=eastus2`, `fallbackLocation=centralus`,
`projectName=centinela`, `companyName=novacasa`, `monthlyBudgetUsd=50`, `retentionDays=30`,
`enableFoundry=false`, `enableAiSearch=false`, `enableSqlAllowAzureServicesRule=false`.

`sqlAdministratorLogin` y `sqlAdministratorPassword` se leen en `dev.bicepparam` mediante
`readEnvironmentVariable('CENTINELA_SQL_ADMIN_LOGIN'/'CENTINELA_SQL_ADMIN_PASSWORD')` — un archivo
`.bicepparam` con `using` exige una asignación para todo parámetro sin valor por defecto (Bicep
BCP258), pero esta función no incrusta ningún literal en el archivo versionado. Los scripts en
`scripts/` solicitan las credenciales de forma interactiva, las exportan solo en variables de
entorno del proceso (nunca como argumento `--parameters` en la línea de comandos ni en disco) y las
limpian al finalizar (`trap`/`finally`). La contraseña usa `@secure()` en todos los módulos que la
reciben y nunca se registra, se muestra ni se usa para crear el recurso real en esta fase.

## Cómo validar localmente

Requiere Azure CLI con la extensión Bicep instalada (`az bicep install`) y sesión autenticada con,
al menos, permisos de lectura sobre la suscripción.

```powershell
# PowerShell
.\scripts\validate.ps1
.\scripts\what-if.ps1
```

```bash
# Bash
./scripts/validate.sh
./scripts/what-if.sh
```

Ninguno de los dos scripts crea, modifica ni elimina recursos. Si `validate`/`what-if` fallan por
permisos insuficientes de la sesión o por proveedores de Azure no registrados en la suscripción,
el resultado se documenta como una limitación conocida (ver
`docs/evidence/phase-03-azure-cli-gateway-iac-report.md`) — no se eleva privilegios, no se
registran proveedores y no se cambia RBAC para "solucionar" el fallo.

## Región

Principal: **East US 2**. Alterna: **Central US** (documentada en `fallbackLocation`, no usada por
defecto).
