<#
.SYNOPSIS
Orquestador testeable del despliegue real de Centinela DEV.

.DESCRIPTION
Invoke-CentinelaDevDeployment separa la secuencia obligatoria (autorizacion -> revalidacion ->
creacion) de los efectos externos reales, que se reciben como scriptblocks inyectados
($GetActiveSubscriptionName, $RunPreDeploymentChecks, $RunDeploymentCreate). Esto permite que
infra/scripts/tests/Test-DeployDevGuard.ps1 ejercite la secuencia completa con dobles de prueba,
sin invocar Azure CLI real, y confirme que $RunDeploymentCreate nunca se invoca salvo que las
cinco condiciones de Assert-DeploymentAuthorized se cumplan Y $RunPreDeploymentChecks tenga exito.

deploy-dev.ps1 es el unico lugar del repositorio que invoca esta funcion con scriptblocks reales
(Azure CLI real). Ningun otro archivo debe wire-up $RunDeploymentCreate a un comando real.
#>

. (Join-Path $PSScriptRoot 'DeployGuard.ps1')

function Invoke-CentinelaDevDeployment {
    [CmdletBinding()]
    param(
        [switch]$Apply,

        [string]$ConfirmationPhrase,

        [string]$Environment = 'dev',

        [string]$Location = 'eastus2',

        [Parameter(Mandatory)]
        [scriptblock]$GetActiveSubscriptionName,

        [Parameter(Mandatory)]
        [scriptblock]$RunPreDeploymentChecks,

        [Parameter(Mandatory)]
        [scriptblock]$RunDeploymentCreate
    )

    $activeSubscriptionName = & $GetActiveSubscriptionName

    Assert-DeploymentAuthorized -Apply:$Apply -ConfirmationPhrase $ConfirmationPhrase `
        -Environment $Environment -Location $Location -ActiveSubscriptionName $activeSubscriptionName

    # Revalidacion completa (bicep build/lint + deployment sub validate + deployment sub what-if).
    # Si cualquier paso falla, este scriptblock lanza una excepcion (via Invoke-AzCommand) y
    # $RunDeploymentCreate jamas se invoca.
    & $RunPreDeploymentChecks

    & $RunDeploymentCreate
}
