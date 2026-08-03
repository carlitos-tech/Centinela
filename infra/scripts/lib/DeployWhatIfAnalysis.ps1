<#
.SYNOPSIS
Analisis puro (sin llamadas a `az`) del resultado JSON de `az deployment sub what-if` para
Centinela DEV, usado como guarda obligatoria antes de `az deployment sub create`.

.DESCRIPTION
Antes de esta correccion, deploy-dev.ps1 solo verificaba que `az deployment sub what-if`
terminara con codigo de salida 0 (via Invoke-AzCommand) y avanzaba directamente a create. Un
what-if puede terminar con codigo de salida 0 y, aun asi, describir cambios inesperados o no
aprobados (una asignacion RBAC, una regla de firewall de SQL, un recurso fuera del resource group
de DEV, un numero distinto de recursos). Get-CentinelaWhatIfAnalysis / Assert-CentinelaWhatIfPlanApproved
cierran esa brecha analizando cada cambio individual, no solo el codigo de salida.

Plan aprobado (Fase 04, Correccion 3) — exactamente estos 9 recursos, todos con changeType=Create,
todos dentro de rg-novacasa-centinela-dev (el propio Resource Group es el unico recurso cuyo ID no
contiene el segmento /resourceGroups/rg-novacasa-centinela-dev/ porque es un recurso de alcance de
suscripcion):

  1. Microsoft.Resources/resourceGroups
  2. Microsoft.OperationalInsights/workspaces
  3. Microsoft.Insights/components
  4. Microsoft.Storage/storageAccounts
  5. Microsoft.KeyVault/vaults
  6. Microsoft.Web/serverfarms
  7. Microsoft.Web/sites
  8. Microsoft.Sql/servers
  9. Microsoft.Sql/servers/databases

Cualquier otro tipo de cambio (Delete, Modify, Ignore, o cualquier changeType distinto de Create),
cualquier recurso fuera de rg-novacasa-centinela-dev, cualquier asignacion RBAC
(Microsoft.Authorization/roleAssignments), cualquier regla de firewall de Azure SQL
(Microsoft.Sql/servers/firewallRules), cualquier recurso de Microsoft Foundry / Cognitive Services
(Microsoft.CognitiveServices/*, Microsoft.MachineLearningServices/*), cualquier recurso de Azure
AI Search (Microsoft.Search/searchServices), un conteo de Create distinto de 9, o un JSON invalido
o irreconocible, hacen que Get-CentinelaWhatIfAnalysis devuelva Approved=$false con motivos
sanitizados (nunca un resourceId completo, que incluiria el Subscription ID) en BlockReasons.
Assert-CentinelaWhatIfPlanApproved lanza una excepcion en ese caso, para que deploy-dev.ps1 jamas
invoque `az deployment sub create` y, en su lugar, muestre el resumen sanitizado y requiera una
nueva aprobacion humana.

Al ser puras (reciben el JSON de what-if como string, no ejecutan `az`), estas funciones se prueban
exhaustivamente con what-if simulado (ver infra/scripts/tests/Test-WhatIfPlanApproval.ps1).

Correccion short-circuit (Fase 04): un modulo anidado cuyos parametros dependen de un output de otro
modulo aun no desplegado puede ser excluido por completo del arreglo "changes" sin que el what-if
falle (codigo de salida 0, JSON valido). Azure CLI >= 2.75.0 / Az PowerShell >= 13.1.0 exponen esto
mediante un arreglo "diagnostics" (a nivel raiz y/o por cambio) con codigos como
NestedDeploymentShortCircuited o NestedDeploymentSkippedFromInternalExpansion. Estos diagnosticos
pueden incluir en su "message" el nombre completo del modulo/recurso afectado, por lo que
Get-CentinelaWhatIfAnalysis nunca imprime ese mensaje crudo: solo registra el "code" y "level"
(ambos son constantes fijas de Azure, no contienen identificadores de la suscripcion) y bloquea el
plan igual que ante cualquier otra discrepancia.
#>

$script:CentinelaExpectedResourceGroupName = 'rg-novacasa-centinela-dev'

$script:CentinelaIncompleteAnalysisDiagnosticCodes = @(
    'NestedDeploymentShortCircuited'
    'NestedDeploymentSkippedFromInternalExpansion'
)

$script:CentinelaApprovedResourceTypes = @(
    'Microsoft.Resources/resourceGroups'
    'Microsoft.OperationalInsights/workspaces'
    'Microsoft.Insights/components'
    'Microsoft.Storage/storageAccounts'
    'Microsoft.KeyVault/vaults'
    'Microsoft.Web/serverfarms'
    'Microsoft.Web/sites'
    'Microsoft.Sql/servers'
    'Microsoft.Sql/servers/databases'
)

function ConvertTo-CentinelaResourceDescriptor {
    [CmdletBinding()]
    param(
        [string]$ResourceId
    )

    if ($ResourceId -match '^/subscriptions/[^/]+/resourceGroups/([^/]+)$') {
        return [pscustomobject]@{
            ResourceGroupName = $matches[1]
            ResourceType      = 'Microsoft.Resources/resourceGroups'
            ResourceName      = $matches[1]
        }
    }

    if ($ResourceId -match '^/subscriptions/[^/]+/resourceGroups/([^/]+)/providers/(.+)$') {
        $rgName = $matches[1]
        $providerPath = $matches[2]
        $segments = $providerPath -split '/'

        if ($segments.Count -lt 2) {
            return [pscustomobject]@{
                ResourceGroupName = $rgName
                ResourceType      = $providerPath
                ResourceName      = $null
            }
        }

        $providerNamespace = $segments[0]
        $typeParts = New-Object System.Collections.Generic.List[string]
        $nameParts = New-Object System.Collections.Generic.List[string]

        for ($i = 1; $i -lt $segments.Count; $i += 2) {
            $typeParts.Add($segments[$i])
            if ($i + 1 -lt $segments.Count) { $nameParts.Add($segments[$i + 1]) }
        }

        $resourceType = "$providerNamespace/$($typeParts -join '/')"
        $resourceName = if ($nameParts.Count -gt 0) { $nameParts[$nameParts.Count - 1] } else { $null }

        return [pscustomobject]@{
            ResourceGroupName = $rgName
            ResourceType      = $resourceType
            ResourceName      = $resourceName
        }
    }

    return [pscustomobject]@{
        ResourceGroupName = $null
        ResourceType       = 'Desconocido'
        ResourceName        = $null
    }
}

function Add-CentinelaDiagnosticsBlockReasons {
    [CmdletBinding()]
    param(
        [System.Collections.Generic.List[string]]$BlockReasons,

        $Diagnostics
    )

    if (-not $Diagnostics) { return }

    foreach ($diagnostic in @($Diagnostics)) {
        $code = [string]$diagnostic.code
        if ([string]::IsNullOrWhiteSpace($code)) { continue }

        if ($script:CentinelaIncompleteAnalysisDiagnosticCodes -contains $code) {
            $level = [string]$diagnostic.level
            if ([string]::IsNullOrWhiteSpace($level)) { $level = 'Desconocido' }
            $BlockReasons.Add("El analisis de what-if reporto un diagnostico de evaluacion incompleta (code=$code, level=$level); el plan no puede aprobarse sin una evaluacion completa de todos los modulos.")
        }
    }
}

function Get-CentinelaWhatIfAnalysis {
    [CmdletBinding()]
    param(
        [string]$WhatIfJson,

        [string]$ExpectedResourceGroupName = $script:CentinelaExpectedResourceGroupName
    )

    $counts = @{}
    $blockReasons = New-Object System.Collections.Generic.List[string]
    $resourceSummaries = New-Object System.Collections.Generic.List[string]
    $seenApprovedTypes = New-Object System.Collections.Generic.List[string]

    $parsed = $null
    try {
        $parsed = $WhatIfJson | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $blockReasons.Add('La salida de what-if no es JSON valido.')
    }

    if ($parsed -and -not ($parsed.PSObject.Properties.Name -contains 'changes')) {
        $blockReasons.Add('La salida de what-if no contiene una lista de cambios reconocible (falta la propiedad "changes").')
        $parsed = $null
    }

    if ($parsed) {
        if ($parsed.PSObject.Properties.Name -contains 'diagnostics') {
            Add-CentinelaDiagnosticsBlockReasons -BlockReasons $blockReasons -Diagnostics $parsed.diagnostics
        }

        foreach ($change in $parsed.changes) {
            if ($change.PSObject.Properties.Name -contains 'diagnostics') {
                Add-CentinelaDiagnosticsBlockReasons -BlockReasons $blockReasons -Diagnostics $change.diagnostics
            }

            $changeType = [string]$change.changeType
            if ([string]::IsNullOrWhiteSpace($changeType)) { $changeType = 'Desconocido' }
            if ($counts.ContainsKey($changeType)) { $counts[$changeType]++ } else { $counts[$changeType] = 1 }

            $descriptor = ConvertTo-CentinelaResourceDescriptor -ResourceId ([string]$change.resourceId)

            if ($descriptor.ResourceGroupName -and $descriptor.ResourceGroupName -ne $ExpectedResourceGroupName) {
                $blockReasons.Add("Recurso fuera del resource group esperado (tipo: $($descriptor.ResourceType)).")
            }

            if ($changeType -ne 'Create') {
                $blockReasons.Add("Cambio de tipo '$changeType' no permitido (unicamente se permiten cambios Create).")
                continue
            }

            $resourceSummaries.Add("$($descriptor.ResourceType): $($descriptor.ResourceName)")

            if ($descriptor.ResourceType -eq 'Microsoft.Authorization/roleAssignments') {
                $blockReasons.Add('Se detecto una asignacion RBAC no aprobada en el plan.')
            }
            elseif ($descriptor.ResourceType -eq 'Microsoft.Sql/servers/firewallRules') {
                $blockReasons.Add('Se detecto una regla de firewall de Azure SQL no aprobada en el plan.')
            }
            elseif ($descriptor.ResourceType -like 'Microsoft.CognitiveServices/*' -or $descriptor.ResourceType -like 'Microsoft.MachineLearningServices/*') {
                $blockReasons.Add('Se detecto un recurso de Microsoft Foundry / Cognitive Services no aprobado en el plan.')
            }
            elseif ($descriptor.ResourceType -eq 'Microsoft.Search/searchServices') {
                $blockReasons.Add('Se detecto un recurso de Azure AI Search no aprobado en el plan.')
            }
            elseif ($script:CentinelaApprovedResourceTypes -notcontains $descriptor.ResourceType) {
                $blockReasons.Add("Tipo de recurso no aprobado en el plan: $($descriptor.ResourceType).")
            }
            else {
                $seenApprovedTypes.Add($descriptor.ResourceType)
            }
        }

        $createCount = if ($counts.ContainsKey('Create')) { $counts['Create'] } else { 0 }
        if ($createCount -ne $script:CentinelaApprovedResourceTypes.Count) {
            $blockReasons.Add("Se esperaban exactamente $($script:CentinelaApprovedResourceTypes.Count) operaciones Create; se encontraron $createCount.")
        }

        $missingTypes = $script:CentinelaApprovedResourceTypes | Where-Object { $seenApprovedTypes -notcontains $_ }
        if ($missingTypes.Count -gt 0) {
            $blockReasons.Add("Faltan recursos aprobados en el plan: $($missingTypes -join ', ').")
        }
    }

    [pscustomobject]@{
        Approved          = ($blockReasons.Count -eq 0)
        BlockReasons      = $blockReasons
        Counts            = $counts
        ResourceSummaries = $resourceSummaries
    }
}

function Assert-CentinelaWhatIfPlanApproved {
    [CmdletBinding()]
    param(
        [string]$WhatIfJson,

        [string]$ExpectedResourceGroupName = $script:CentinelaExpectedResourceGroupName
    )

    $analysis = Get-CentinelaWhatIfAnalysis -WhatIfJson $WhatIfJson -ExpectedResourceGroupName $ExpectedResourceGroupName

    if (-not $analysis.Approved) {
        throw "Bloqueado: el plan de what-if no coincide con el plan aprobado ($($analysis.BlockReasons -join '; ')). Se requiere una nueva aprobacion humana antes de continuar."
    }

    return $analysis
}
