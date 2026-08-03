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

. (Join-Path $PSScriptRoot 'lib/AzExec.ps1')

$infraDir = Resolve-Path (Join-Path $PSScriptRoot '..')
$mainTemplate = Join-Path $infraDir 'main.bicep'
$paramsFile = Join-Path $infraDir 'dev.bicepparam'

try {
    $sqlAdminLogin = Read-Host 'Usuario administrador temporal de Azure SQL (solo para what-if, no se guarda)'
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

            Invoke-AzCommand -StepName 'az deployment sub what-if (East US 2)' -Arguments @(
                'deployment', 'sub', 'what-if',
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

    Write-Host 'what-if completo. Ningun cambio fue aplicado: este comando solo previsualiza.'
}
catch {
    Write-Error "Fallo el what-if de Centinela (Fase 03): $($_.Exception.Message)"
    exit 1
}
