namespace Centinela.Infrastructure.AzureCli;

/// <summary>
/// Ejecuta el binario `az` de forma segura (sin shell interactivo, con ArgumentList, timeout y
/// cancelación). Es el único punto del sistema que efectivamente lanza un proceso de Azure CLI.
/// </summary>
public interface IAzureCliProcessRunner
{
    Task<AzureCliRawProcessResult> RunAsync(IReadOnlyList<string> arguments, TimeSpan timeout, CancellationToken cancellationToken);
}
