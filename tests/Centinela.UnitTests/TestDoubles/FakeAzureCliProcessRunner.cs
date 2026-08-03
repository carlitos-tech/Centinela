using Centinela.Infrastructure.AzureCli;

namespace Centinela.UnitTests.TestDoubles;

/// <summary>
/// Runner de prueba que nunca inicia un proceso real: solo registra los argumentos recibidos y
/// devuelve un resultado configurado por el test. Permite verificar que el gateway construye
/// argumentos tipados (lista de tokens, nunca una cadena de comando) sin depender de Azure CLI.
/// </summary>
public sealed class FakeAzureCliProcessRunner : IAzureCliProcessRunner
{
    public List<IReadOnlyList<string>> ReceivedArguments { get; } = [];

    public int CallCount => ReceivedArguments.Count;

    public AzureCliRawProcessResult NextResult { get; set; } = new()
    {
        ExitCode = 0,
        StandardOutput = string.Empty,
        StandardError = string.Empty,
        TimedOut = false,
    };

    public Func<IReadOnlyList<string>, AzureCliRawProcessResult>? ResultFactory { get; set; }

    public Task<AzureCliRawProcessResult> RunAsync(IReadOnlyList<string> arguments, TimeSpan timeout, CancellationToken cancellationToken)
    {
        ReceivedArguments.Add(arguments);

        cancellationToken.ThrowIfCancellationRequested();

        var result = ResultFactory?.Invoke(arguments) ?? NextResult;
        return Task.FromResult(result);
    }
}
