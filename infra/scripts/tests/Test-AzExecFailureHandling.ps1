<#
.SYNOPSIS
Prueba reproducible: demuestra que Invoke-AzCommand (infra/scripts/lib/AzExec.ps1) detecta un
código de salida distinto de cero de un ejecutable `az` simulado y aborta sin imprimir ningún
mensaje de éxito posterior.

.DESCRIPTION
Antes de la corrección de la Fase 03, validate.ps1/what-if.ps1 solo confiaban en
$ErrorActionPreference = 'Stop', que NO convierte el código de salida de un ejecutable nativo en
una excepción de PowerShell (ni en 5.1 ni en 7 sin $PSNativeCommandUseErrorActionPreference, que
tampoco existe en 5.1). Este script crea un `az.cmd` simulado que siempre retorna el código de
salida 1, lo antepone temporalmente al PATH, e invoca Invoke-AzCommand contra él. La prueba pasa
únicamente si Invoke-AzCommand lanza una excepción y el mensaje de éxito nunca se imprime.

.OUTPUTS
Código de salida 0 si la prueba pasó (el fallo simulado fue detectado correctamente).
Código de salida 1 si la prueba falló (el fallo simulado NO fue detectado: regresión).
#>

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../lib/AzExec.ps1')

$fakeAzDir = Join-Path ([System.IO.Path]::GetTempPath()) "centinela-fake-az-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $fakeAzDir -Force | Out-Null

$fakeAzPath = Join-Path $fakeAzDir 'az.cmd'
Set-Content -Path $fakeAzPath -Value @'
@echo off
echo ERROR: fallo simulado de az para prueba de manejo de codigo de salida 1>&2
exit /b 1
'@ -Encoding ASCII

$originalPath = $env:Path
$testPassed = $false
$successMessagePrinted = $false

try {
    $env:Path = "$fakeAzDir;$originalPath"

    $output = & {
        try {
            Invoke-AzCommand -StepName 'az simulado (debe fallar)' -Arguments @('bicep', 'version')
            'NO-EXCEPTION-THROWN: mensaje de exito habria seguido a esta linea'
        }
        catch {
            "EXCEPTION-THROWN: $($_.Exception.Message)"
        }
    }

    Write-Host $output

    $testPassed = $output -like 'EXCEPTION-THROWN:*'
    $successMessagePrinted = $output -like 'NO-EXCEPTION-THROWN:*'
}
finally {
    $env:Path = $originalPath
    Remove-Item -Path $fakeAzDir -Recurse -Force -ErrorAction SilentlyContinue
}

if ($testPassed -and -not $successMessagePrinted) {
    Write-Host 'PASS: Invoke-AzCommand detecto el codigo de salida 1 del az simulado y aborto sin imprimir un mensaje de exito.'
    exit 0
}
else {
    Write-Error 'FAIL: Invoke-AzCommand no detecto el fallo simulado (regresion en el manejo de $LASTEXITCODE).'
    exit 1
}
