<#
.SYNOPSIS
Prueba reproducible: infra/scripts/deploy-dev.ps1 (via Invoke-CentinelaDevDeployment) nunca llega a
'az deployment sub create' bajo ninguno de los cinco escenarios bloqueados.

.DESCRIPTION
Ejercita Invoke-CentinelaDevDeployment (infra/scripts/lib/DeployOrchestrator.ps1) con scriptblocks
de prueba: $GetActiveSubscriptionName y $RunPreDeploymentChecks devuelven valores controlados,
$RunDeploymentCreate solo incrementa un contador en memoria. Ningun escenario de esta prueba invoca
Azure CLI real.

Escenarios verificados (todos deben bloquear, contador de create = 0):
  1. Falta -Apply.
  2. -ConfirmationPhrase incorrecta.
  3. Suscripcion activa distinta de 'SuscripcionClaudeCode'.
  4. -Environment fuera de la lista permitida.
  5. $RunPreDeploymentChecks falla (simula un 'az' que retorna codigo de salida distinto de 0
     durante la revalidacion previa al apply).

Y un escenario de control que confirma que, cuando las cinco condiciones se cumplen, el contador de
create SI se incrementa exactamente una vez (para que la prueba no pase trivialmente por un error
en el propio arnes de pruebas).

.OUTPUTS
Codigo de salida 0 si los 6 escenarios se comportaron como se esperaba.
Codigo de salida 1 si alguno fallo.
#>

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../lib/DeployOrchestrator.ps1')

$validPhrase = 'AUTORIZO_DESPLIEGUE_CENTINELA_DEV'
$validSubscription = 'SuscripcionClaudeCode'

function Invoke-GuardScenario {
    param(
        [string]$Name,
        [hashtable]$Params,
        [string]$SubscriptionName = $validSubscription,
        [bool]$PreChecksFail = $false
    )

    $script:createInvocationCount = 0
    $script:preChecksInvocationCount = 0

    $getActiveSubscriptionName = { $SubscriptionName }.GetNewClosure()

    $runPreDeploymentChecks = {
        $script:preChecksInvocationCount++
        if ($PreChecksFail) {
            throw "Fallo simulado de 'az' durante la revalidacion previa al apply (codigo de salida distinto de 0)."
        }
    }.GetNewClosure()

    $runDeploymentCreate = {
        $script:createInvocationCount++
    }

    $blocked = $false
    $errorMessage = $null
    try {
        Invoke-CentinelaDevDeployment @Params `
            -GetActiveSubscriptionName $getActiveSubscriptionName `
            -RunPreDeploymentChecks $runPreDeploymentChecks `
            -RunDeploymentCreate $runDeploymentCreate
    }
    catch {
        $blocked = $true
        $errorMessage = $_.Exception.Message
    }

    [pscustomobject]@{
        Name             = $Name
        Blocked          = $blocked
        ErrorMessage     = $errorMessage
        CreateInvocations = $script:createInvocationCount
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

# 3. Suscripcion incorrecta.
$results += Invoke-GuardScenario -Name 'Suscripcion incorrecta' -Params @{
    Apply               = $true
    ConfirmationPhrase  = $validPhrase
    Environment         = 'dev'
    Location            = 'eastus2'
} -SubscriptionName 'OtraSuscripcionDistinta'

# 4. Entorno fuera de la lista permitida.
$results += Invoke-GuardScenario -Name 'Entorno no permitido' -Params @{
    Apply               = $true
    ConfirmationPhrase  = $validPhrase
    Environment         = 'prod'
    Location            = 'eastus2'
}

# 5. Fallo simulado de 'az' en la revalidacion previa (todas las guardas de autorizacion pasan).
$results += Invoke-GuardScenario -Name 'Fallo de az en revalidacion' -Params @{
    Apply               = $true
    ConfirmationPhrase  = $validPhrase
    Environment         = 'dev'
    Location            = 'eastus2'
} -PreChecksFail $true

# 6. Control: todas las condiciones correctas -> debe llegar a create exactamente una vez.
$results += Invoke-GuardScenario -Name 'CONTROL: todo correcto' -Params @{
    Apply               = $true
    ConfirmationPhrase  = $validPhrase
    Environment         = 'dev'
    Location            = 'eastus2'
}

$allPassed = $true

foreach ($result in $results) {
    if ($result.Name -eq 'CONTROL: todo correcto') {
        $expectedBlocked = $false
        $expectedCreateCount = 1
    }
    else {
        $expectedBlocked = $true
        $expectedCreateCount = 0
    }

    $pass = ($result.Blocked -eq $expectedBlocked) -and ($result.CreateInvocations -eq $expectedCreateCount)
    $status = if ($pass) { 'PASS' } else { 'FAIL' }
    if (-not $pass) { $allPassed = $false }

    Write-Host "[$status] $($result.Name): Blocked=$($result.Blocked) CreateInvocations=$($result.CreateInvocations) $(if ($result.ErrorMessage) { "-- $($result.ErrorMessage)" })"
}

if ($allPassed) {
    Write-Host 'PASS: deploy-dev.ps1 (via Invoke-CentinelaDevDeployment) nunca alcanza az deployment sub create en ningun escenario bloqueado, y si lo alcanza en el escenario de control valido.'
    exit 0
}
else {
    Write-Error 'FAIL: al menos un escenario de guarda no se comporto como se esperaba.'
    exit 1
}
