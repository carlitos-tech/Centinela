<#
.SYNOPSIS
Captura en memoria y saneamiento de errores de `az` para diagnostico (Correccion diagnostico
preflight, Fase 04), sin usar --debug/--verbose y sin persistir salida cruda en disco.

.DESCRIPTION
Invoke-AzCommandCaptureDiagnostic ejecuta `az` redirigiendo stderr junto a stdout (`2>&1`) para
separarlos en memoria segun el tipo de objeto que devuelve PowerShell (ErrorRecord para stderr),
sin escribir ningun archivo temporal y sin imprimir ninguna de las dos salidas: el llamador
siempre debe pasar el resultado por Get-CentinelaSanitizedErrorReport / ConvertTo-CentinelaSanitizedText
antes de mostrar nada. $ErrorActionPreference se fuerza a 'Continue' unicamente durante la
invocacion nativa (Windows PowerShell 5.1 convierte cada linea de stderr en un ErrorRecord no
terminante; con 'Stop' la primera linea de stderr abortaria el script antes de poder capturar el
resto) y se restaura siempre en un bloque finally. $LASTEXITCODE se verifica explicitamente
despues de cada invocacion, igual que en AzExec.ps1.

ConvertTo-CentinelaSanitizedText redacta, en este orden (el orden importa: los patrones mas
especificos deben aplicarse antes de que un patron generico como el de GUID, correo o clave=valor
consuma parte de su texto):
  1. Tokens Bearer (antes que el patron generico de clave=valor: evita que la palabra clave
     "Authorization" consuma la palabra literal "Bearer" como si fuera el valor del secreto).
  2. Pares clave=valor de secretos conocidos (password, connection string, etc.).
  3. URLs de proxy (con credenciales embebidas o cuyo host contenga la palabra "proxy"; antes que
     la redaccion de correos, para que un patron de correo generico no consuma el "@" y el host de
     una URL completa).
  4. Segmentos /subscriptions/<id> y /tenants/<id>.
  5. Cualquier otro GUID (Object ID, correlation ID, tracking ID, etc.).
  6. Correos electronicos.
  7. Rutas locales de Windows (unidad:\...) y rutas UNC (\\servidor\recurso\...).
  8. Nombres de usuario locales con formato DOMINIO\usuario.

Get-CentinelaSanitizedErrorReport interpreta el texto crudo (stderr, o stdout si stderr esta
vacio) del error de `az`, intenta un parseo JSON tras recortar el prefijo `ERROR: ` que antepone
Azure CLI, y extrae: code, un inner code/message tomado de la hoja MAS PROFUNDA de un arreglo
"details" (o "error.details") anidado -- ARM suele envolver el error real en varios niveles, p.ej.
un "ValidationForResourceFailed" intermedio cuyo unico mensaje es "Check Error.Details[0] for more
information", con la causa funcional real un nivel mas abajo -- resourceType (a partir de
"target", nunca el resourceId completo), region y SKU detectados en el mensaje YA saneado, y
CodeChain (la cadena de codes recorridos desde el nivel superior hasta la hoja, saneada, para
poder mostrar el arbol de error sin exponer nunca IDs). Si el mensaje mas profundo obtenido sigue
siendo un mero redireccionamiento ("Check ... Details ... for more information") sin describir la
causa funcional, se trata como evidencia insuficiente y la clasificacion cae a UNKNOWN en vez de
forzar una causa no sustentada por el mensaje. Nunca conserva ni devuelve tracking ID, correlation
ID, request ID, headers HTTP ni el cuerpo crudo de la respuesta.

Get-CentinelaAzureErrorClassification clasifica la causa unicamente a partir de codigos/mensajes
ya saneados, en un orden deliberado: las causas especificas (cuota, SKU, region, restriccion de
suscripcion, politica, autorizacion) se evaluan antes que el comodin generico de plantilla/API
version, porque el codigo de nivel superior mas comun de Azure Resource Manager
("InvalidTemplateDeployment") aparece para casi cualquier fallo de preflight sin importar la causa
real, y evaluarlo primero enmascararia la causa especifica reportada en el inner error.
#>

. (Join-Path $PSScriptRoot 'AzExec.ps1')

function ConvertTo-CentinelaSanitizedText {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Text
    )

    if ([string]::IsNullOrEmpty($Text)) { return $Text }

    $sanitized = $Text

    # 1. Tokens Bearer (antes que el patron generico de clave=valor: un encabezado
    # "Authorization: Bearer <token>" no debe dejar que la palabra clave "Authorization" del patron
    # generico consuma la palabra literal "Bearer" como si fuera el valor del secreto).
    $sanitized = [regex]::Replace($sanitized, '(?i)Bearer\s+[A-Za-z0-9\-_\.=]+', 'Bearer <REDACTED_TOKEN>')

    # 2. Pares clave=valor de secretos conocidos. "authorization" se excluye deliberadamente: el
    # caso de uso real (encabezado "Authorization: Bearer ...") ya lo cubre la regla 1, y
    # mezclarlo aqui volveria a capturar la palabra "Bearer" como si fuera el valor del secreto.
    $sanitized = [regex]::Replace(
        $sanitized,
        '(?i)\b(password|pwd|secret|apikey|api[_-]?key|accountkey|access[_-]?key|client[_-]?secret|sharedaccesssignature|connectionstring)\s*[:=]\s*[^;,\s"'']+',
        '$1=<REDACTED>'
    )

    # 3. URLs de proxy: con credenciales embebidas, o cuyo host contenga la palabra "proxy" (antes
    # que la redaccion de correos: un patron de correo generico puede coincidir con el segmento
    # "usuario@host-con-proxy" de una URL y consumir el "@" y la palabra "proxy" antes de que estas
    # reglas tengan oportunidad de reconocer la URL completa).
    $sanitized = [regex]::Replace($sanitized, '(?i)https?://[^\s"'']*@[^\s"'']+', '<PROXY_URL>')
    $sanitized = [regex]::Replace($sanitized, '(?i)https?://[^\s"'']*proxy[^\s"'']*', '<PROXY_URL>')

    # 4. Segmentos /subscriptions/<id> y /tenants/<id>.
    $sanitized = [regex]::Replace($sanitized, '(?i)/subscriptions/[0-9a-f-]{36}', '/subscriptions/<SUBSCRIPTION_ID>')
    $sanitized = [regex]::Replace($sanitized, '(?i)/tenants/[0-9a-f-]{36}', '/tenants/<TENANT_ID>')

    # 5. Cualquier otro GUID (Object ID, correlation ID, tracking ID, etc.).
    $sanitized = [regex]::Replace($sanitized, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<GUID>')

    # 6. Correos electronicos.
    $sanitized = [regex]::Replace($sanitized, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '<EMAIL>')

    # 7. Rutas locales de Windows y UNC. Los segmentos no admiten ':' para no seguir de largo tras
    # la unidad y detenerse antes de un separador como ": 65" en un mensaje de excepcion.
    $sanitized = [regex]::Replace($sanitized, '[A-Za-z]:\\(?:[^\\/:*?"<>|\r\n]+\\)*[^\\/:*?"<>|\r\n]*', '<LOCAL_PATH>')
    $sanitized = [regex]::Replace($sanitized, '\\\\[^\\/:*?"<>|\r\n\s]+(?:\\[^\\/:*?"<>|\r\n]+)*', '<LOCAL_PATH>')

    # 8. Nombres de usuario locales con formato DOMINIO\usuario (tras redactar rutas, para reducir
    # falsos positivos sobre fragmentos de ruta ya reemplazados).
    $sanitized = [regex]::Replace($sanitized, '(?i)\b[A-Za-z0-9._-]+\\[A-Za-z][A-Za-z0-9._-]{1,}\b', '<LOCAL_USER>')

    return $sanitized
}

function Invoke-AzCommandCaptureDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StepName,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    foreach ($argument in $Arguments) {
        if ($argument -in @('--debug', '--verbose', '-v')) {
            throw "Bloqueado: Invoke-AzCommandCaptureDiagnostic no permite el argumento '$argument' (prohibido para el diagnostico de preflight, Fase 04)."
        }
    }

    Write-Host "== $StepName (diagnostico; stdout/stderr capturados en memoria, nunca impresos crudos) =="

    $previousEap = $ErrorActionPreference
    $rawItems = $null
    try {
        $ErrorActionPreference = 'Continue'
        $rawItems = & az @Arguments 2>&1
    }
    finally {
        $ErrorActionPreference = $previousEap
    }
    $exitCode = $LASTEXITCODE

    $stdOutLines = New-Object System.Collections.Generic.List[string]
    $stdErrLines = New-Object System.Collections.Generic.List[string]

    foreach ($item in @($rawItems)) {
        if ($item -is [System.Management.Automation.ErrorRecord]) {
            $stdErrLines.Add($item.ToString())
        }
        else {
            $stdOutLines.Add([string]$item)
        }
    }

    [pscustomobject]@{
        ExitCode = $exitCode
        StdOut   = ($stdOutLines -join [Environment]::NewLine)
        StdErr   = ($stdErrLines -join [Environment]::NewLine)
    }
}

function Get-CentinelaAzureErrorClassification {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][AllowNull()][string]$SanitizedCode,
        [AllowEmptyString()][AllowNull()][string]$SanitizedInnerCode,
        [AllowEmptyString()][AllowNull()][string]$SanitizedMessage
    )

    $text = "$SanitizedCode $SanitizedInnerCode $SanitizedMessage".ToLowerInvariant()

    if ([string]::IsNullOrWhiteSpace(($text -replace '\s', ''))) { return 'UNKNOWN' }

    if ($text -match 'quota|capacity|insufficient|exceeded the.*limit|not enough') { return 'QUOTA_OR_CAPACITY' }
    if ($text -match 'skunotavailable|sku is not available|sku.*not available|invalid sku') { return 'SKU_NOT_AVAILABLE' }
    if ($text -match 'locationnotavailableforresourcetype|region.*not available|location.*not available') { return 'REGION_NOT_AVAILABLE' }
    if ($text -match 'notavailableforsubscription|subscriptionnotregistered|restricted for this subscription|not permitted for.*subscription|disallowedforsubscription') { return 'SUBSCRIPTION_RESTRICTION' }
    if ($text -match 'requestdisallowedbypolicy|policy') { return 'POLICY_DENY' }
    if ($text -match 'authorizationfailed|forbidden|unauthorized|does not have authorization|accessdenied') { return 'AUTHORIZATION' }
    if ($text -match 'invalidtemplate|apiversion|api version|invalidapiversionparameter|invalidresourcetype|template') { return 'API_VERSION_OR_TEMPLATE' }

    return 'UNKNOWN'
}

function Get-CentinelaDeepestErrorDetail {
    <#
    Los errores de preflight de ARM anidan "details" en varios niveles (p.ej. un
    ValidationForResourceFailed de nivel intermedio cuyo unico mensaje es "Check
    Error.Details[0] for more information", y la causa funcional real esta un nivel mas abajo).
    Esta funcion desciende recursivamente por "details" hasta la hoja mas profunda y devuelve,
    ademas del code/message/target de esa hoja, la cadena completa de codes recorridos (para
    mostrar el arbol de errores sin exponer nunca el resourceId completo).
    #>
    [CmdletBinding()]
    param(
        $DetailsSource,
        [string[]]$CodeChain = @()
    )

    if (-not $DetailsSource -or @($DetailsSource).Count -eq 0) {
        return [pscustomobject]@{ Code = $null; Message = $null; Target = $null; CodeChain = $CodeChain }
    }

    $current = @($DetailsSource)[0]
    $currentCode = if ($current.PSObject.Properties.Name -contains 'code') { [string]$current.code } else { $null }
    $currentMessage = if ($current.PSObject.Properties.Name -contains 'message') { [string]$current.message } else { $null }
    $currentTarget = if ($current.PSObject.Properties.Name -contains 'target') { [string]$current.target } else { $null }

    $nextChain = if ($currentCode) { $CodeChain + @($currentCode) } else { $CodeChain }

    $nestedDetails = $null
    if ($current.PSObject.Properties.Name -contains 'details' -and @($current.details).Count -gt 0) {
        $nestedDetails = $current.details
    }

    if ($nestedDetails) {
        return Get-CentinelaDeepestErrorDetail -DetailsSource $nestedDetails -CodeChain $nextChain
    }

    return [pscustomobject]@{ Code = $currentCode; Message = $currentMessage; Target = $currentTarget; CodeChain = $nextChain }
}

function Get-CentinelaSanitizedErrorReport {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][AllowNull()][string]$RawStdErr,
        [AllowEmptyString()][AllowNull()][string]$RawStdOut
    )

    $combinedRaw = if (-not [string]::IsNullOrWhiteSpace($RawStdErr)) { $RawStdErr } else { $RawStdOut }

    $code = $null
    $innerCode = $null
    $message = $null
    $resourceType = $null
    $parsedOk = $false
    $codeChain = @()

    if (-not [string]::IsNullOrWhiteSpace($combinedRaw)) {
        # Azure CLI antepone 'ERROR: ' (u ocasionalmente un prefijo de nombre de ejecutable) antes
        # del cuerpo JSON del error. Se recorta ese prefijo unicamente para intentar el parseo;
        # el texto recortado nunca se imprime, solo se usa en memoria.
        $jsonCandidate = [regex]::Replace($combinedRaw, '(?s)^.*?ERROR:\s*', '')
        $jsonCandidate = $jsonCandidate.Trim()

        $parsed = $null
        try {
            $parsed = $jsonCandidate | ConvertFrom-Json -ErrorAction Stop
            $parsedOk = $true
        }
        catch {
            $parsed = $null
        }

        if ($parsed) {
            if ($parsed.PSObject.Properties.Name -contains 'code') { $code = [string]$parsed.code }
            if ($parsed.PSObject.Properties.Name -contains 'message') { $message = [string]$parsed.message }

            $detailsSource = $null
            if ($parsed.PSObject.Properties.Name -contains 'details') {
                $detailsSource = $parsed.details
            }
            elseif ($parsed.PSObject.Properties.Name -contains 'error') {
                if (-not $code -and $parsed.error.PSObject.Properties.Name -contains 'code') { $code = [string]$parsed.error.code }
                if (-not $message -and $parsed.error.PSObject.Properties.Name -contains 'message') { $message = [string]$parsed.error.message }
                if ($parsed.error.PSObject.Properties.Name -contains 'details') { $detailsSource = $parsed.error.details }
            }

            if ($detailsSource -and @($detailsSource).Count -gt 0) {
                $deepest = Get-CentinelaDeepestErrorDetail -DetailsSource $detailsSource
                $codeChain = @($deepest.CodeChain)
                if ($deepest.Code) { $innerCode = $deepest.Code }
                if (-not [string]::IsNullOrWhiteSpace($deepest.Message)) { $message = $deepest.Message }
                if ($deepest.Target) {
                    $resourceType = [regex]::Replace($deepest.Target, '(?i)^.*/providers/', '')
                }
            }
        }
    }

    if (-not $message) { $message = $combinedRaw }

    $sanitizedCode = ConvertTo-CentinelaSanitizedText -Text $code
    $sanitizedInnerCode = ConvertTo-CentinelaSanitizedText -Text $innerCode
    $sanitizedMessage = ConvertTo-CentinelaSanitizedText -Text $message
    $sanitizedResourceType = ConvertTo-CentinelaSanitizedText -Text $resourceType
    $sanitizedCodeChain = @($codeChain | ForEach-Object { ConvertTo-CentinelaSanitizedText -Text $_ })

    $region = $null
    if ($sanitizedMessage -match '(?i)\b(eastus2|centralus|east us 2|central us)\b') { $region = $matches[0] }

    $sku = $null
    if ($sanitizedMessage -match '(?i)\bB1\b') { $sku = 'B1' }

    # Un mensaje que unicamente redirige a un nivel mas profundo ("Check Error.Details[...] for
    # more information", sin describir la causa funcional) no aporta evidencia real: se trata
    # como si no se hubiera obtenido el inner error, y la clasificacion cae a UNKNOWN aunque
    # existan code/innerCode, en vez de forzar una causa que el mensaje no sustenta.
    $messageIsNonInformativeRedirect = ($sanitizedMessage -match '(?i)check\s+.*details.*for more information')

    $classification = if ($messageIsNonInformativeRedirect) {
        'UNKNOWN'
    }
    else {
        Get-CentinelaAzureErrorClassification -SanitizedCode $sanitizedCode -SanitizedInnerCode $sanitizedInnerCode -SanitizedMessage $sanitizedMessage
    }

    if (-not $parsedOk -and [string]::IsNullOrWhiteSpace($sanitizedCode) -and [string]::IsNullOrWhiteSpace($sanitizedInnerCode)) {
        $classification = 'UNKNOWN'
    }

    [pscustomobject]@{
        ParsedOk       = $parsedOk
        Code           = $sanitizedCode
        InnerCode      = $sanitizedInnerCode
        CodeChain      = $sanitizedCodeChain
        Message        = $sanitizedMessage
        ResourceType   = $sanitizedResourceType
        Region         = $region
        Sku            = $sku
        Classification = $classification
    }
}
