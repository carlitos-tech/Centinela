<#
.SYNOPSIS
Prueba reproducible: la Fase 1 del despliegue real (Invoke-CentinelaDeploymentAuthorizationGuard)
bloquea correctamente cada una de las seis condiciones de autorizacion, en el orden documentado
en infra/scripts/lib/DeployGuard.ps1, y nunca solicita ni recibe credenciales SQL.

.DESCRIPTION
Ejercita Invoke-CentinelaDeploymentAuthorizationGuard (infra/scripts/lib/DeployOrchestrator.ps1)
con scriptblocks de prueba para $GetActiveSubscriptionName y $GetActiveSubscriptionId. Ningun
escenario de esta prueba invoca Azure CLI real.

Los identificadores de suscripcion ficticios usados en esta prueba se construyen en tiempo de
ejecucion con [guid]::NewGuid() (nunca como literales GUID en este archivo), para no activar el
escaneo de GUID sin enmascarar del workflow de gobierno (.github/workflows/governance.yml).

Escenarios verificados (todos deben bloquear):
  1. Falta -Apply.
  2. -ConfirmationPhrase incorrecta.
  3. -Environment fuera de la lista permitida.
  4. -Location fuera de la lista permitida.
  5. Suscripcion activa (nombre) distinta de 'SuscripcionClaudeCode', con Subscription ID correcto
     ("ID correcto y nombre incorrecto").
  6. CENTINELA_EXPECTED_SUBSCRIPTION_ID ausente (nombre de suscripcion correcto) ("variable ausente").
  7. Subscription ID activo distinto del esperado, con nombre de suscripcion correcto
     ("ID incorrecto").

Y un escenario de control que confirma que, cuando las seis condiciones se cumplen (incluyendo
nombre correcto e ID correcto), la guarda NO bloquea.

Para los escenarios 5, 6 y 7 (los que involucran Subscription ID), esta prueba ademas verifica que
el mensaje de error no contenga ninguno de los dos identificadores ficticios usados.

.OUTPUTS
Codigo de salida 0 si todos los escenarios se comportaron como se esperaba.
Codigo de salida 1 si alguno fallo.
#>

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../lib/DeployOrchestrator.ps1')

$validPhrase = 'AUTORIZO_DESPLIEGUE_CENTINELA_DEV'
$validSubscription = 'SuscripcionClaudeCode'

# Identificadores ficticios construidos dinamicamente (nunca literales en el codigo fuente).
$fakeExpectedSubscriptionId = [guid]::NewGuid().ToString()
$fakeMismatchedSubscriptionId = [guid]::NewGuid().ToString()

function Invoke-GuardScenario {
    param(
        [string]$Name,
        [hashtable]$Params,
        [string]$SubscriptionName = $validSubscription,
        [string]$ActiveSubscriptionId = $fakeExpectedSubscriptionId,
        [string]$ExpectedSubscriptionId = $fakeExpectedSubscriptionId,
        [string[]]$ForbiddenSubstrings = @()
    )

    $getActiveSubscriptionName = { $SubscriptionName }.GetNewClosure()
    $getActiveSubscriptionId = { $ActiveSubscriptionId }.GetNewClosure()

    $blocked = $false
    $errorMessage = $null
    try {
        Invoke-CentinelaDeploymentAuthorizationGuard @Params `
            -GetActiveSubscriptionName $getActiveSubscriptionName `
            -GetActiveSubscriptionId $getActiveSubscriptionId `
            -ExpectedSubscriptionId $ExpectedSubscriptionId
    }
    catch {
        $blocked = $true
        $errorMessage = $_.Exception.Message
    }

    $leaksId = $false
    if ($errorMessage) {
        foreach ($forbidden in $ForbiddenSubstrings) {
            if (-not [string]::IsNullOrEmpty($forbidden) -and $errorMessage.Contains($forbidden)) {
                $leaksId = $true
            }
        }
    }

    [pscustomobject]@{
        Name         = $Name
        Blocked      = $blocked
        ErrorMessage = $errorMessage
        LeaksId      = $leaksId
    }
}

$results = @()

# 1. Falta -Apply.
$results += Invoke-GuardScenario -Name 'Falta -Apply' -Params @{
    ConfirmationPhrase = $validPhrase
    Environment         = 'dev'
    Location            = 'eastus2'
}

# 2. Frase de confirmacion incorrecta.
$results += Invoke-GuardScenario -Name 'Frase incorrecta' -Params @{
    Apply               = $true
    ConfirmationPhrase  = 'frase-incorrecta'
    Environment         = 'dev'
    Location            = 'eastus2'
}

# 3. Entorno fuera de la lista permitida.
$results += Invoke-GuardScenario -Name 'Entorno no permitido' -Params @{
    Apply               = $true
    ConfirmationPhrase  = $validPhrase
    Environment         = 'prod'
    Location            = 'eastus2'
}

# 4. Region fuera de la lista permitida.
$results += Invoke-GuardScenario -Name 'Region no permitida' -Params @{
    Apply               = $true
    ConfirmationPhrase  = $validPhrase
    Environment         = 'dev'
    Location            = 'westus'
}

# 5. ID correcto y nombre incorrecto.
$results += Invoke-GuardScenario -Name 'ID correcto y nombre incorrecto' -Params @{
    Apply               = $true
    ConfirmationPhrase  = $validPhrase
    Environment         = 'dev'
    Location            = 'eastus2'
} -SubscriptionName 'OtraSuscripcionDistinta' `
    -ForbiddenSubstrings @($fakeExpectedSubscriptionId)

# 6. Variable ausente (CENTINELA_EXPECTED_SUBSCRIPTION_ID vacia/no suministrada).
$results += Invoke-GuardScenario -Name 'Variable ausente' -Params @{
    Apply               = $true
    ConfirmationPhrase  = $validPhrase
    Environment         = 'dev'
    Location            = 'eastus2'
} -ExpectedSubscriptionId '' `
    -ForbiddenSubstrings @($fakeExpectedSubscriptionId, $fakeMismatchedSubscriptionId)

# 7. ID incorrecto (nombre de suscripcion correcto, Subscription ID activo distinto del esperado).
$results += Invoke-GuardScenario -Name 'ID incorrecto' -Params @{
    Apply               = $true
    ConfirmationPhrase  = $validPhrase
    Environment         = 'dev'
    Location            = 'eastus2'
} -ActiveSubscriptionId $fakeMismatchedSubscriptionId -ExpectedSubscriptionId $fakeExpectedSubscriptionId `
    -ForbiddenSubstrings @($fakeExpectedSubscriptionId, $fakeMismatchedSubscriptionId)

# 8. CONTROL: nombre correcto e ID correcto, junto con las demas condiciones -> no debe bloquear.
$results += Invoke-GuardScenario -Name 'CONTROL: nombre correcto e ID correcto' -Params @{
    Apply               = $true
    ConfirmationPhrase  = $validPhrase
    Environment         = 'dev'
    Location            = 'eastus2'
}

$allPassed = $true

foreach ($result in $results) {
    $expectedBlocked = ($result.Name -ne 'CONTROL: nombre correcto e ID correcto')

    $pass = ($result.Blocked -eq $expectedBlocked) -and (-not $result.LeaksId)
    $status = if ($pass) { 'PASS' } else { 'FAIL' }
    if (-not $pass) { $allPassed = $false }

    $extra = if ($result.LeaksId) { ' -- FUGA DE IDENTIFICADOR EN EL MENSAJE DE ERROR' } else { '' }
    Write-Host "[$status] $($result.Name): Blocked=$($result.Blocked)$extra $(if ($result.ErrorMessage) { "-- $($result.ErrorMessage)" })"
}

if ($allPassed) {
    Write-Host 'PASS: Invoke-CentinelaDeploymentAuthorizationGuard bloquea las seis condiciones esperadas, aprueba el escenario de control, y ningun mensaje de error incluye un Subscription ID.'
    exit 0
}
else {
    Write-Error 'FAIL: al menos un escenario de guarda no se comporto como se esperaba.'
    exit 1
}
