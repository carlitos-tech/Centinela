namespace Centinela.Infrastructure.AzureCli;

/// <summary>Resultado crudo (no redactado) de una ejecución del proceso `az`. Uso interno del runner y del gateway.</summary>
public sealed record AzureCliRawProcessResult
{
    public required int ExitCode { get; init; }
    public required string StandardOutput { get; init; }
    public required string StandardError { get; init; }
    public required bool TimedOut { get; init; }
}
