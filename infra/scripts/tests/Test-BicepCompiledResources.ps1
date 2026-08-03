<#
.SYNOPSIS
Prueba reproducible: analisis estatico de la plantilla ARM compilada de main.bicep (Correccion
short-circuit, Fase 04) — confirma la causa raiz y la correccion del bloqueo "7 de 9 recursos"
documentado en el reporte de evidencia, sin ejecutar ningun despliegue ni what-if real.

.DESCRIPTION
Compila infra/main.bicep con `az bicep build --stdout` (unica llamada a Azure CLI de este archivo;
solo compila localmente, no autentica ni contacta ningun recurso de Azure) y recorre
recursivamente el arreglo "resources" de la plantilla resultante, incluyendo las plantillas
anidadas de cada modulo (`Microsoft.Resources/deployments` -> `properties.template.resources`),
para verificar:

  1. Existen exactamente 10 recursos fisicos (no-`Microsoft.Resources/deployments`) declarados en
     total across todos los modulos anidados.
  2. De esos 10, exactamente 9 no tienen una propiedad "condition" (es decir, se crean
     incondicionalmente) — el unico condicionado es la regla de firewall de Azure SQL
     (Microsoft.Sql/servers/firewallRules), deshabilitada por defecto
     (enableSqlAllowAzureServicesRule=false en dev.bicepparam). Estos 9 recursos incondicionales
     son exactamente el plan aprobado que Get-CentinelaWhatIfAnalysis exige.
  3. Microsoft.Web/serverfarms y Microsoft.Web/sites estan presentes entre los 9 recursos
     incondicionales (antes de esta correccion, un what-if real solo devolvia 7 de 9 porque el
     modulo appServiceDeployment completo — que contiene exactamente estos dos recursos — quedaba
     excluido del analisis).
  4. La cadena "APPLICATIONINSIGHTS_CONNECTION_STRING" no aparece en ningun lugar de la plantilla
     compilada: la conexion entre el backend y Application Insights queda diferida al despliegue
     posterior de la aplicacion (ver infra/CLAUDE.md y el reporte de evidencia de la Fase 04).
  5. El modulo appServiceDeployment no depende de monitoringDeployment (ni por "dependsOn" ni por
     recibir applicationInsightsConnectionString como parametro) — la causa raiz confirmada del
     short-circuit: un parametro derivado de un output de un modulo aun no desplegado impedia que
     el motor de what-if de Azure evaluara completamente el modulo dependiente.

.OUTPUTS
Codigo de salida 0 si todos los escenarios se comportaron como se esperaba.
Codigo de salida 1 si alguno fallo, o si `az bicep build` no pudo ejecutarse.
#>

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
$mainBicep = Join-Path $repoRoot 'infra/main.bicep'

$results = @()

function Add-CentinelaTestResult {
    param([string]$Name, [bool]$Pass, [string]$Detail = '')
    $script:results += [pscustomobject]@{ Name = $Name; Pass = $Pass; Detail = $Detail }
}

function Get-CentinelaPhysicalResources {
    param($Resources)

    $physical = New-Object System.Collections.Generic.List[object]
    foreach ($resource in @($Resources)) {
        if ($resource.type -eq 'Microsoft.Resources/deployments') {
            $nested = $resource.properties.template.resources
            if ($nested) {
                (Get-CentinelaPhysicalResources -Resources $nested) | ForEach-Object { $physical.Add($_) }
            }
        }
        else {
            $physical.Add($resource)
        }
    }
    return $physical
}

$compiledText = $null
$compileError = $null
try {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $compiledText = (& az bicep build --file $mainBicep --stdout 2>$null) -join [Environment]::NewLine
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $prevEap
    }
    if ($exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($compiledText)) {
        $compileError = "az bicep build --stdout fallo con codigo de salida $exitCode."
    }
}
catch {
    $compileError = "Excepcion al ejecutar az bicep build: $($_.Exception.Message)"
}

Add-CentinelaTestResult -Name 'az bicep build --stdout se ejecuta correctamente' -Pass ($null -eq $compileError) -Detail $compileError

if (-not $compileError) {
    $compiled = $compiledText | ConvertFrom-Json -ErrorAction Stop
    $physicalResources = Get-CentinelaPhysicalResources -Resources $compiled.resources

    # 1. Exactamente 10 recursos fisicos totales.
    Add-CentinelaTestResult -Name '10 recursos fisicos totales declarados (todas las plantillas anidadas)' `
        -Pass ($physicalResources.Count -eq 10) -Detail "Encontrados: $($physicalResources.Count)"

    # 2. Exactamente 9 sin condition (incondicionales).
    $unconditional = $physicalResources | Where-Object { -not ($_.PSObject.Properties.Name -contains 'condition') -or [string]::IsNullOrWhiteSpace([string]$_.condition) }
    Add-CentinelaTestResult -Name '9 recursos incondicionales (el plan aprobado exacto)' `
        -Pass ($unconditional.Count -eq 9) -Detail "Incondicionales: $($unconditional.Count) de $($physicalResources.Count)"

    $unconditionalTypes = $unconditional | ForEach-Object { [string]$_.type }

    # 3. Microsoft.Web/serverfarms y Microsoft.Web/sites presentes entre los incondicionales.
    Add-CentinelaTestResult -Name 'Microsoft.Web/serverfarms presente entre los recursos incondicionales' `
        -Pass ($unconditionalTypes -contains 'Microsoft.Web/serverfarms')
    Add-CentinelaTestResult -Name 'Microsoft.Web/sites presente entre los recursos incondicionales' `
        -Pass ($unconditionalTypes -contains 'Microsoft.Web/sites')

    # 4. APPLICATIONINSIGHTS_CONNECTION_STRING no aparece en ningun lugar de la plantilla compilada.
    Add-CentinelaTestResult -Name 'APPLICATIONINSIGHTS_CONNECTION_STRING no aparece en la plantilla compilada' `
        -Pass (-not $compiledText.Contains('APPLICATIONINSIGHTS_CONNECTION_STRING'))

    # 5. appServiceDeployment no depende de monitoringDeployment ni recibe
    # applicationInsightsConnectionString como parametro.
    $appServiceDeployment = $compiled.resources | Where-Object { $_.type -eq 'Microsoft.Resources/deployments' -and $_.name -eq 'appServiceDeployment' } | Select-Object -First 1
    if (-not $appServiceDeployment) {
        Add-CentinelaTestResult -Name 'El modulo appServiceDeployment existe en la plantilla compilada' -Pass $false
    }
    else {
        Add-CentinelaTestResult -Name 'El modulo appServiceDeployment existe en la plantilla compilada' -Pass $true

        $dependsOnText = ($appServiceDeployment.dependsOn | ForEach-Object { [string]$_ }) -join ' | '
        $dependsOnMonitoring = $dependsOnText -match 'monitoringDeployment'
        Add-CentinelaTestResult -Name 'appServiceDeployment no depende de monitoringDeployment (dependsOn)' `
            -Pass (-not $dependsOnMonitoring) -Detail $dependsOnText

        $paramNames = @()
        if ($appServiceDeployment.properties.parameters) {
            $paramNames = $appServiceDeployment.properties.parameters.PSObject.Properties.Name
        }
        Add-CentinelaTestResult -Name 'appServiceDeployment no recibe applicationInsightsConnectionString como parametro' `
            -Pass ($paramNames -notcontains 'applicationInsightsConnectionString') -Detail ($paramNames -join ', ')
    }
}

$allPassed = $true
foreach ($result in $results) {
    $status = if ($result.Pass) { 'PASS' } else { 'FAIL' }
    if (-not $result.Pass) { $allPassed = $false }
    Write-Host "[$status] $($result.Name)$(if ($result.Detail) { " -- $($result.Detail)" })"
}

if ($allPassed) {
    Write-Host 'PASS: la plantilla ARM compilada de main.bicep contiene exactamente los 9 recursos incondicionales aprobados (incluyendo Microsoft.Web/serverfarms y Microsoft.Web/sites), no expone APPLICATIONINSIGHTS_CONNECTION_STRING, y appServiceDeployment ya no depende de monitoringDeployment.'
    exit 0
}
else {
    Write-Error 'FAIL: al menos una verificacion estatica de la plantilla ARM compilada no se comporto como se esperaba.'
    exit 1
}
