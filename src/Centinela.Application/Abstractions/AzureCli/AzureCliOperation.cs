namespace Centinela.Application.Abstractions.AzureCli;

/// <summary>
/// Operaciones de Azure CLI reconocidas por la allowlist del gateway. Cualquier operación que no
/// esté en esta enumeración es rechazada antes de construir o ejecutar ningún proceso.
/// </summary>
public enum AzureCliOperation
{
    AccountShow,
    AccountListLocations,
    ProviderShow,
    ProviderList,
    WebAppListRuntimes,
    GroupExists,
    GroupShow,
    BicepVersion,
    BicepBuild,
    BicepLint,
    DeploymentSubValidate,
    DeploymentSubWhatIf,
    DeploymentGroupValidate,
    DeploymentGroupWhatIf,
}
