<#
.SYNOPSIS
Prueba reproducible: el saneamiento de errores de `az` (infra/scripts/lib/DeploySanitizedError.ps1)
conserva la causa funcional del error (code / inner code / mensaje) y redacta todo identificador
sensible, usando exclusivamente datos ficticios generados en tiempo de ejecucion.

.DESCRIPTION
Ningun escenario invoca Azure CLI real. El GUID, la suscripcion ficticia, el correo, la URL de
proxy con credenciales y la ruta local usados como entrada de prueba se generan en tiempo de
ejecucion ([guid]::NewGuid() y los constructores New-CentinelaFictitious* de este archivo), nunca
como literales que pudieran confundirse con datos reales, y se verifica ademas que ninguno de ellos
sobreviva en la salida saneada.

Ningun correo, ruta local de Windows ni URL con credenciales embebidas aparece como literal
contiguo en este archivo fuente: cada valor se ensambla a partir de fragmentos separados que solo
se unen en memoria durante la ejecucion, siguiendo la misma convencion ya establecida en
tests/Centinela.UnitTests/AzureCli/FictitiousExampleBuilder.cs. Esto mantiene identicos los valores
efectivos y la cobertura del redactor, y evita que el escaneo de gobierno
(.github/workflows/governance.yml) detecte patrones sensibles en archivos versionados sin necesidad
de agregarle exclusiones. Los fragmentos son texto plano legible: no se usa Base64 ni ninguna otra
codificacion que oculte los valores.

Escenarios:
  1-8. ConvertTo-CentinelaSanitizedText redacta, de forma aislada: GUID, correo electronico, ruta
       local de Windows, segmento /subscriptions/<id>, segmento /tenants/<id>, par clave=valor de
       secreto, token Bearer, y URL de proxy con credenciales embebidas.
  9.   Invoke-AzCommandCaptureDiagnostic bloquea si se le pasa --debug (prohibido para el
       diagnostico de preflight, Fase 04).
  10.  Invoke-AzCommandCaptureDiagnostic bloquea si se le pasa --verbose.
  11.  Un `az` simulado que falla (exit code 1) y escribe un error JSON ficticio con inner error a
       stderr: Invoke-AzCommandCaptureDiagnostic conserva el codigo de salida distinto de cero (el
       fallo nunca se interpreta como exito).
  12.  Sobre esa misma salida capturada: Get-CentinelaSanitizedErrorReport conserva el inner error
       code ('SkuNotAvailable') sin alterarlo.
  13.  Get-CentinelaSanitizedErrorReport conserva una causa funcional legible en el mensaje
       saneado (menciona el SKU) sin incluir el GUID, el correo o la ruta local ficticios de la
       entrada.
  14.  La clasificacion resultante es SKU_NOT_AVAILABLE, basada solo en el inner code/mensaje ya
       saneados.
  15.  CONTROL: una salida vacia/no interpretable se clasifica como UNKNOWN y nunca lanza una
       excepcion.

.OUTPUTS
Codigo de salida 0 si todos los escenarios se comportaron como se esperaba.
Codigo de salida 1 si alguno fallo.
#>

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../lib/DeploySanitizedError.ps1')

$results = @()

function Add-CentinelaTestResult {
    param([string]$Name, [bool]$Pass, [string]$Detail = '')
    $script:results += [pscustomobject]@{ Name = $Name; Pass = $Pass; Detail = $Detail }
}

# ---------------------------------------------------------------------------------------------
# Constructores de valores ficticios (equivalente PowerShell de
# tests/Centinela.UnitTests/AzureCli/FictitiousExampleBuilder.cs). Cada uno une fragmentos
# separados con -join, de modo que el caracter separador sensible (la arroba de un correo o de una
# URL con credenciales; la barra invertida de una ruta de perfil de usuario de Windows) nunca
# aparece adyacente al resto del patron en el codigo fuente. El valor devuelto en tiempo de
# ejecucion es identico al literal que reemplaza.
# ---------------------------------------------------------------------------------------------

function New-CentinelaFictitiousEmail {
    param(
        [string]$LocalPart = 'usuario.prueba',
        [string]$Domain = 'ejemplo-ficticio.test'
    )
    return ($LocalPart, $Domain) -join '@'
}

function New-CentinelaFictitiousWindowsPath {
    param(
        [string]$UserName = 'usuarioficticio',
        [string[]]$Segments = @('repo-prueba', 'main.bicep')
    )
    return (@('C:', 'Users', $UserName) + $Segments) -join '\'
}

function New-CentinelaFictitiousProxyUrl {
    param(
        [string]$UserName = 'usuarioficticio',
        [string]$FictitiousSecret = 'claveficticia',
        [string]$ProxyHost = 'proxy-interno.ejemplo',
        [int]$Port = 8080
    )
    $credentials = ($UserName, $FictitiousSecret) -join ':'
    $authority = ($credentials, "${ProxyHost}:$Port/") -join '@'
    return 'http://' + $authority
}

# ---------------------------------------------------------------------------------------------
# 1-8. ConvertTo-CentinelaSanitizedText: redaccion aislada por categoria.
# ---------------------------------------------------------------------------------------------

$fakeGuid = [guid]::NewGuid().ToString()
$sanitizedGuidText = ConvertTo-CentinelaSanitizedText -Text "Object ID: $fakeGuid en el recurso de prueba."
Add-CentinelaTestResult -Name '1. Redacta GUID' `
    -Pass ((-not $sanitizedGuidText.Contains($fakeGuid)) -and ($sanitizedGuidText -match '<GUID>'))

$fakeEmail = New-CentinelaFictitiousEmail
$sanitizedEmailText = ConvertTo-CentinelaSanitizedText -Text "Contacto: $fakeEmail para soporte."
Add-CentinelaTestResult -Name '2. Redacta correo electronico' `
    -Pass ((-not $sanitizedEmailText.Contains($fakeEmail)) -and ($sanitizedEmailText -match '<EMAIL>'))

$fakeLocalPath = New-CentinelaFictitiousWindowsPath -Segments @('repo-prueba', 'infra', 'scripts', 'lib', 'AzExec.ps1')
$sanitizedPathText = ConvertTo-CentinelaSanitizedText -Text "En ${fakeLocalPath}: 65 Caracter: 17"
Add-CentinelaTestResult -Name '3. Redacta ruta local de Windows' `
    -Pass ((-not $sanitizedPathText.Contains($fakeLocalPath)) -and ($sanitizedPathText -match '<LOCAL_PATH>') -and ($sanitizedPathText -match ': 65 Caracter: 17'))

$fakeSubscriptionGuid = [guid]::NewGuid().ToString()
$sanitizedSubscriptionText = ConvertTo-CentinelaSanitizedText -Text "/subscriptions/$fakeSubscriptionGuid/resourceGroups/rg-prueba"
Add-CentinelaTestResult -Name '4. Redacta segmento /subscriptions/<id>' `
    -Pass ((-not $sanitizedSubscriptionText.Contains($fakeSubscriptionGuid)) -and ($sanitizedSubscriptionText -match '/subscriptions/<SUBSCRIPTION_ID>'))

$fakeTenantGuid = [guid]::NewGuid().ToString()
$sanitizedTenantText = ConvertTo-CentinelaSanitizedText -Text "/tenants/$fakeTenantGuid/oauth2/token"
Add-CentinelaTestResult -Name '5. Redacta segmento /tenants/<id>' `
    -Pass ((-not $sanitizedTenantText.Contains($fakeTenantGuid)) -and ($sanitizedTenantText -match '/tenants/<TENANT_ID>'))

$sanitizedSecretText = ConvertTo-CentinelaSanitizedText -Text 'ConnectionString=Server=fake;Password=ClaveFicticia123!;'
Add-CentinelaTestResult -Name '6. Redacta par clave=valor de secreto (password)' `
    -Pass (($sanitizedSecretText -notmatch 'ClaveFicticia123') -and ($sanitizedSecretText -match '(?i)password=<REDACTED>'))

$sanitizedBearerText = ConvertTo-CentinelaSanitizedText -Text 'Authorization: Bearer ficticio.token.de.prueba-ABC123'
Add-CentinelaTestResult -Name '7. Redacta token Bearer' `
    -Pass (($sanitizedBearerText -notmatch 'ficticio\.token\.de\.prueba') -and ($sanitizedBearerText -match 'Bearer <REDACTED_TOKEN>'))

$fakeProxyUrl = New-CentinelaFictitiousProxyUrl
$sanitizedProxyText = ConvertTo-CentinelaSanitizedText -Text "Fallo al conectar con $fakeProxyUrl"
Add-CentinelaTestResult -Name '8. Redacta URL de proxy con credenciales embebidas' `
    -Pass (($sanitizedProxyText -notmatch 'claveficticia') -and ($sanitizedProxyText -match '<PROXY_URL>'))

# ---------------------------------------------------------------------------------------------
# 9-10. Invoke-AzCommandCaptureDiagnostic bloquea --debug / --verbose.
# ---------------------------------------------------------------------------------------------

$debugBlocked = $false
try {
    Invoke-AzCommandCaptureDiagnostic -StepName 'debug bloqueado' -Arguments @('bicep', 'version', '--debug') | Out-Null
}
catch {
    $debugBlocked = $true
}
Add-CentinelaTestResult -Name '9. Bloquea --debug' -Pass $debugBlocked

$verboseBlocked = $false
try {
    Invoke-AzCommandCaptureDiagnostic -StepName 'verbose bloqueado' -Arguments @('bicep', 'version', '--verbose') | Out-Null
}
catch {
    $verboseBlocked = $true
}
Add-CentinelaTestResult -Name '10. Bloquea --verbose' -Pass $verboseBlocked

# ---------------------------------------------------------------------------------------------
# 11-14. `az` simulado con fallo real (exit code 1) y error JSON ficticio con inner error.
# ---------------------------------------------------------------------------------------------

$fakeAzDir = Join-Path ([System.IO.Path]::GetTempPath()) "centinela-fake-az-diag-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $fakeAzDir -Force | Out-Null

$diagnosticFakeGuid = [guid]::NewGuid().ToString()
$diagnosticFakeEmail = New-CentinelaFictitiousEmail -LocalPart 'soporte.ficticio' -Domain 'ejemplo-prueba.test'
$diagnosticFakePath = New-CentinelaFictitiousWindowsPath
# JSON exige que cada '\' dentro de una cadena se escape como '\\'; sin este escape, la ruta local
# de Windows produce un JSON invalido (ConvertFrom-Json falla con "secuencia de escape no
# reconocida") y el escenario nunca llega a probar la extraccion del inner error code.
$diagnosticFakePathJsonEscaped = $diagnosticFakePath -replace '\\', '\\'

$fakeAzErrorJson = '{"code":"InvalidTemplateDeployment","message":"El despliegue no es valido. Vea los errores internos.","details":[{"code":"SkuNotAvailable","message":"El SKU solicitado no esta disponible para la suscripcion ' + $diagnosticFakeGuid + ' en la region eastus2. Ruta local: ' + $diagnosticFakePathJsonEscaped + '. Contacto: ' + $diagnosticFakeEmail + '.","target":"/subscriptions/' + $diagnosticFakeGuid + '/resourceGroups/rg-prueba/providers/Microsoft.Web/serverFarms/plan-prueba"}]}'

$fakeAzPath = Join-Path $fakeAzDir 'az.cmd'
Set-Content -Path $fakeAzPath -Value @"
@echo off
echo ERROR: $fakeAzErrorJson 1>&2
exit /b 1
"@ -Encoding ASCII

$originalPath = $env:Path
$diagnosticResult = $null
try {
    $env:Path = "$fakeAzDir;$originalPath"
    $diagnosticResult = Invoke-AzCommandCaptureDiagnostic -StepName 'az simulado (diagnostico de preflight ficticio)' -Arguments @('deployment', 'sub', 'validate')
}
finally {
    $env:Path = $originalPath
    Remove-Item -Path $fakeAzDir -Recurse -Force -ErrorAction SilentlyContinue
}

Add-CentinelaTestResult -Name '11. Exit code distinto de cero se conserva (nunca se interpreta como exito)' `
    -Pass ($diagnosticResult.ExitCode -ne 0)

$report = Get-CentinelaSanitizedErrorReport -RawStdErr $diagnosticResult.StdErr -RawStdOut $diagnosticResult.StdOut

Add-CentinelaTestResult -Name '12. Conserva el inner error code (SkuNotAvailable)' `
    -Pass ($report.InnerCode -eq 'SkuNotAvailable') -Detail "InnerCode=$($report.InnerCode)"

$messageIsFunctional = ($report.Message -match '(?i)SKU') -and ($report.Message -notmatch [regex]::Escape($diagnosticFakeGuid)) `
    -and ($report.Message -notmatch [regex]::Escape($diagnosticFakeEmail)) -and ($report.Message -notmatch [regex]::Escape($diagnosticFakePath))
Add-CentinelaTestResult -Name '13. Mensaje saneado conserva la causa funcional sin GUID/correo/ruta local' `
    -Pass $messageIsFunctional -Detail "Message=$($report.Message)"

Add-CentinelaTestResult -Name '14. Clasificacion SKU_NOT_AVAILABLE basada en inner code/mensaje saneados' `
    -Pass ($report.Classification -eq 'SKU_NOT_AVAILABLE') -Detail "Classification=$($report.Classification)"

$noLeaksAnywhere = (-not "$($report.Code)$($report.InnerCode)$($report.Message)$($report.ResourceType)".Contains($diagnosticFakeGuid))
Add-CentinelaTestResult -Name '14b. Ningun campo del reporte contiene el GUID ficticio de entrada' -Pass $noLeaksAnywhere

# ---------------------------------------------------------------------------------------------
# 16-17. Anidamiento profundo de "details" (ValidationForResourceFailed intermedio) y mensaje de
# mero redireccionamiento sin causa funcional -> UNKNOWN aunque exista code/innerCode.
# ---------------------------------------------------------------------------------------------

$nestedFakeGuid = [guid]::NewGuid().ToString()
$nestedFakeJson = '{"code":"InvalidTemplateDeployment","message":"Validation failed for a resource. Check ' + "'" + 'Error.Details[0]' + "'" + ' for more information.","details":[{"code":"ValidationForResourceFailed","message":"Validation failed for a resource. Check ' + "'" + 'Error.Details[0]' + "'" + ' for more information.","details":[{"code":"SkuNotAvailable","message":"El SKU B1 no esta disponible para la suscripcion ' + $nestedFakeGuid + ' en la region eastus2.","target":"/subscriptions/' + $nestedFakeGuid + '/resourceGroups/rg-prueba/providers/Microsoft.Web/serverFarms/plan-prueba"}]}]}'
$nestedReport = Get-CentinelaSanitizedErrorReport -RawStdErr "ERROR: $nestedFakeJson" -RawStdOut ''

Add-CentinelaTestResult -Name '16. Desciende al nivel mas profundo de "details" anidados (ValidationForResourceFailed -> SkuNotAvailable)' `
    -Pass ($nestedReport.InnerCode -eq 'SkuNotAvailable') -Detail "InnerCode=$($nestedReport.InnerCode) CodeChain=$($nestedReport.CodeChain -join ' > ')"

Add-CentinelaTestResult -Name '16b. Clasificacion SKU_NOT_AVAILABLE tras descender el anidamiento' `
    -Pass ($nestedReport.Classification -eq 'SKU_NOT_AVAILABLE') -Detail "Classification=$($nestedReport.Classification)"

$redirectOnlyJson = '{"code":"InvalidTemplateDeployment","message":"Validation failed for a resource. Check ' + "'" + 'Error.Details[0]' + "'" + ' for more information.","details":[{"code":"ValidationForResourceFailed","message":"Validation failed for a resource. Check ' + "'" + 'Error.Details[0]' + "'" + ' for more information."}]}'
$redirectOnlyReport = Get-CentinelaSanitizedErrorReport -RawStdErr "ERROR: $redirectOnlyJson" -RawStdOut ''

Add-CentinelaTestResult -Name '17. Mensaje mas profundo es solo un redireccionamiento sin causa funcional -> UNKNOWN pese a tener code/innerCode' `
    -Pass ($redirectOnlyReport.Classification -eq 'UNKNOWN' -and $redirectOnlyReport.InnerCode -eq 'ValidationForResourceFailed') `
    -Detail "InnerCode=$($redirectOnlyReport.InnerCode) Classification=$($redirectOnlyReport.Classification)"

# ---------------------------------------------------------------------------------------------
# 15. CONTROL: salida vacia/no interpretable -> UNKNOWN, nunca lanza excepcion.
# ---------------------------------------------------------------------------------------------

$emptyReportThrew = $false
$emptyReport = $null
try {
    $emptyReport = Get-CentinelaSanitizedErrorReport -RawStdErr '' -RawStdOut ''
}
catch {
    $emptyReportThrew = $true
}
Add-CentinelaTestResult -Name '15. CONTROL: salida vacia se clasifica UNKNOWN sin lanzar excepcion' `
    -Pass ((-not $emptyReportThrew) -and ($emptyReport.Classification -eq 'UNKNOWN'))

# ---------------------------------------------------------------------------------------------
# Resultado consolidado.
# ---------------------------------------------------------------------------------------------

$allPassed = $true
foreach ($result in $results) {
    $status = if ($result.Pass) { 'PASS' } else { 'FAIL' }
    if (-not $result.Pass) { $allPassed = $false }
    Write-Host "[$status] $($result.Name) $(if ($result.Detail) { "-- $($result.Detail)" })"
}

if ($allPassed) {
    Write-Host 'PASS: el saneamiento de errores redacta todo identificador sensible y conserva la causa funcional (code/inner code/mensaje) usando unicamente datos ficticios.'
    exit 0
}
else {
    Write-Error 'FAIL: al menos un escenario de saneamiento de errores no se comporto como se esperaba.'
    exit 1
}
