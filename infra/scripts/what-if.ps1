<#
.SYNOPSIS
Ejecuta `az deployment sub what-if` sobre las plantillas Bicep de Centinela (Fase 03) para mostrar
los cambios que se propondrían, sin aplicar ninguno.

Este script SOLO ejecuta az deployment sub what-if (modo de solo lectura/preview de Azure CLI).
NUNCA ejecuta az deployment sub create, az deployment group create, az group create,
az resource create/update/delete, ni encadena `what-if` con `--confirm-with-what-if` para aplicar
cambios automáticamente. Si necesitas agregar un paso nuevo a este script, no agregues ninguno de
los comandos anteriores sin una autorización humana explícita separada.
#>

$ErrorActionPreference = 'Stop'

$infraDir = Resolve-Path (Join-Path $PSScriptRoot '..')
$mainTemplate = Join-Path $infraDir 'main.bicep'
$paramsFile = Join-Path $infraDir 'dev.bicepparam'

$sqlAdminLogin = Read-Host 'Usuario administrador temporal de Azure SQL (solo para what-if, no se guarda)'
$sqlPasswordSecure = Read-Host -AsSecureString 'Contraseña temporal de administrador de Azure SQL (solo en memoria, no se guarda)'
$sqlPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlPasswordSecure)
)

try {
    # dev.bicepparam lee estas dos variables vía readEnvironmentVariable(); nunca se pasan como
    # argumento de línea de comandos ni quedan escritas en disco.
    $env:CENTINELA_SQL_ADMIN_LOGIN = $sqlAdminLogin
    $env:CENTINELA_SQL_ADMIN_PASSWORD = $sqlPasswordPlain

    Write-Host '== az deployment sub what-if (East US 2) =='
    az deployment sub what-if `
        --location eastus2 `
        --template-file $mainTemplate `
        --parameters $paramsFile `
        --only-show-errors
}
finally {
    $sqlPasswordPlain = $null
    $sqlAdminLogin = $null
    Remove-Item Env:\CENTINELA_SQL_ADMIN_LOGIN -ErrorAction SilentlyContinue
    Remove-Item Env:\CENTINELA_SQL_ADMIN_PASSWORD -ErrorAction SilentlyContinue
    [System.GC]::Collect()
}

Write-Host 'what-if completo. Ningún cambio fue aplicado: este comando solo previsualiza.'
