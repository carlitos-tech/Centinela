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
    public required TimeSpan Duration { get; init; }
}
