namespace Centinela.Application.Abstractions.AzureCli;

/// <summary>
/// Familia de solicitudes tipadas, una por operación de <see cref="AzureCliOperation"/>. Se agrupan
/// en un solo archivo por ser DTOs pequeños y estrechamente relacionados (misma allowlist); cada
/// tipo se traduce a argumentos concretos exclusivamente en <c>AzureCliCommandPolicy</c>.
/// </summary>
public sealed record AccountShowRequest : IAzureCliCommandRequest
{
    public AzureCliOperation Operation => AzureCliOperation.AccountShow;
}

public sealed record AccountListLocationsRequest : IAzureCliCommandRequest
{
    public AzureCliOperation Operation => AzureCliOperation.AccountListLocations;
}

public sealed record ProviderShowRequest : IAzureCliCommandRequest
{
    public required string Namespace { get; init; }

    public AzureCliOperation Operation => AzureCliOperation.ProviderShow;
}

public sealed record ProviderListRequest : IAzureCliCommandRequest
{
    public AzureCliOperation Operation => AzureCliOperation.ProviderList;
}

public sealed record WebAppListRuntimesRequest : IAzureCliCommandRequest
{
    /// <summary>"linux" o "windows".</summary>
    public required string Os { get; init; }

    public AzureCliOperation Operation => AzureCliOperation.WebAppListRuntimes;
}

public sealed record GroupExistsRequest : IAzureCliCommandRequest
{
    public required string Name { get; init; }

    public AzureCliOperation Operation => AzureCliOperation.GroupExists;
}

public sealed record GroupShowRequest : IAzureCliCommandRequest
{
    public required string Name { get; init; }

    public AzureCliOperation Operation => AzureCliOperation.GroupShow;
}

public sealed record BicepVersionRequest : IAzureCliCommandRequest
{
    public AzureCliOperation Operation => AzureCliOperation.BicepVersion;
}

public sealed record BicepBuildRequest : IAzureCliCommandRequest
{
    /// <summary>Ruta relativa dentro de <c>infra/</c>, por ejemplo <c>infra/main.bicep</c>.</summary>
    public required string FilePath { get; init; }

    public AzureCliOperation Operation => AzureCliOperation.BicepBuild;
}

public sealed record BicepLintRequest : IAzureCliCommandRequest
{
    /// <summary>Ruta relativa dentro de <c>infra/</c>, por ejemplo <c>infra/main.bicep</c>.</summary>
    public required string FilePath { get; init; }

    public AzureCliOperation Operation => AzureCliOperation.BicepLint;
}

public sealed record DeploymentSubValidateRequest : IAzureCliCommandRequest
{
    public required string Location { get; init; }
    public required string TemplateFile { get; init; }
    public string? ParametersFile { get; init; }

    public AzureCliOperation Operation => AzureCliOperation.DeploymentSubValidate;
}

public sealed record DeploymentSubWhatIfRequest : IAzureCliCommandRequest
{
    public required string Location { get; init; }
    public required string TemplateFile { get; init; }
    public string? ParametersFile { get; init; }

    public AzureCliOperation Operation => AzureCliOperation.DeploymentSubWhatIf;
}

public sealed record DeploymentGroupValidateRequest : IAzureCliCommandRequest
{
    public required string ResourceGroupName { get; init; }
    public required string TemplateFile { get; init; }
    public string? ParametersFile { get; init; }

    public AzureCliOperation Operation => AzureCliOperation.DeploymentGroupValidate;
}

public sealed record DeploymentGroupWhatIfRequest : IAzureCliCommandRequest
{
    public required string ResourceGroupName { get; init; }
    public required string TemplateFile { get; init; }
    public string? ParametersFile { get; init; }

    public AzureCliOperation Operation => AzureCliOperation.DeploymentGroupWhatIf;
}
