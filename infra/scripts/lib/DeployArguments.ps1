<#
.SYNOPSIS
Construccion pura de los argumentos de `az deployment sub validate|what-if|create` para
Centinela DEV, sin ejecutar ningun comando externo.

.DESCRIPTION
Antes de esta correccion, -Location solo controlaba la ubicacion del propio deployment de
suscripcion (`--location`), mientras que dev.bicepparam fijaba primaryLocation=eastus2 de forma
independiente: -Location centralus nunca desplegaba los recursos en Central US, porque el
parametro de Bicep que realmente posiciona cada recurso (`primaryLocation`, usado por los seis
modulos en infra/main.bicep) nunca recibia el valor de -Location.

Get-CentinelaDeploymentArguments corrige esto agregando siempre un argumento `--parameters`
adicional con `primaryLocation=$Location` DESPUES del archivo dev.bicepparam: la semantica de
merge de `az` aplica los `--parameters` en el orden recibido, por lo que este valor inline
sobrescribe el `primaryLocation = 'eastus2'` literal de dev.bicepparam. Con esto, la ubicacion del
deployment (`--location`) y la ubicacion real de los recursos (`primaryLocation`) quedan siempre
sincronizadas: 'eastus2' produce recursos en East US 2, 'centralus' produce recursos en Central
US. fallbackLocation permanece solo como documentacion en main.bicep/dev.bicepparam; esta funcion
nunca la usa ni conmuta automaticamente a ella.

Al ser pura (no ejecuta `az`, no depende de sesion de Azure), se puede probar exhaustivamente
sobre los argumentos generados (ver infra/scripts/tests/Test-DeployArguments.ps1).
#>

. (Join-Path $PSScriptRoot 'DeployGuard.ps1')

function Get-CentinelaDeploymentArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('validate', 'what-if', 'create')]
        [string]$Operation,

        [Parameter(Mandatory)]
        [string]$Location,

        [Parameter(Mandatory)]
        [string]$TemplateFile,

        [Parameter(Mandatory)]
        [string]$ParametersFile,

        [string]$DeploymentName
    )

    if ($script:CentinelaAllowedLocations -notcontains $Location) {
        throw "Bloqueado: la region '$Location' no esta en la lista permitida ($($script:CentinelaAllowedLocations -join ', ')). Ninguna otra region es aceptada."
    }

    $arguments = switch ($Operation) {
        'validate' { @('deployment', 'sub', 'validate') }
        'what-if' { @('deployment', 'sub', 'what-if') }
        'create' { @('deployment', 'sub', 'create') }
    }

    if ($Operation -eq 'create') {
        if ([string]::IsNullOrWhiteSpace($DeploymentName)) {
            throw 'Bloqueado: la operacion create requiere -DeploymentName.'
        }
        $arguments += @('--name', $DeploymentName)
    }

    $arguments += @(
        '--location', $Location,
        '--template-file', $TemplateFile,
        '--parameters', $ParametersFile,
        '--parameters', "primaryLocation=$Location",
        '--only-show-errors'
    )

    if ($Operation -eq 'what-if') {
        # ResourceIdOnly: el JSON resultante solo trae resourceId + changeType por cambio,
        # suficiente para el analisis de Correccion 3 y sin incluir propiedades completas de cada
        # recurso (menor superficie de datos a sanitizar).
        #
        # --no-pretty-print es obligatorio: `az deployment ... what-if` tiene un renderizador propio
        # que ignora --output/-o y siempre imprime un diff de texto coloreado a menos que se pase
        # este flag explicitamente (confirmado con `az deployment sub what-if --help` y de forma
        # empirica: sin el, Invoke-AzCommandCaptureJson recibe texto no-JSON y
        # Get-CentinelaWhatIfAnalysis bloquea con "La salida de what-if no es JSON valido", pese a
        # que `az` termina con codigo de salida 0).
        $arguments += @('--result-format', 'ResourceIdOnly', '--no-pretty-print')
    }

    # Salida JSON capturable (nunca impresa cruda; ver AzExec.ps1 / Correccion 4).
    $arguments += @('--output', 'json')

    return $arguments
}
