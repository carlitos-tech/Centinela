<#
.SYNOPSIS
Despliegue REAL de la infraestructura DEV de Centinela. NO SE HA EJECUTADO EN NINGUNA SESION.

.DESCRIPTION
Este script existe unicamente como preparacion de la Fase 04 (Bootstrap Azure DEV) y esta
protegido con multiples guardas independientes en infra/scripts/lib/DeployGuard.ps1:

  1. Requiere el switch -Apply. Sin el, se bloquea antes de tocar Azure.
  2. Requiere -ConfirmationPhrase exactamente igual a 'AUTORIZO_DESPLIEGUE_CENTINELA_DEV'.
  3. Requiere que la suscripcion activa sea exactamente 'SuscripcionClaudeCode'.
  4. Requiere que -Environment sea 'dev' (unico valor permitido) y -Location sea 'eastus2' o
     'centralus' (unicas regiones documentadas en CLAUDE.md, seccion 5).
  5. Revalida bicep build/lint + az deployment sub validate + az deployment sub what-if
     inmediatamente antes de crear: si cualquiera de esos pasos falla (codigo de salida distinto
     de 0, verificado por Invoke-AzCommand), el script aborta sin llegar a
     'az deployment sub create'.

Este script NUNCA usa `--confirm-with-what-if`: el what-if y el create son pasos explicitamente
separados, para que el what-if de este mismo script (y el de infra/scripts/what-if.ps1) siga
siendo una operacion de solo lectura independiente de cualquier creacion real.

'az deployment sub create' aparece exactamente una vez en todo este repositorio: en el
scriptblock $runDeploymentCreate mas abajo, invocado solo a traves de
Invoke-CentinelaDevDeployment (infra/scripts/lib/DeployOrchestrator.ps1) despues de que las cinco
guardas anteriores se cumplan. infra/scripts/tests/Test-DeployDevGuard.ps1 prueba exhaustivamente
que ese scriptblock nunca se invoca si cualquiera de las guardas falla.

.PARAMETER Apply
Requerido para avanzar mas alla de las guardas. Sin este switch, el script se detiene.

.PARAMETER ConfirmationPhrase
Debe ser exactamente 'AUTORIZO_DESPLIEGUE_CENTINELA_DEV'.

.PARAMETER Environment
Entorno objetivo. Unico valor permitido: 'dev'.

.PARAMETER Location
Region objetivo. Valores permitidos: 'eastus2' (principal), 'centralus' (contingencia).

.NOTES
Requiere aprobacion humana explicita adicional antes de cualquier ejecucion real (ver CLAUDE.md,
secciones 5 y 11, y la autorizacion de Fase 04 que dio origen a este archivo).
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
. (Join-Path $PSScriptRoot 'lib/DeployOrchestrator.ps1')

$infraDir = Resolve-Path (Join-Path $PSScriptRoot '..')
$mainTemplate = Join-Path $infraDir 'main.bicep'
$paramsFile = Join-Path $infraDir 'dev.bicepparam'

$getActiveSubscriptionName = {
    (az account show --query name -o tsv).Trim()
}

$runPreDeploymentChecks = {
    Invoke-AzCommand -StepName 'az bicep version' -Arguments @('bicep', 'version')
    Invoke-AzCommand -StepName 'az bicep build (main.bicep)' -Arguments @('bicep', 'build', '--file', $mainTemplate)
    Invoke-AzCommand -StepName 'az bicep lint (main.bicep)' -Arguments @('bicep', 'lint', '--file', $mainTemplate)
    Invoke-AzCommand -StepName 'az deployment sub validate (revalidacion previa al apply)' -Arguments @(
        'deployment', 'sub', 'validate',
        '--location', $Location,
        '--template-file', $mainTemplate,
        '--parameters', $paramsFile,
        '--only-show-errors'
    )
    Invoke-AzCommand -StepName 'az deployment sub what-if (revalidacion previa al apply)' -Arguments @(
        'deployment', 'sub', 'what-if',
        '--location', $Location,
        '--template-file', $mainTemplate,
        '--parameters', $paramsFile,
        '--only-show-errors'
    )
}

# Unico punto del repositorio donde se invoca 'az deployment sub create'. No se ejecuta con
# --confirm-with-what-if: what-if (arriba) y create (aqui) son pasos separados y explicitos.
$runDeploymentCreate = {
    Invoke-AzCommand -StepName 'az deployment sub create (DESPLIEGUE REAL)' -Arguments @(
        'deployment', 'sub', 'create',
        '--name', "centinela-dev-$(Get-Date -Format 'yyyyMMddHHmmss')",
        '--location', $Location,
        '--template-file', $mainTemplate,
        '--parameters', $paramsFile,
        '--only-show-errors'
    )
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

            Invoke-CentinelaDevDeployment -Apply:$Apply -ConfirmationPhrase $ConfirmationPhrase `
                -Environment $Environment -Location $Location `
                -GetActiveSubscriptionName $getActiveSubscriptionName `
                -RunPreDeploymentChecks $runPreDeploymentChecks `
                -RunDeploymentCreate $runDeploymentCreate
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
