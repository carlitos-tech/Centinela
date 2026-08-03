<#
.SYNOPSIS
Lógica de autorización pura (sin llamadas a `az`) para el despliegue real de Centinela DEV.

.DESCRIPTION
Assert-DeploymentAuthorized no ejecuta ningún comando externo: solo evalúa las cinco condiciones
que deben cumplirse simultáneamente antes de que deploy-dev.ps1 pueda avanzar hacia
`az deployment sub create`. Al ser pura, se puede probar exhaustivamente sin Azure CLI real (ver
infra/scripts/tests/Test-DeployDevGuard.ps1).
#>

$script:CentinelaRequiredConfirmationPhrase = 'AUTORIZO_DESPLIEGUE_CENTINELA_DEV'
$script:CentinelaRequiredSubscriptionName = 'SuscripcionClaudeCode'
$script:CentinelaAllowedEnvironments = @('dev')
$script:CentinelaAllowedLocations = @('eastus2', 'centralus')

function Assert-DeploymentAuthorized {
    [CmdletBinding()]
    param(
        [switch]$Apply,

        [string]$ConfirmationPhrase,

        [string]$Environment,

        [string]$Location,

        [string]$ActiveSubscriptionName
    )

    if (-not $Apply) {
        throw 'Bloqueado: falta el switch -Apply. Sin -Apply, este script nunca ejecuta az deployment sub create.'
    }

    if ($ConfirmationPhrase -ne $script:CentinelaRequiredConfirmationPhrase) {
        throw "Bloqueado: la frase de confirmacion no coincide con '$($script:CentinelaRequiredConfirmationPhrase)'."
    }

    if ($ActiveSubscriptionName -ne $script:CentinelaRequiredSubscriptionName) {
        throw "Bloqueado: la suscripcion activa ('$ActiveSubscriptionName') no es '$($script:CentinelaRequiredSubscriptionName)'."
    }

    if ($script:CentinelaAllowedEnvironments -notcontains $Environment) {
        throw "Bloqueado: el entorno '$Environment' no esta en la lista permitida ($($script:CentinelaAllowedEnvironments -join ', '))."
    }

    if ($script:CentinelaAllowedLocations -notcontains $Location) {
        throw "Bloqueado: la region '$Location' no esta en la lista permitida ($($script:CentinelaAllowedLocations -join ', '))."
    }
}
