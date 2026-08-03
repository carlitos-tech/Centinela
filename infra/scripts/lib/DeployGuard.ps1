<#
.SYNOPSIS
Lógica de autorización pura (sin llamadas a `az`) para el despliegue real de Centinela DEV.

.DESCRIPTION
Assert-DeploymentAuthorized no ejecuta ningún comando externo: solo evalúa, en orden estricto,
las seis condiciones que deben cumplirse simultáneamente antes de que deploy-dev.ps1 pueda
avanzar hacia la solicitud de credenciales SQL y, despues, hacia `az deployment sub create`:

  1. -Apply
  2. -ConfirmationPhrase
  3. -Environment
  4. -Location
  5. Nombre de la suscripcion activa (-ActiveSubscriptionName)
  6. Subscription ID activo vs. CENTINELA_EXPECTED_SUBSCRIPTION_ID (-ActiveSubscriptionId /
     -ExpectedSubscriptionId)

Este orden es intencional (correccion de Fase 04, "orden de las guardas"): ninguna credencial se
solicita antes de superar las seis condiciones, y el Subscription ID esperado se valida de
ultimo, tras confirmar nombre de entorno, region y nombre de suscripcion.

La condicion 6 es una segunda validacion de identidad de la suscripcion, independiente del
nombre: CENTINELA_EXPECTED_SUBSCRIPTION_ID se lee desde el entorno local (nunca tiene un valor
predeterminado en este archivo ni en ningun otro archivo versionado) y nunca se imprime, ni en
consola ni en mensajes de excepcion — los mensajes de error de esta funcion nunca incluyen el
valor de -ActiveSubscriptionId ni el de -ExpectedSubscriptionId.

Al ser pura, se puede probar exhaustivamente sin Azure CLI real (ver
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

        [string]$ActiveSubscriptionName,

        [string]$ActiveSubscriptionId,

        [string]$ExpectedSubscriptionId
    )

    # 1. -Apply
    if (-not $Apply) {
        throw 'Bloqueado: falta el switch -Apply. Sin -Apply, este script nunca ejecuta az deployment sub create.'
    }

    # 2. Frase de confirmacion
    if ($ConfirmationPhrase -ne $script:CentinelaRequiredConfirmationPhrase) {
        throw "Bloqueado: la frase de confirmacion no coincide con '$($script:CentinelaRequiredConfirmationPhrase)'."
    }

    # 3. Entorno
    if ($script:CentinelaAllowedEnvironments -notcontains $Environment) {
        throw "Bloqueado: el entorno '$Environment' no esta en la lista permitida ($($script:CentinelaAllowedEnvironments -join ', '))."
    }

    # 4. Region
    if ($script:CentinelaAllowedLocations -notcontains $Location) {
        throw "Bloqueado: la region '$Location' no esta en la lista permitida ($($script:CentinelaAllowedLocations -join ', '))."
    }

    # 5. Nombre de la suscripcion activa
    if ($ActiveSubscriptionName -ne $script:CentinelaRequiredSubscriptionName) {
        throw "Bloqueado: la suscripcion activa ('$ActiveSubscriptionName') no es '$($script:CentinelaRequiredSubscriptionName)'."
    }

    # 6. Subscription ID esperado (segunda validacion de identidad, independiente del nombre).
    # CENTINELA_EXPECTED_SUBSCRIPTION_ID nunca tiene un valor predeterminado: si no se suministro
    # desde el entorno local, este bloqueo debe activarse sin importar que las condiciones 1-5
    # hayan pasado.
    if ([string]::IsNullOrWhiteSpace($ExpectedSubscriptionId)) {
        throw 'Bloqueado: no se definio la variable de entorno CENTINELA_EXPECTED_SUBSCRIPTION_ID. Esta variable es obligatoria, debe suministrarse desde el entorno local y no tiene valor predeterminado.'
    }

    # Comparacion exacta de dos identificadores ya conocidos por el proceso; ninguno de los dos se
    # incluye en el mensaje de error (solo se reporta el hecho de la discrepancia).
    if ($ActiveSubscriptionId -ne $ExpectedSubscriptionId) {
        throw 'Bloqueado: el Subscription ID de la suscripcion activa no coincide con CENTINELA_EXPECTED_SUBSCRIPTION_ID.'
    }
}
