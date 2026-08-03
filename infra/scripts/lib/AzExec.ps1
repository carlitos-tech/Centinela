<#
.SYNOPSIS
Función compartida por validate.ps1 y what-if.ps1 para invocar `az` verificando siempre el
código de salida real del proceso.

Ni $ErrorActionPreference = 'Stop' ni (donde exista) $PSNativeCommandUseErrorActionPreference
convierten por sí solos un código de salida distinto de cero de un ejecutable nativo en una
excepción de PowerShell en Windows PowerShell 5.1 — y $PSNativeCommandUseErrorActionPreference no
existe siquiera en 5.1, solo desde PowerShell 7.3. Por eso esta función revisa $LASTEXITCODE
explícitamente después de cada invocación de `az` y aborta con una excepción propia si el comando
falló, funcionando igual en PowerShell 5.1 y 7.
#>

function Invoke-AzCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StepName,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    Write-Host "== $StepName =="
    & az @Arguments
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "El comando 'az $($Arguments -join ' ')' del paso '$StepName' fallo con codigo de salida $exitCode."
    }
}
