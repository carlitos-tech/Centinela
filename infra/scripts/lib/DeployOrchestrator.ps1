<#
.SYNOPSIS
Orquestador testeable, en dos fases, del despliegue real de Centinela DEV.

.DESCRIPTION
El flujo se divide deliberadamente en dos funciones (Correccion 5, Fase 04: "orden de las
guardas") para que ninguna credencial de Azure SQL se solicite antes de superar las seis
condiciones de autorizacion:

  FASE 1 — Invoke-CentinelaDeploymentAuthorizationGuard
    Evalua, en orden, las seis condiciones de Assert-DeploymentAuthorized (Apply, frase de
    confirmacion, entorno, region, nombre de suscripcion, Subscription ID esperado). No solicita
    ni recibe ninguna credencial SQL. Si cualquier condicion falla, lanza una excepcion y
    deploy-dev.ps1 nunca llega a pedir credenciales.

  FASE 2 — Invoke-CentinelaDevPreDeploymentAndCreate
    Solo se invoca despues de que la Fase 1 haya tenido exito Y deploy-dev.ps1 haya solicitado y
    exportado temporalmente las credenciales SQL necesarias para validate/what-if/create. Ejecuta,
    en orden estricto: revalidacion Bicep (build/lint) + `az deployment sub validate` ->
    `az deployment sub what-if` (JSON capturado) -> analisis obligatorio del plan (Correccion 3,
    Get-CentinelaWhatIfAnalysis) -> reporte sanitizado del resultado (aprobado o bloqueado) ->
    solo si el plan es aprobado, `az deployment sub create`.

Ambas funciones reciben los efectos externos como scriptblocks inyectados, para que
infra/scripts/tests/Test-DeployDevGuard.ps1 y infra/scripts/tests/Test-WhatIfPlanApproval.ps1
ejerciten la secuencia completa con dobles de prueba, sin invocar Azure CLI real.

deploy-dev.ps1 es el unico lugar del repositorio que invoca estas funciones con scriptblocks
reales (Azure CLI real). Ningun otro archivo debe wire-up $RunDeploymentCreate a un comando real.
#>

. (Join-Path $PSScriptRoot 'DeployGuard.ps1')
. (Join-Path $PSScriptRoot 'DeployWhatIfAnalysis.ps1')

function Invoke-CentinelaDeploymentAuthorizationGuard {
    [CmdletBinding()]
    param(
        [switch]$Apply,

        [string]$ConfirmationPhrase,

        [string]$Environment = 'dev',

        [string]$Location = 'eastus2',

        [Parameter(Mandatory)]
        [scriptblock]$GetActiveSubscriptionName,

        [Parameter(Mandatory)]
        [scriptblock]$GetActiveSubscriptionId,

        [string]$ExpectedSubscriptionId
    )

    $activeSubscriptionName = & $GetActiveSubscriptionName
    $activeSubscriptionId = & $GetActiveSubscriptionId

    Assert-DeploymentAuthorized -Apply:$Apply -ConfirmationPhrase $ConfirmationPhrase `
        -Environment $Environment -Location $Location `
        -ActiveSubscriptionName $activeSubscriptionName `
        -ActiveSubscriptionId $activeSubscriptionId `
        -ExpectedSubscriptionId $ExpectedSubscriptionId
}

function Invoke-CentinelaDevPreDeploymentAndCreate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$RunBicepValidate,

        [Parameter(Mandatory)]
        [scriptblock]$RunWhatIf,

        [Parameter(Mandatory)]
        [scriptblock]$ReportWhatIfAnalysis,

        [Parameter(Mandatory)]
        [scriptblock]$RunDeploymentCreate,

        [string]$ExpectedResourceGroupName = $script:CentinelaExpectedResourceGroupName
    )

    # Revalidacion Bicep + `az deployment sub validate`. Si falla (codigo de salida distinto de
    # 0), lanza una excepcion y ni el what-if ni el create se ejecutan.
    & $RunBicepValidate

    # `az deployment sub what-if` capturado como JSON (nunca impreso crudo). Un fallo de Azure CLI
    # aqui tambien lanza una excepcion antes de llegar al analisis o a create.
    $whatIfJson = & $RunWhatIf

    # Analisis obligatorio del plan (Correccion 3): un codigo de salida 0 en what-if NO es
    # suficiente por si solo.
    $analysis = Get-CentinelaWhatIfAnalysis -WhatIfJson $whatIfJson -ExpectedResourceGroupName $ExpectedResourceGroupName

    # El resumen sanitizado se muestra tanto si el plan es aprobado como si es bloqueado.
    & $ReportWhatIfAnalysis $analysis

    if (-not $analysis.Approved) {
        throw "Bloqueado: el plan de what-if no coincide con el plan aprobado ($($analysis.BlockReasons -join '; ')). Se requiere una nueva aprobacion humana antes de continuar."
    }

    & $RunDeploymentCreate

    return $analysis
}
