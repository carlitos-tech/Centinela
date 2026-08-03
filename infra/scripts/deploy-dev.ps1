<#
.SYNOPSIS
Despliegue REAL de la infraestructura DEV de Centinela. NO SE HA EJECUTADO EN NINGUNA SESION.

.DESCRIPTION
Este script existe unicamente como preparacion de la Fase 04 (Bootstrap Azure DEV) y esta
protegido con multiples guardas independientes, en dos fases estrictamente ordenadas
(infra/scripts/lib/DeployOrchestrator.ps1, infra/scripts/lib/DeployGuard.ps1,
infra/scripts/lib/DeployWhatIfAnalysis.ps1):

  FASE 1 — Autorizacion (sin credenciales, sin `az deployment` alguno):
    1. Requiere el switch -Apply. Sin el, se bloquea antes de tocar Azure.
    2. Requiere -ConfirmationPhrase exactamente igual a 'AUTORIZO_DESPLIEGUE_CENTINELA_DEV'.
    3. Requiere que -Environment sea 'dev' (unico valor permitido).
    4. Requiere que -Location sea 'eastus2' o 'centralus' (unicas regiones documentadas en
       CLAUDE.md, seccion 5).
    5. Requiere que la suscripcion activa sea exactamente 'SuscripcionClaudeCode'.
    6. Requiere que el Subscription ID activo coincida con la variable de entorno
       CENTINELA_EXPECTED_SUBSCRIPTION_ID (obligatoria, sin valor predeterminado, nunca impresa).

  Solo si las seis condiciones anteriores se cumplen, este script solicita interactivamente las
  credenciales temporales de Azure SQL (nunca antes).

  FASE 2 — Revalidacion y creacion (con credenciales SQL ya exportadas temporalmente):
    7. Revalida bicep build/lint + `az deployment sub validate`.
    8. Ejecuta `az deployment sub what-if` (salida capturada como JSON, nunca impresa cruda).
    9. Analiza el plan de what-if (Correccion 3): exige exactamente los 9 recursos aprobados, todos
       Create, ninguno RBAC/regla de firewall SQL/Foundry/AI Search, ninguno fuera de
       rg-novacasa-centinela-dev. Un codigo de salida 0 en what-if NO es suficiente por si solo.
       Muestra siempre un resumen sanitizado del resultado (aprobado o bloqueado).
    10. Solo si el plan es aprobado, ejecuta `az deployment sub create`.

Este script NUNCA usa `--confirm-with-what-if`: el what-if y el create son pasos explicitamente
separados. `az deployment sub create` aparece exactamente una vez en todo este repositorio: en el
scriptblock $runDeploymentCreate mas abajo, invocado solo a traves de
Invoke-CentinelaDevPreDeploymentAndCreate y solo si el plan de what-if fue aprobado.

Ninguna salida de este script imprime Tenant ID, Subscription ID, Object ID, credenciales ni
cadenas de conexion; ninguna salida cruda de `az` se guarda en disco.

.PARAMETER Apply
Requerido para avanzar mas alla de las guardas. Sin este switch, el script se detiene.

.PARAMETER ConfirmationPhrase
Debe ser exactamente 'AUTORIZO_DESPLIEGUE_CENTINELA_DEV'.

.PARAMETER Environment
Entorno objetivo. Unico valor permitido: 'dev'.

.PARAMETER Location
Region objetivo (region del deployment Y region real de los recursos, ver Correccion 2). Valores
permitidos: 'eastus2' (principal), 'centralus' (contingencia).

.NOTES
Requiere aprobacion humana explicita adicional antes de cualquier ejecucion real (ver CLAUDE.md,
secciones 5 y 11, y las autorizaciones de Fase 04 que dieron origen a este archivo). Requiere
ademas que CENTINELA_EXPECTED_SUBSCRIPTION_ID este definida en el entorno local antes de invocar
este script; el script nunca la define ni le asigna un valor predeterminado.
#>

[CmdletBinding()]
param(
    [switch]$Apply,

    [string]$ConfirmationPhrase,

    [ValidateSet('dev')]
    [string]$Environment = 'dev',

    [ValidateSet('eastus2', 'centralus')]
    [string]$Location = 'eastus2'
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/AzExec.ps1')
. (Join-Path $PSScriptRoot 'lib/DeployArguments.ps1')
. (Join-Path $PSScriptRoot 'lib/DeployOrchestrator.ps1')
. (Join-Path $PSScriptRoot 'lib/DeploySanitizedOutput.ps1')

$infraDir = Resolve-Path (Join-Path $PSScriptRoot '..')
$mainTemplate = Join-Path $infraDir 'main.bicep'
$paramsFile = Join-Path $infraDir 'dev.bicepparam'

# CENTINELA_EXPECTED_SUBSCRIPTION_ID se lee tal cual desde el entorno local: nunca tiene un valor
# predeterminado aqui ni en ningun otro archivo versionado, y su valor nunca se imprime (ni aqui,
# ni en DeployGuard.ps1, ni en ningun mensaje de excepcion).
$expectedSubscriptionId = $env:CENTINELA_EXPECTED_SUBSCRIPTION_ID

# Consulta independiente de la suscripcion activa: dos llamadas separadas (nombre e ID), ninguna
# de las cuales deriva el valor ESPERADO (ese viene unicamente del entorno, arriba).
$getActiveSubscriptionName = {
    (az account show --query name -o tsv).Trim()
}
$getActiveSubscriptionId = {
    (az account show --query id -o tsv).Trim()
}

# ---------------------------------------------------------------------------------------------
# FASE 1: autorizacion. Ninguna credencial SQL se solicita todavia.
# ---------------------------------------------------------------------------------------------
try {
    Invoke-CentinelaDeploymentAuthorizationGuard -Apply:$Apply -ConfirmationPhrase $ConfirmationPhrase `
        -Environment $Environment -Location $Location `
        -GetActiveSubscriptionName $getActiveSubscriptionName `
        -GetActiveSubscriptionId $getActiveSubscriptionId `
        -ExpectedSubscriptionId $expectedSubscriptionId
}
catch {
    Write-Error "Despliegue de Centinela DEV bloqueado: $($_.Exception.Message)"
    exit 1
}

# ---------------------------------------------------------------------------------------------
# FASE 2: las seis guardas de autorizacion pasaron. Recien ahora se solicitan credenciales SQL.
# ---------------------------------------------------------------------------------------------
$runBicepValidate = {
    Invoke-AzCommand -StepName 'az bicep version' -Arguments @('bicep', 'version')
    Invoke-AzCommand -StepName 'az bicep build (main.bicep)' -Arguments @('bicep', 'build', '--file', $mainTemplate)
    Invoke-AzCommand -StepName 'az bicep lint (main.bicep)' -Arguments @('bicep', 'lint', '--file', $mainTemplate)

    $validateArgs = Get-CentinelaDeploymentArguments -Operation 'validate' -Location $Location `
        -TemplateFile $mainTemplate -ParametersFile $paramsFile
    $validateJson = Invoke-AzCommandCaptureJson -StepName 'az deployment sub validate (revalidacion previa al apply)' -Arguments $validateArgs
    (Format-CentinelaValidateSummary -ValidateJson $validateJson) | ForEach-Object { Write-Host $_ }
}

$runWhatIf = {
    $whatIfArgs = Get-CentinelaDeploymentArguments -Operation 'what-if' -Location $Location `
        -TemplateFile $mainTemplate -ParametersFile $paramsFile
    Invoke-AzCommandCaptureJson -StepName 'az deployment sub what-if (revalidacion previa al apply)' -Arguments $whatIfArgs
}

$reportWhatIfAnalysis = {
    param($Analysis)
    (Format-CentinelaWhatIfSummary -Analysis $Analysis) | ForEach-Object { Write-Host $_ }
}

# Unico punto del repositorio donde se invoca 'az deployment sub create'. Solo se alcanza si el
# analisis del what-if (Correccion 3) aprobo el plan.
$runDeploymentCreate = {
    $deploymentName = "centinela-dev-$(Get-Date -Format 'yyyyMMddHHmmss')"
    $createArgs = Get-CentinelaDeploymentArguments -Operation 'create' -Location $Location `
        -TemplateFile $mainTemplate -ParametersFile $paramsFile -DeploymentName $deploymentName
    $createJson = Invoke-AzCommandCaptureJson -StepName 'az deployment sub create (DESPLIEGUE REAL)' -Arguments $createArgs
    (Format-CentinelaCreateSummary -CreateJson $createJson) | ForEach-Object { Write-Host $_ }
}

try {
    $sqlAdminLogin = Read-Host 'Usuario administrador de Azure SQL (no se guarda)'
    $sqlPasswordSecure = Read-Host -AsSecureString 'Contraseña de administrador de Azure SQL (solo en memoria, no se guarda)'

    $sqlPasswordBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlPasswordSecure)

    try {
        $sqlPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($sqlPasswordBstr)

        try {
            $env:CENTINELA_SQL_ADMIN_LOGIN = $sqlAdminLogin
            $env:CENTINELA_SQL_ADMIN_PASSWORD = $sqlPasswordPlain

            Invoke-CentinelaDevPreDeploymentAndCreate -RunBicepValidate $runBicepValidate `
                -RunWhatIf $runWhatIf -ReportWhatIfAnalysis $reportWhatIfAnalysis `
                -RunDeploymentCreate $runDeploymentCreate | Out-Null
        }
        finally {
            $sqlPasswordPlain = $null
            $sqlAdminLogin = $null
            Remove-Item Env:\CENTINELA_SQL_ADMIN_LOGIN -ErrorAction SilentlyContinue
            Remove-Item Env:\CENTINELA_SQL_ADMIN_PASSWORD -ErrorAction SilentlyContinue
        }
    }
    finally {
        if ($sqlPasswordBstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($sqlPasswordBstr)
        }
    }

    Write-Host 'Despliegue completo.'
}
catch {
    Write-Error "Despliegue de Centinela DEV bloqueado o fallido: $($_.Exception.Message)"
    exit 1
}
