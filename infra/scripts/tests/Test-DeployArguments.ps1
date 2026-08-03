<#
.SYNOPSIS
Prueba reproducible: Get-CentinelaDeploymentArguments (Correccion 2, Fase 04) genera
`primaryLocation=<Location>` explicito y consistente con `--location`, para que la region del
deployment y la region real de los recursos nunca queden desincronizadas.

.DESCRIPTION
No ejecuta `az` en ningun momento; solo inspecciona el arreglo de argumentos devuelto por
Get-CentinelaDeploymentArguments (infra/scripts/lib/DeployArguments.ps1).

Escenarios verificados:
  1. -Location eastus2 -> los argumentos incluyen '--location','eastus2' y
     '--parameters','primaryLocation=eastus2'.
  2. -Location centralus -> los argumentos incluyen '--location','centralus' y
     '--parameters','primaryLocation=centralus'.
  3. Ninguna otra region es aceptada (por ejemplo, 'westus' lanza una excepcion).
  4. -Operation 'what-if' siempre incluye '--no-pretty-print' (sin este flag, `az deployment ...
     what-if` ignora --output/-o y devuelve un diff de texto en vez de JSON; confirmado de forma
     empirica contra Azure real durante la VALIDACION de esta correccion).

.OUTPUTS
Codigo de salida 0 si los tres escenarios se comportaron como se esperaba.
Codigo de salida 1 si alguno fallo.
#>

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../lib/DeployArguments.ps1')

$templateFile = 'C:\ruta-ficticia\main.bicep'
$paramsFile = 'C:\ruta-ficticia\dev.bicepparam'

function Test-ArgumentContainsPair {
    param(
        [string[]]$Arguments,
        [string]$Flag,
        [string]$Value
    )

    for ($i = 0; $i -lt ($Arguments.Count - 1); $i++) {
        if ($Arguments[$i] -eq $Flag -and $Arguments[$i + 1] -eq $Value) {
            return $true
        }
    }
    return $false
}

$results = @()

# 1. East US 2 -> primaryLocation=eastus2.
$eastArgs = Get-CentinelaDeploymentArguments -Operation 'what-if' -Location 'eastus2' `
    -TemplateFile $templateFile -ParametersFile $paramsFile
$eastPass = (Test-ArgumentContainsPair -Arguments $eastArgs -Flag '--location' -Value 'eastus2') -and `
    (Test-ArgumentContainsPair -Arguments $eastArgs -Flag '--parameters' -Value 'primaryLocation=eastus2')
$results += [pscustomobject]@{ Name = 'East US 2 -> primaryLocation=eastus2'; Pass = $eastPass }

# 2. Central US -> primaryLocation=centralus.
$centralArgs = Get-CentinelaDeploymentArguments -Operation 'what-if' -Location 'centralus' `
    -TemplateFile $templateFile -ParametersFile $paramsFile
$centralPass = (Test-ArgumentContainsPair -Arguments $centralArgs -Flag '--location' -Value 'centralus') -and `
    (Test-ArgumentContainsPair -Arguments $centralArgs -Flag '--parameters' -Value 'primaryLocation=centralus')
$results += [pscustomobject]@{ Name = 'Central US -> primaryLocation=centralus'; Pass = $centralPass }

# 3. Ninguna otra region es aceptada.
$rejectedRegion = $false
try {
    Get-CentinelaDeploymentArguments -Operation 'what-if' -Location 'westus' `
        -TemplateFile $templateFile -ParametersFile $paramsFile | Out-Null
}
catch {
    $rejectedRegion = $true
}
$results += [pscustomobject]@{ Name = 'Ninguna otra region es aceptada (westus)'; Pass = $rejectedRegion }

# 4. what-if siempre incluye --no-pretty-print.
$whatIfArgs = Get-CentinelaDeploymentArguments -Operation 'what-if' -Location 'eastus2' `
    -TemplateFile $templateFile -ParametersFile $paramsFile
$noPrettyPrintPass = $whatIfArgs -contains '--no-pretty-print'
$results += [pscustomobject]@{ Name = "what-if incluye --no-pretty-print"; Pass = $noPrettyPrintPass }

$allPassed = $true
foreach ($result in $results) {
    $status = if ($result.Pass) { 'PASS' } else { 'FAIL' }
    if (-not $result.Pass) { $allPassed = $false }
    Write-Host "[$status] $($result.Name)"
}

if ($allPassed) {
    Write-Host 'PASS: Get-CentinelaDeploymentArguments produce primaryLocation consistente con -Location para las dos regiones permitidas, y rechaza cualquier otra region.'
    exit 0
}
else {
    Write-Error 'FAIL: al menos un escenario de Get-CentinelaDeploymentArguments no se comporto como se esperaba.'
    exit 1
}
