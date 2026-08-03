namespace Centinela.Application.Abstractions.AzureCli;

/// <summary>
/// Contrato base de toda solicitud tipada de Azure CLI. No existe ninguna implementación que
/// acepte un comando libre: cada solicitud concreta corresponde exactamente a una operación de
/// <see cref="AzureCliOperation"/> y expone solo los parámetros tipados de esa operación.
/// </summary>
public interface IAzureCliCommandRequest
{
    AzureCliOperation Operation { get; }
}
