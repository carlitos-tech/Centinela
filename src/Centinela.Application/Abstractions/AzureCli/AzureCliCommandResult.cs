namespace Centinela.Application.Abstractions.AzureCli;

/// <summary>Resultado ya redactado (sin secretos) de una ejecución del gateway.</summary>
public sealed record AzureCliCommandResult
{
    public required bool Success { get; init; }
    public required int ExitCode { get; init; }
    public required string SanitizedStandardOutput { get; init; }
    public required string SanitizedStandardError { get; init; }
    public required TimeSpan Duration { get; init; }
    public required string CorrelationId { get; init; }
}
