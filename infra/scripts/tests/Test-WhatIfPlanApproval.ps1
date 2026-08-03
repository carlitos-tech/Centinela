<#
.SYNOPSIS
Prueba reproducible: el analisis del plan de what-if (Correccion 3, Fase 04) aprueba unicamente
el plan de 9 recursos Create documentado, y bloquea cualquier desviacion — incluyendo una
desviacion que un `az deployment sub what-if` real reportaria con codigo de salida 0.

.DESCRIPTION
Ejercita Get-CentinelaWhatIfAnalysis / Assert-CentinelaWhatIfPlanApproved
(infra/scripts/lib/DeployWhatIfAnalysis.ps1) con JSON de what-if simulado, y
Invoke-CentinelaDevPreDeploymentAndCreate (infra/scripts/lib/DeployOrchestrator.ps1) con
scriptblocks de prueba. Ningun escenario invoca Azure CLI real.

El Subscription ID ficticio usado para construir los resourceId de prueba se genera en tiempo de
ejecucion con [guid]::NewGuid() (nunca como literal en este archivo), para no activar el escaneo
de GUID sin enmascarar del workflow de gobierno.

Escenarios de analisis (Get-CentinelaWhatIfAnalysis), todos sobre el resource group aprobado
rg-novacasa-centinela-dev:
  1. 9 Create permitidos (el plan aprobado exacto) -> Approved = $true.
  2. 1 Delete (un recurso aprobado con changeType=Delete en lugar de Create) -> bloquea.
  3. 1 Modify (un recurso aprobado con changeType=Modify) -> bloquea.
  4. 8 Create (falta un recurso aprobado) -> bloquea.
  5. 10 Create (un recurso adicional no documentado) -> bloquea.
  6. Recurso RBAC (Microsoft.Authorization/roleAssignments) -> bloquea.
  7. Regla de firewall de Azure SQL (Microsoft.Sql/servers/firewallRules) -> bloquea.
  8. Recurso de Microsoft Foundry / Azure AI Search (Microsoft.CognitiveServices/accounts) ->
     bloquea.
  9. JSON invalido -> bloquea.

Escenarios adicionales (Correccion what-if, Fase 04 — cambio de --result-format a
FullResourcePayloads tras el InternalServerError reproducible documentado con ResourceIdOnly):
  10. FullResourcePayloads: 9 Create con propiedades completas (before/after/delta ademas de
      resourceId/changeType) -> Approved = $true. Confirma que Get-CentinelaWhatIfAnalysis no
      requirio adaptacion: solo lee resourceId/changeType, presentes en ambos formatos.
  11. FullResourcePayloads: 1 Delete con propiedades completas -> bloquea igual que con
      ResourceIdOnly.
  12. FullResourcePayloads: 1 Modify con propiedades completas -> bloquea igual que con
      ResourceIdOnly.
  13. Salida de `az` que no es JSON (texto de error plano, no una lista de cambios) -> bloquea con
      un motivo generico ("La salida de what-if no es JSON valido."), y ese texto de error
      (que en este escenario simulado contiene un Subscription ID ficticio, generado con
      [guid]::NewGuid(), nunca un identificador real) jamas aparece en BlockReasons, Counts ni
      ResourceSummaries: Get-CentinelaWhatIfAnalysis nunca hace eco de la entrada cruda.

Escenarios de orquestacion (Invoke-CentinelaDevPreDeploymentAndCreate), que ademas confirman que
$RunDeploymentCreate nunca se invoca cuando el paso anterior falla:
  10. Fallo de Azure CLI en el propio what-if (el scriptblock $RunWhatIf lanza una excepcion) ->
      bloquea, create no se invoca.
  11. CONTROL: bicep validate y what-if tienen exito con el plan de 9 recursos aprobado -> no
      bloquea, create se invoca exactamente una vez.

.OUTPUTS
Codigo de salida 0 si todos los escenarios se comportaron como se esperaba.
Codigo de salida 1 si alguno fallo.
#>

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../lib/DeployWhatIfAnalysis.ps1')
. (Join-Path $PSScriptRoot '../lib/DeployOrchestrator.ps1')

$fakeSubscriptionId = [guid]::NewGuid().ToString()
$resourceGroupName = 'rg-novacasa-centinela-dev'

function New-CentinelaFakeResourceGroupId {
    "/subscriptions/$fakeSubscriptionId/resourceGroups/$resourceGroupName"
}

function New-CentinelaFakeProviderResourceId {
    param([string]$ProviderPath)
    "/subscriptions/$fakeSubscriptionId/resourceGroups/$resourceGroupName/providers/$ProviderPath"
}

# Los 9 recursos aprobados (Correccion 3), cada uno como par (resourceId, changeType=Create).
function Get-CentinelaApprovedChanges {
    @(
        @{ resourceId = (New-CentinelaFakeResourceGroupId); changeType = 'Create' }
        @{ resourceId = (New-CentinelaFakeProviderResourceId 'Microsoft.OperationalInsights/workspaces/log-novacasa-centinela-dev'); changeType = 'Create' }
        @{ resourceId = (New-CentinelaFakeProviderResourceId 'Microsoft.Insights/components/appi-novacasa-centinela-dev'); changeType = 'Create' }
        @{ resourceId = (New-CentinelaFakeProviderResourceId 'Microsoft.Storage/storageAccounts/stnovacascentine'); changeType = 'Create' }
        @{ resourceId = (New-CentinelaFakeProviderResourceId 'Microsoft.KeyVault/vaults/kv-novacas-centinela'); changeType = 'Create' }
        @{ resourceId = (New-CentinelaFakeProviderResourceId 'Microsoft.Web/serverfarms/plan-novacasa-centinela-dev'); changeType = 'Create' }
        @{ resourceId = (New-CentinelaFakeProviderResourceId 'Microsoft.Web/sites/app-novacasa-centinela-dev-api'); changeType = 'Create' }
        @{ resourceId = (New-CentinelaFakeProviderResourceId 'Microsoft.Sql/servers/sql-novacasa-centinela-dev'); changeType = 'Create' }
        @{ resourceId = (New-CentinelaFakeProviderResourceId 'Microsoft.Sql/servers/sql-novacasa-centinela-dev/databases/sqldb-novacasa-centinela-dev'); changeType = 'Create' }
    )
}

function New-CentinelaWhatIfJson {
    param([array]$Changes)
    (@{ changes = $Changes } | ConvertTo-Json -Depth 6)
}

$analysisResults = @()

function Test-Analysis {
    param(
        [string]$Name,
        [string]$Json,
        [bool]$ExpectedApproved
    )
    $analysis = Get-CentinelaWhatIfAnalysis -WhatIfJson $Json -ExpectedResourceGroupName $resourceGroupName
    $pass = ($analysis.Approved -eq $ExpectedApproved)
    $script:analysisResults += [pscustomobject]@{ Name = $Name; Pass = $pass; Approved = $analysis.Approved; Reasons = ($analysis.BlockReasons -join ' | ') }
}

# 1. 9 Create permitidos.
Test-Analysis -Name '9 Create permitidos' -Json (New-CentinelaWhatIfJson -Changes (Get-CentinelaApprovedChanges)) -ExpectedApproved $true

# 2. 1 Delete.
$deleteChanges = Get-CentinelaApprovedChanges
$deleteChanges[3].changeType = 'Delete'
Test-Analysis -Name '1 Delete' -Json (New-CentinelaWhatIfJson -Changes $deleteChanges) -ExpectedApproved $false

# 3. 1 Modify.
$modifyChanges = Get-CentinelaApprovedChanges
$modifyChanges[3].changeType = 'Modify'
Test-Analysis -Name '1 Modify' -Json (New-CentinelaWhatIfJson -Changes $modifyChanges) -ExpectedApproved $false

# 4. 8 Create (falta un recurso aprobado).
$eightChanges = (Get-CentinelaApprovedChanges) | Select-Object -First 8
Test-Analysis -Name '8 Create' -Json (New-CentinelaWhatIfJson -Changes $eightChanges) -ExpectedApproved $false

# 5. 10 Create (un recurso adicional no documentado).
$tenChanges = Get-CentinelaApprovedChanges
$tenChanges += @{ resourceId = (New-CentinelaFakeProviderResourceId 'Microsoft.Storage/storageAccounts/stnovacasextra'); changeType = 'Create' }
Test-Analysis -Name '10 Create' -Json (New-CentinelaWhatIfJson -Changes $tenChanges) -ExpectedApproved $false

# 6. Recurso RBAC.
$rbacChanges = Get-CentinelaApprovedChanges
$rbacChanges[3] = @{ resourceId = (New-CentinelaFakeProviderResourceId 'Microsoft.Authorization/roleAssignments/ra-test-assignment'); changeType = 'Create' }
Test-Analysis -Name 'Recurso RBAC' -Json (New-CentinelaWhatIfJson -Changes $rbacChanges) -ExpectedApproved $false

# 7. Regla de firewall de Azure SQL.
$sqlRuleChanges = Get-CentinelaApprovedChanges
$sqlRuleChanges[3] = @{ resourceId = (New-CentinelaFakeProviderResourceId 'Microsoft.Sql/servers/sql-novacasa-centinela-dev/firewallRules/AllowAzureServices'); changeType = 'Create' }
Test-Analysis -Name 'Regla de firewall de Azure SQL' -Json (New-CentinelaWhatIfJson -Changes $sqlRuleChanges) -ExpectedApproved $false

# 8. Recurso de Microsoft Foundry / Azure AI Search.
$foundryChanges = Get-CentinelaApprovedChanges
$foundryChanges[3] = @{ resourceId = (New-CentinelaFakeProviderResourceId 'Microsoft.CognitiveServices/accounts/foundry-novacasa-centinela-dev'); changeType = 'Create' }
Test-Analysis -Name 'Recurso de Microsoft Foundry / Azure AI Search' -Json (New-CentinelaWhatIfJson -Changes $foundryChanges) -ExpectedApproved $false

# 9. JSON invalido.
Test-Analysis -Name 'JSON invalido' -Json '{ esto no es json valido' -ExpectedApproved $false

# ---------------------------------------------------------------------------------------------
# Escenarios FullResourcePayloads (Correccion what-if, Fase 04).
# ---------------------------------------------------------------------------------------------

function New-CentinelaFullPayloadChange {
    param(
        [string]$ResourceId,
        [string]$ChangeType
    )
    @{
        resourceId = $ResourceId
        changeType = $ChangeType
        # Campos adicionales que FullResourcePayloads agrega y ResourceIdOnly no incluye.
        # Get-CentinelaWhatIfAnalysis no los lee; se agregan aqui para demostrar que su presencia
        # no rompe ni altera el analisis.
        before     = $null
        after      = @{ id = $ResourceId; name = 'placeholder'; type = 'placeholder' }
        delta      = @()
    }
}

function Get-CentinelaApprovedChangesFullPayload {
    (Get-CentinelaApprovedChanges) | ForEach-Object {
        New-CentinelaFullPayloadChange -ResourceId $_.resourceId -ChangeType $_.changeType
    }
}

# 10. FullResourcePayloads: 9 Create con propiedades completas.
Test-Analysis -Name 'FullResourcePayloads: 9 Create con propiedades completas' `
    -Json (New-CentinelaWhatIfJson -Changes (Get-CentinelaApprovedChangesFullPayload)) -ExpectedApproved $true

# 11. FullResourcePayloads: 1 Delete con propiedades completas.
$fullDeleteChanges = @(Get-CentinelaApprovedChangesFullPayload)
$fullDeleteChanges[3].changeType = 'Delete'
Test-Analysis -Name 'FullResourcePayloads: 1 Delete con propiedades completas' `
    -Json (New-CentinelaWhatIfJson -Changes $fullDeleteChanges) -ExpectedApproved $false

# 12. FullResourcePayloads: 1 Modify con propiedades completas.
$fullModifyChanges = @(Get-CentinelaApprovedChangesFullPayload)
$fullModifyChanges[3].changeType = 'Modify'
Test-Analysis -Name 'FullResourcePayloads: 1 Modify con propiedades completas' `
    -Json (New-CentinelaWhatIfJson -Changes $fullModifyChanges) -ExpectedApproved $false

# 13. Salida de `az` que no es JSON de una lista de cambios (texto de error plano), con un
# Subscription ID FICTICIO ([guid]::NewGuid(), nunca un identificador real) embebido, para
# confirmar que Get-CentinelaWhatIfAnalysis nunca hace eco de la entrada cruda en sus salidas.
$redactionFakeSubscriptionId = [guid]::NewGuid().ToString()
$rawErrorText = "ERROR: (AuthorizationFailed) The client does not have authorization to perform action 'Microsoft.Resources/deployments/write' over scope '/subscriptions/$redactionFakeSubscriptionId/resourceGroups/$resourceGroupName'."
$redactionAnalysis = Get-CentinelaWhatIfAnalysis -WhatIfJson $rawErrorText -ExpectedResourceGroupName $resourceGroupName
$redactionApprovedPass = ($redactionAnalysis.Approved -eq $false)
$redactionBlockReasonsText = ($redactionAnalysis.BlockReasons -join ' | ')
$redactionCountsText = ($redactionAnalysis.Counts.Keys -join ',')
$redactionSummariesText = ($redactionAnalysis.ResourceSummaries -join ' | ')
$redactionNeverLeaksPass = (-not $redactionBlockReasonsText.Contains($redactionFakeSubscriptionId)) -and `
    (-not $redactionCountsText.Contains($redactionFakeSubscriptionId)) -and `
    (-not $redactionSummariesText.Contains($redactionFakeSubscriptionId)) -and `
    (-not $redactionBlockReasonsText.Contains($rawErrorText))
$analysisResults += [pscustomobject]@{
    Name     = '13. Salida no-JSON con Subscription ID ficticio: bloquea y nunca hace eco del texto crudo'
    Pass     = ($redactionApprovedPass -and $redactionNeverLeaksPass)
    Approved = $redactionAnalysis.Approved
    Reasons  = $redactionBlockReasonsText
}

# ---------------------------------------------------------------------------------------------
# Escenarios de orquestacion (Invoke-CentinelaDevPreDeploymentAndCreate).
# ---------------------------------------------------------------------------------------------

function Invoke-OrchestratorScenario {
    param(
        [string]$Name,
        [bool]$WhatIfFails,
        [bool]$ExpectedBlocked,
        [int]$ExpectedCreateCount
    )

    $script:createInvocationCount = 0
    $script:reportInvocationCount = 0

    $runBicepValidate = { }

    # El JSON se precalcula fuera del scriptblock: .GetNewClosure() solo captura variables, no
    # las funciones definidas en este script, asi que el scriptblock no puede invocar
    # New-CentinelaWhatIfJson/Get-CentinelaApprovedChanges por su nombre.
    $approvedPlanJson = New-CentinelaWhatIfJson -Changes (Get-CentinelaApprovedChanges)

    $runWhatIf = {
        if ($WhatIfFails) {
            throw "Fallo simulado de 'az' durante el what-if (codigo de salida distinto de 0)."
        }
        return $approvedPlanJson
    }.GetNewClosure()

    $reportWhatIfAnalysis = {
        param($analysis)
        $script:reportInvocationCount++
    }

    $runDeploymentCreate = {
        $script:createInvocationCount++
    }

    $blocked = $false
    $errorMessage = $null
    try {
        Invoke-CentinelaDevPreDeploymentAndCreate -RunBicepValidate $runBicepValidate `
            -RunWhatIf $runWhatIf -ReportWhatIfAnalysis $reportWhatIfAnalysis `
            -RunDeploymentCreate $runDeploymentCreate -ExpectedResourceGroupName $resourceGroupName | Out-Null
    }
    catch {
        $blocked = $true
        $errorMessage = $_.Exception.Message
    }

    $pass = ($blocked -eq $ExpectedBlocked) -and ($script:createInvocationCount -eq $ExpectedCreateCount)
    [pscustomobject]@{ Name = $Name; Pass = $pass; Blocked = $blocked; CreateInvocations = $script:createInvocationCount; ErrorMessage = $errorMessage }
}

$orchestratorResults = @()
$orchestratorResults += Invoke-OrchestratorScenario -Name 'Fallo de Azure CLI en what-if' -WhatIfFails $true -ExpectedBlocked $true -ExpectedCreateCount 0
$orchestratorResults += Invoke-OrchestratorScenario -Name 'CONTROL: plan aprobado llega a create' -WhatIfFails $false -ExpectedBlocked $false -ExpectedCreateCount 1

# ---------------------------------------------------------------------------------------------
# Resultado consolidado.
# ---------------------------------------------------------------------------------------------

$allPassed = $true

foreach ($result in $analysisResults) {
    $status = if ($result.Pass) { 'PASS' } else { 'FAIL' }
    if (-not $result.Pass) { $allPassed = $false }
    Write-Host "[$status] $($result.Name): Approved=$($result.Approved) $(if ($result.Reasons) { "-- $($result.Reasons)" })"
}

foreach ($result in $orchestratorResults) {
    $status = if ($result.Pass) { 'PASS' } else { 'FAIL' }
    if (-not $result.Pass) { $allPassed = $false }
    Write-Host "[$status] $($result.Name): Blocked=$($result.Blocked) CreateInvocations=$($result.CreateInvocations) $(if ($result.ErrorMessage) { "-- $($result.ErrorMessage)" })"
}

if ($allPassed) {
    Write-Host 'PASS: el analisis del what-if aprueba unicamente el plan de 9 recursos documentado, bloquea toda desviacion, y el orquestador nunca invoca create salvo en el escenario de control.'
    exit 0
}
else {
    Write-Error 'FAIL: al menos un escenario de analisis de what-if no se comporto como se esperaba.'
    exit 1
}
