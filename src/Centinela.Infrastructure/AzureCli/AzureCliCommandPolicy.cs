using System.Text.RegularExpressions;
using Centinela.Application.Abstractions.AzureCli;

namespace Centinela.Infrastructure.AzureCli;

/// <summary>
/// Allowlist de operaciones de Azure CLI: única responsable de traducir una solicitud tipada en la
/// lista de argumentos que se pasará al proceso `az`. No existe ninguna ruta que acepte una cadena
/// de comando libre. Toda operación no reconocida, o con parámetros que no superen la validación,
/// se rechaza aquí — antes de construir el <c>ProcessStartInfo</c> — por lo que el proceso nunca
/// llega a iniciarse.
/// </summary>
public static class AzureCliCommandPolicy
{
    // Coincide con las regiones documentadas para el proyecto: East US 2 (principal) y Central US (alterna).
    private static readonly HashSet<string> AllowedLocations = new(StringComparer.OrdinalIgnoreCase)
    {
        "eastus2",
        "centralus",
    };

    private static readonly HashSet<string> AllowedOsValues = new(StringComparer.OrdinalIgnoreCase) { "linux", "windows" };

    private static readonly Regex ProviderNamespacePattern = new(@"^Microsoft\.[A-Za-z]+$", RegexOptions.Compiled);
    private static readonly Regex ResourceGroupNamePattern = new(@"^[a-zA-Z0-9._\-]{1,90}$", RegexOptions.Compiled);
    private static readonly Regex RelativeInfraPathPattern = new(@"^infra/[a-zA-Z0-9._\-/]+$", RegexOptions.Compiled);

    public static IReadOnlyList<string> BuildArguments(IAzureCliCommandRequest request) => request switch
    {
        AccountShowRequest =>
            ["account", "show", "--output", "json", "--only-show-errors"],

        AccountListLocationsRequest =>
            ["account", "list-locations", "--output", "json", "--only-show-errors"],

        ProviderShowRequest r =>
            ["provider", "show", "--namespace", RequireProviderNamespace(r.Namespace), "--output", "json", "--only-show-errors"],

        ProviderListRequest =>
            ["provider", "list", "--output", "json", "--only-show-errors", "--query", "[].{namespace:namespace,state:registrationState}"],

        WebAppListRuntimesRequest r =>
            ["webapp", "list-runtimes", "--os", RequireOs(r.Os), "--output", "json", "--only-show-errors"],

        GroupExistsRequest r =>
            ["group", "exists", "--name", RequireResourceGroupName(r.Name), "--only-show-errors"],

        GroupShowRequest r =>
            ["group", "show", "--name", RequireResourceGroupName(r.Name), "--output", "json", "--only-show-errors"],

        BicepVersionRequest =>
            ["bicep", "version"],

        BicepBuildRequest r =>
            ["bicep", "build", "--file", RequireInfraTemplatePath(r.FilePath)],

        BicepLintRequest r =>
            ["bicep", "lint", "--file", RequireInfraTemplatePath(r.FilePath)],

        DeploymentSubValidateRequest r =>
            BuildSubscriptionDeploymentArgs("validate", r.Location, r.TemplateFile, r.ParametersFile),

        DeploymentSubWhatIfRequest r =>
            BuildSubscriptionDeploymentArgs("what-if", r.Location, r.TemplateFile, r.ParametersFile),

        DeploymentGroupValidateRequest r =>
            BuildGroupDeploymentArgs("validate", r.ResourceGroupName, r.TemplateFile, r.ParametersFile),

        DeploymentGroupWhatIfRequest r =>
            BuildGroupDeploymentArgs("what-if", r.ResourceGroupName, r.TemplateFile, r.ParametersFile),

        _ => throw new AzureCliOperationNotAllowedException(
            $"La solicitud de tipo '{request.GetType().Name}' no corresponde a ninguna operación permitida por la allowlist."),
    };

    private static List<string> BuildSubscriptionDeploymentArgs(string mode, string location, string templateFile, string? parametersFile)
    {
        var args = new List<string>
        {
            "deployment", "sub", mode,
            "--location", RequireAllowedLocation(location),
            "--template-file", RequireInfraTemplatePath(templateFile),
        };

        AppendParametersIfPresent(args, parametersFile);

        args.Add("--output");
        args.Add("json");
        args.Add("--only-show-errors");
        return args;
    }

    private static List<string> BuildGroupDeploymentArgs(string mode, string resourceGroupName, string templateFile, string? parametersFile)
    {
        var args = new List<string>
        {
            "deployment", "group", mode,
            "--resource-group", RequireResourceGroupName(resourceGroupName),
            "--template-file", RequireInfraTemplatePath(templateFile),
        };

        AppendParametersIfPresent(args, parametersFile);

        args.Add("--output");
        args.Add("json");
        args.Add("--only-show-errors");
        return args;
    }

    private static void AppendParametersIfPresent(List<string> args, string? parametersFile)
    {
        if (string.IsNullOrWhiteSpace(parametersFile))
        {
            return;
        }

        args.Add("--parameters");
        args.Add(RequireInfraTemplatePath(parametersFile));
    }

    private static string RequireProviderNamespace(string value) =>
        ProviderNamespacePattern.IsMatch(value)
            ? value
            : throw new AzureCliOperationNotAllowedException("Namespace de proveedor inválido para 'az provider show'.");

    private static string RequireOs(string value) =>
        AllowedOsValues.Contains(value)
            ? value.ToLowerInvariant()
            : throw new AzureCliOperationNotAllowedException("Valor de --os inválido para 'az webapp list-runtimes' (solo 'linux' o 'windows').");

    private static string RequireResourceGroupName(string value) =>
        ResourceGroupNamePattern.IsMatch(value)
            ? value
            : throw new AzureCliOperationNotAllowedException("Nombre de resource group inválido.");

    private static string RequireAllowedLocation(string value) =>
        AllowedLocations.Contains(value)
            ? value.ToLowerInvariant()
            : throw new AzureCliOperationNotAllowedException($"Región '{value}' no está en la allowlist de regiones del proyecto (East US 2 / Central US).");

    private static string RequireInfraTemplatePath(string value)
    {
        var normalized = value.Replace('\\', '/');

        if (normalized.Contains(".."))
        {
            throw new AzureCliOperationNotAllowedException("La ruta de plantilla no puede contener segmentos '..'.");
        }

        return RelativeInfraPathPattern.IsMatch(normalized)
            ? normalized
            : throw new AzureCliOperationNotAllowedException("La ruta de plantilla debe ser relativa y estar dentro de 'infra/'.");
    }
}
