<#
.SYNOPSIS
Funciones compartidas para invocar `az` verificando siempre el código de salida real del proceso.

Ni $ErrorActionPreference = 'Stop' ni (donde exista) $PSNativeCommandUseErrorActionPreference
convierten por sí solos un código de salida distinto de cero de un ejecutable nativo en una
excepción de PowerShell en Windows PowerShell 5.1 — y $PSNativeCommandUseErrorActionPreference no
existe siquiera en 5.1, solo desde PowerShell 7.3. Por eso estas funciones revisan $LASTEXITCODE
explícitamente después de cada invocación de `az` y abortan con una excepción propia si el comando
falló, funcionando igual en PowerShell 5.1 y 7.

Ningún mensaje de excepción de este archivo incluye la lista completa de argumentos: algunos
argumentos son rutas locales absolutas (plantillas Bicep, archivos de parámetros), y CLAUDE.md
(sección 9) prohíbe exponer rutas locales completas del equipo de desarrollo en cualquier salida.
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
        throw "El paso '$StepName' (az) fallo con codigo de salida $exitCode."
    }
}

<#
.SYNOPSIS
Invoca `az` capturando su salida estandar en memoria (nunca en disco, nunca impresa cruda) para
que el llamador pueda analizarla y decidir que resumen sanitizado mostrar (Correccion 4, Fase 04).

.DESCRIPTION
A diferencia de Invoke-AzCommand (que transmite la salida de `az` directamente a la consola,
adecuado para pasos de diagnostico como `bicep build`/`lint` que no contienen identificadores),
Invoke-AzCommandCaptureJson se usa para validate/what-if/create: pasos cuya salida JSON puede
incluir Subscription ID, Tenant ID u Object ID dentro de cada resourceId. stderr se descarta (no
se redirige a la salida capturada ni se imprime) para que un fallo de `az` nunca vuelque texto de
diagnostico sin sanitizar a la consola; en su lugar, esta funcion lanza una excepcion generica con
unicamente el nombre del paso y el codigo de salida.

El valor devuelto es la salida estandar completa (texto JSON) como una sola cadena, mantenida
solo en memoria: esta funcion nunca escribe un archivo temporal, por lo que no hay nada que
limpiar en un bloque finally.
#>
function Invoke-AzCommandCaptureJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StepName,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    Write-Host "== $StepName (salida capturada en memoria; no se imprime cruda) =="
    $rawLines = & az @Arguments 2>$null
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "El paso '$StepName' (az) fallo con codigo de salida $exitCode."
    }

    return ($rawLines -join [Environment]::NewLine)
}
