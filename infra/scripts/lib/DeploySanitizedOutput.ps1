<#
.SYNOPSIS
Formateo de resúmenes sanitizados (Correccion 4, Fase 04) para validate/what-if/create de
Centinela DEV — nunca Tenant ID, nunca Subscription ID, nunca Object ID, nunca credenciales ni
cadenas de conexion, nunca la salida JSON cruda de `az`.

.DESCRIPTION
Estas funciones reciben datos ya parseados (el analisis de Get-CentinelaWhatIfAnalysis, o un
objeto deserializado de la salida JSON de `az`) y devuelven unicamente lineas de texto listas
para Write-Host. Ninguna de ellas escribe a disco ni conserva la salida cruda mas alla de la
variable local que ya recibieron como parametro.
#>

function Format-CentinelaValidateSummary {
    [CmdletBinding()]
    param(
        [string]$ValidateJson
    )

    $provisioningState = 'desconocido'
    try {
        $parsed = $ValidateJson | ConvertFrom-Json -ErrorAction Stop
        if ($parsed.properties -and $parsed.properties.provisioningState) {
            $provisioningState = [string]$parsed.properties.provisioningState
        }
    }
    catch {
        $provisioningState = 'no se pudo interpretar la salida de validate'
    }

    return @("validate: provisioningState=$provisioningState")
}

function Format-CentinelaWhatIfSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Analysis
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('what-if (resumen sanitizado, sin resourceId completos):')

    foreach ($changeType in ($Analysis.Counts.Keys | Sort-Object)) {
        $lines.Add("  $changeType`: $($Analysis.Counts[$changeType])")
    }
    if ($Analysis.Counts.Keys.Count -eq 0) {
        $lines.Add('  (sin cambios reportados)')
    }

    if ($Analysis.ResourceSummaries.Count -gt 0) {
        $lines.Add('  Recursos Create (tipo: nombre publico):')
        foreach ($summary in $Analysis.ResourceSummaries) {
            $lines.Add("    - $summary")
        }
    }

    if ($Analysis.Approved) {
        $lines.Add('  Resultado: APROBADO (coincide con el plan de 9 recursos aprobado).')
    }
    else {
        $lines.Add('  Resultado: BLOQUEADO. Motivos:')
        foreach ($reason in $Analysis.BlockReasons) {
            $lines.Add("    - $reason")
        }
    }

    return $lines
}

function Format-CentinelaCreateSummary {
    [CmdletBinding()]
    param(
        [string]$CreateJson
    )

    $lines = New-Object System.Collections.Generic.List[string]

    try {
        $parsed = $CreateJson | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $lines.Add('create: no se pudo interpretar la salida (no se muestra contenido crudo).')
        return $lines
    }

    $provisioningState = if ($parsed.properties -and $parsed.properties.provisioningState) {
        [string]$parsed.properties.provisioningState
    }
    else { 'desconocido' }
    $lines.Add("create: provisioningState=$provisioningState")

    $publicOutputNames = @(
        'resourceGroupName', 'storageAccountName', 'keyVaultName',
        'webAppName', 'sqlServerName', 'sqlDatabaseName'
    )

    if ($parsed.properties -and $parsed.properties.outputs) {
        foreach ($outputName in $publicOutputNames) {
            $outputProperty = $parsed.properties.outputs.PSObject.Properties[$outputName]
            if ($outputProperty -and $outputProperty.Value.value) {
                $lines.Add("  $outputName = $($outputProperty.Value.value)")
            }
        }
    }

    return $lines
}
