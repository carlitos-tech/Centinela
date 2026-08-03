namespace Centinela.Application.Abstractions.AzureCli;

/// <summary>
/// Único mecanismo permitido para que los componentes de Centinela ejecuten Azure CLI. No expone
/// ningún método de comando libre: toda ejecución parte de una solicitud tipada correspondiente a
/// una operación conocida de la allowlist (ver ADR de la Fase 03).
/// </summary>
public interface IAzureCliCommandGateway
{
    Task<AzureCliCommandResult> ExecuteAsync(IAzureCliCommandRequest request, CancellationToken cancellationToken = default);
}
