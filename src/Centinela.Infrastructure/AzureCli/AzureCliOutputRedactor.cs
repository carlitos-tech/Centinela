using System.Text.RegularExpressions;

namespace Centinela.Infrastructure.AzureCli;

/// <summary>
/// Redacta de cualquier texto (salida de `az`, argumentos, mensajes de error) los patrones que
/// podrían revelar Tenant ID, Subscription ID, otros GUID, tokens, contraseñas, API keys, cadenas
/// de conexión, rutas locales de desarrollo o correos electrónicos. Se aplica siempre antes de que
/// cualquier resultado o registro de auditoría salga del gateway.
/// </summary>
public static class AzureCliOutputRedactor
{
    private static readonly (Regex Pattern, string Replacement)[] Rules =
    [
        (new Regex(@"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b", RegexOptions.Compiled), "[REDACTED-GUID]"),
        (new Regex(@"\b[\w.+-]+@[\w-]+\.[A-Za-z]{2,}\b", RegexOptions.Compiled), "[REDACTED-EMAIL]"),
        (new Regex(@"(?i:(AccountKey|SharedAccessKey|SharedAccessSignature|Password|Pwd)\s*=\s*[^;""'\s]+)", RegexOptions.Compiled), "$1=[REDACTED]"),
        (new Regex(@"(?i:Bearer\s+[A-Za-z0-9\-_\.]+)", RegexOptions.Compiled), "Bearer [REDACTED-TOKEN]"),
        (new Regex(@"(?i:""(accessToken|token|password|secret|apiKey|api_key|connectionString|clientSecret)""\s*:\s*""[^""]*"")", RegexOptions.Compiled), "\"$1\": \"[REDACTED]\""),
        (new Regex(@"[A-Za-z]:\\Users\\[^\s""']+", RegexOptions.Compiled), "[REDACTED-PATH]"),
        (new Regex(@"/(home|Users)/[^\s""']+", RegexOptions.Compiled), "[REDACTED-PATH]"),
    ];

    public static string Redact(string? value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return value ?? string.Empty;
        }

        var redacted = value;
        foreach (var (pattern, replacement) in Rules)
        {
            redacted = pattern.Replace(redacted, replacement);
        }

        return redacted;
    }
}
