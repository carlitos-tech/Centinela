namespace Centinela.Application.Abstractions.AzureCli;

/// <summary>
/// Registro de auditoría sanitizado de una solicitud al gateway, permitida o bloqueada. Nunca
/// contiene secretos, GUID sin enmascarar, tokens, contraseñas, cadenas de conexión ni rutas
/// locales de desarrollo.
/// </summary>
public sealed record AzureCliAuditRecord
{
    public required string CorrelationId { get; init; }
    public required DateTimeOffset TimestampUtc { get; init; }
    public required AzureCliOperation Operation { get; init; }
    public required IReadOnlyList<string> SanitizedArguments { get; init; }
    public required bool Allowed { get; init; }
    public bool? Success { get; init; }
    public int? ExitCode { get; init; }
    public string? DenialReason { get; init; }

    /// <summary>
    /// True cuando una operación permitida por la allowlist no llegó a completarse porque el
    /// caller canceló el <see cref="System.Threading.CancellationToken"/> (a diferencia de un
    /// timeout interno del proceso, que se refleja en <c>ExitCode = -1</c> con este campo en
    /// false). Distingue una cancelación deliberada del caller de cualquier otro fallo de
    /// ejecución.
    /// </summary>
    public bool Cancelled { get; init; }

    /// <summary>
    /// Motivo sanitizado (ver <see cref="Centinela.Infrastructure.AzureCli.AzureCliOutputRedactor"/>)
    /// de por qué una operación permitida por la allowlist no llegó a producir un
    /// <see cref="Success"/> definitivo: el binario `az` no existe/no pudo iniciarse, el runner
    /// lanzó una excepción inesperada, o el caller canceló la operación. Distinto de
    /// <see cref="DenialReason"/>, que solo aplica a solicitudes rechazadas por la política antes
    /// de intentar ejecutar el proceso.
    /// </summary>
    public string? FailureReason { get; init; }

    public required TimeSpan Duration { get; init; }
}
