<#
.SYNOPSIS
Valida las plantillas Bicep de Centinela (Fase 03) sin desplegar ningún recurso.

Este script SOLO ejecuta: az bicep version, az bicep build, az bicep lint y
az deployment sub validate. NUNCA ejecuta az deployment sub create, az deployment group create,
az group create, az resource create/update/delete, az provider register, ni ningún comando con
--confirm-with-what-if para aplicar cambios. Si necesitas agregar un paso nuevo a este script,
no agregues ninguno de los comandos anteriores sin una autorización humana explícita separada.
#>

$ErrorActionPreference = 'Stop'

$infraDir = Resolve-Path (Join-Path $PSScriptRoot '..')
$mainTemplate = Join-Path $infraDir 'main.bicep'
$paramsFile = Join-Path $infraDir 'dev.bicepparam'

Write-Host '== az bicep version =='
az bicep version

Write-Host '== az bicep build (main.bicep) =='
az bicep build --file $mainTemplate

Write-Host '== az bicep lint (main.bicep) =='
az bicep lint --file $mainTemplate

$sqlAdminLogin = Read-Host 'Usuario administrador temporal de Azure SQL (solo para validate, no se guarda)'
$sqlPasswordSecure = Read-Host -AsSecureString 'Contraseña temporal de administrador de Azure SQL (solo en memoria, no se guarda)'
$sqlPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlPasswordSecure)
)

try {
    # dev.bicepparam lee estas dos variables vía readEnvironmentVariable(); nunca se pasan como
    # argumento de línea de comandos ni quedan escritas en disco.
    $env:CENTINELA_SQL_ADMIN_LOGIN = $sqlAdminLogin
    $env:CENTINELA_SQL_ADMIN_PASSWORD = $sqlPasswordPlain

    Write-Host '== az deployment sub validate (East US 2) =='
    az deployment sub validate `
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

Write-Host 'Validación completa. No se creó, modificó ni eliminó ningún recurso de Azure.'
