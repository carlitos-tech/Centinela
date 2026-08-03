namespace Centinela.Application.Abstractions.AzureCli;

/// <summary>
/// Se lanza cuando una solicitud no corresponde a ninguna operación permitida por la allowlist, o
/// cuando alguno de sus parámetros no supera la validación de la política de comandos. El proceso
/// de Azure CLI nunca llega a iniciarse en estos casos.
/// </summary>
public sealed class AzureCliOperationNotAllowedException : Exception
{
    public AzureCliOperationNotAllowedException(string message)
        : base(message)
    {
    }
}
