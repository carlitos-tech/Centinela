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

. (Join-Path $PSScriptRoot 'lib/AzExec.ps1')

$infraDir = Resolve-Path (Join-Path $PSScriptRoot '..')
$mainTemplate = Join-Path $infraDir 'main.bicep'
$paramsFile = Join-Path $infraDir 'dev.bicepparam'

try {
    Invoke-AzCommand -StepName 'az bicep version' -Arguments @('bicep', 'version')
    Invoke-AzCommand -StepName 'az bicep build (main.bicep)' -Arguments @('bicep', 'build', '--file', $mainTemplate)
    Invoke-AzCommand -StepName 'az bicep lint (main.bicep)' -Arguments @('bicep', 'lint', '--file', $mainTemplate)

    $sqlAdminLogin = Read-Host 'Usuario administrador temporal de Azure SQL (solo para validate, no se guarda)'
    $sqlPasswordSecure = Read-Host -AsSecureString 'Contraseña temporal de administrador de Azure SQL (solo en memoria, no se guarda)'

    # Se conserva el puntero BSTR para poder liberarlo explícitamente con ZeroFreeBSTR en el
    # finally más interno: GC.Collect() no libera memoria no administrada y no es un sustituto
    # válido de esa liberación explícita.
    $sqlPasswordBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlPasswordSecure)

    try {
        $sqlPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($sqlPasswordBstr)

        try {
            # dev.bicepparam lee estas dos variables vía readEnvironmentVariable(); nunca se pasan
            # como argumento de línea de comandos ni quedan escritas en disco.
            $env:CENTINELA_SQL_ADMIN_LOGIN = $sqlAdminLogin
            $env:CENTINELA_SQL_ADMIN_PASSWORD = $sqlPasswordPlain

            Invoke-AzCommand -StepName 'az deployment sub validate (East US 2)' -Arguments @(
                'deployment', 'sub', 'validate',
                '--location', 'eastus2',
                '--template-file', $mainTemplate,
                '--parameters', $paramsFile,
                '--only-show-errors'
            )
        }
        finally {
            $sqlPasswordPlain = $null
            $sqlAdminLogin = $null
            Remove-Item Env:\CENTINELA_SQL_ADMIN_LOGIN -ErrorAction SilentlyContinue
            Remove-Item Env:\CENTINELA_SQL_ADMIN_PASSWORD -ErrorAction SilentlyContinue
        }
    }
    finally {
        if ($sqlPasswordBstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($sqlPasswordBstr)
        }
    }

    Write-Host 'Validación completa. No se creó, modificó ni eliminó ningún recurso de Azure.'
}
catch {
    Write-Error "Fallo la validacion de Centinela (Fase 03): $($_.Exception.Message)"
    exit 1
}
