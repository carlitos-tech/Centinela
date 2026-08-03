using Centinela.Application.Abstractions.AzureCli;
using Centinela.Infrastructure.AzureCli;

namespace Centinela.UnitTests.AzureCli;

public class AzureCliCommandPolicyTests
{
    [Fact]
    public void BuildArguments_AccountShow_ReturnsExpectedArguments()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new AccountShowRequest());

        Assert.Equal(["account", "show", "--output", "json", "--only-show-errors"], args);
    }

    [Fact]
    public void BuildArguments_AccountListLocations_ReturnsExpectedArguments()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new AccountListLocationsRequest());

        Assert.Equal(["account", "list-locations", "--output", "json", "--only-show-errors"], args);
    }

    [Fact]
    public void BuildArguments_ProviderShow_WithValidNamespace_ReturnsExpectedArguments()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new ProviderShowRequest { Namespace = "Microsoft.Web" });

        Assert.Equal(["provider", "show", "--namespace", "Microsoft.Web", "--output", "json", "--only-show-errors"], args);
    }

    [Theory]
    [InlineData("Microsoft.Web; rm -rf /")]
    [InlineData("Microsoft.Web && whoami")]
    [InlineData("microsoft.web")]
    [InlineData("")]
    [InlineData("NotMicrosoft.Web")]
    public void BuildArguments_ProviderShow_WithInvalidNamespace_Throws(string malicious)
    {
        var request = new ProviderShowRequest { Namespace = malicious };

        Assert.Throws<AzureCliOperationNotAllowedException>(() => AzureCliCommandPolicy.BuildArguments(request));
    }

    [Fact]
    public void BuildArguments_ProviderList_ReturnsExpectedArguments()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new ProviderListRequest());

        Assert.Equal(
            ["provider", "list", "--output", "json", "--only-show-errors", "--query", "[].{namespace:namespace,state:registrationState}"],
            args);
    }

    [Theory]
    [InlineData("linux", "linux")]
    [InlineData("LINUX", "linux")]
    [InlineData("windows", "windows")]
    public void BuildArguments_WebAppListRuntimes_WithValidOs_ReturnsExpectedArguments(string input, string normalized)
    {
        var args = AzureCliCommandPolicy.BuildArguments(new WebAppListRuntimesRequest { Os = input });

        Assert.Equal(["webapp", "list-runtimes", "--os", normalized, "--output", "json", "--only-show-errors"], args);
    }

    [Theory]
    [InlineData("macos")]
    [InlineData("linux; rm -rf /")]
    [InlineData("")]
    public void BuildArguments_WebAppListRuntimes_WithInvalidOs_Throws(string malicious)
    {
        var request = new WebAppListRuntimesRequest { Os = malicious };

        Assert.Throws<AzureCliOperationNotAllowedException>(() => AzureCliCommandPolicy.BuildArguments(request));
    }

    [Fact]
    public void BuildArguments_GroupExists_WithValidName_ReturnsExpectedArguments()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new GroupExistsRequest { Name = "rg-novacasa-centinela-dev" });

        Assert.Equal(["group", "exists", "--name", "rg-novacasa-centinela-dev", "--only-show-errors"], args);
    }

    [Fact]
    public void BuildArguments_GroupShow_WithValidName_ReturnsExpectedArguments()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new GroupShowRequest { Name = "rg-novacasa-centinela-dev" });

        Assert.Equal(["group", "show", "--name", "rg-novacasa-centinela-dev", "--output", "json", "--only-show-errors"], args);
    }

    [Theory]
    [InlineData("rg; rm -rf /")]
    [InlineData("rg && whoami")]
    [InlineData("rg`whoami`")]
    [InlineData("rg$(whoami)")]
    [InlineData("")]
    public void BuildArguments_GroupExists_WithInvalidName_Throws(string malicious)
    {
        var request = new GroupExistsRequest { Name = malicious };

        Assert.Throws<AzureCliOperationNotAllowedException>(() => AzureCliCommandPolicy.BuildArguments(request));
    }

    [Fact]
    public void BuildArguments_BicepVersion_ReturnsExpectedArguments()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new BicepVersionRequest());

        Assert.Equal(["bicep", "version"], args);
    }

    [Fact]
    public void BuildArguments_BicepBuild_WithValidPath_ReturnsExpectedArguments()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new BicepBuildRequest { FilePath = "infra/main.bicep" });

        Assert.Equal(["bicep", "build", "--file", "infra/main.bicep"], args);
    }

    [Theory]
    [InlineData("infra/../secrets.bicep")]
    [InlineData("../../etc/passwd")]
    [InlineData("modules/storage.bicep")]
    [InlineData("C:/Windows/System32/config")]
    [InlineData("infra/main.bicep; rm -rf /")]
    public void BuildArguments_BicepBuild_WithInvalidPath_Throws(string malicious)
    {
        var request = new BicepBuildRequest { FilePath = malicious };

        Assert.Throws<AzureCliOperationNotAllowedException>(() => AzureCliCommandPolicy.BuildArguments(request));
    }

    [Fact]
    public void BuildArguments_BicepBuild_NormalizesBackslashes()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new BicepBuildRequest { FilePath = @"infra\main.bicep" });

        Assert.Equal(["bicep", "build", "--file", "infra/main.bicep"], args);
    }

    [Fact]
    public void BuildArguments_BicepLint_WithValidPath_ReturnsExpectedArguments()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new BicepLintRequest { FilePath = "infra/main.bicep" });

        Assert.Equal(["bicep", "lint", "--file", "infra/main.bicep"], args);
    }

    [Fact]
    public void BuildArguments_DeploymentSubValidate_WithAllowedLocation_ReturnsExpectedArguments()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new DeploymentSubValidateRequest
        {
            Location = "eastus2",
            TemplateFile = "infra/main.bicep",
            ParametersFile = "infra/dev.bicepparam",
        });

        Assert.Equal(
            [
                "deployment", "sub", "validate",
                "--location", "eastus2",
                "--template-file", "infra/main.bicep",
                "--parameters", "infra/dev.bicepparam",
                "--output", "json", "--only-show-errors",
            ],
            args);
    }

    [Fact]
    public void BuildArguments_DeploymentSubValidate_WithoutParametersFile_OmitsParametersFlag()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new DeploymentSubValidateRequest
        {
            Location = "eastus2",
            TemplateFile = "infra/main.bicep",
        });

        Assert.DoesNotContain("--parameters", args);
    }

    [Theory]
    [InlineData("westus")]
    [InlineData("eastus")]
    [InlineData("global")]
    [InlineData("eastus2; rm -rf /")]
    public void BuildArguments_DeploymentSubValidate_WithDisallowedLocation_Throws(string disallowed)
    {
        var request = new DeploymentSubValidateRequest { Location = disallowed, TemplateFile = "infra/main.bicep" };

        Assert.Throws<AzureCliOperationNotAllowedException>(() => AzureCliCommandPolicy.BuildArguments(request));
    }

    [Fact]
    public void BuildArguments_DeploymentSubWhatIf_UsesWhatIfMode()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new DeploymentSubWhatIfRequest
        {
            Location = "centralus",
            TemplateFile = "infra/main.bicep",
        });

        Assert.Equal("what-if", args[2]);
        Assert.DoesNotContain(args, a => a.Contains("create", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void BuildArguments_DeploymentGroupValidate_WithValidResourceGroup_ReturnsExpectedArguments()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new DeploymentGroupValidateRequest
        {
            ResourceGroupName = "rg-novacasa-centinela-dev",
            TemplateFile = "infra/main.bicep",
        });

        Assert.Equal(
            [
                "deployment", "group", "validate",
                "--resource-group", "rg-novacasa-centinela-dev",
                "--template-file", "infra/main.bicep",
                "--output", "json", "--only-show-errors",
            ],
            args);
    }

    [Fact]
    public void BuildArguments_DeploymentGroupWhatIf_UsesWhatIfMode()
    {
        var args = AzureCliCommandPolicy.BuildArguments(new DeploymentGroupWhatIfRequest
        {
            ResourceGroupName = "rg-novacasa-centinela-dev",
            TemplateFile = "infra/main.bicep",
        });

        Assert.Equal("what-if", args[2]);
    }

    [Fact]
    public void BuildArguments_UnrecognizedRequestType_Throws()
    {
        var request = new UnknownRequest();

        var ex = Assert.Throws<AzureCliOperationNotAllowedException>(() => AzureCliCommandPolicy.BuildArguments(request));
        Assert.Contains("UnknownRequest", ex.Message);
    }

    [Fact]
    public void BuildArguments_HypotheticalDeploymentCreateShape_IsNotRecognizedAndThrows()
    {
        // No existe ningún AzureCliOperation ni tipo de solicitud para "create": esta forma
        // hipotética simula qué pasaría si alguien intentara agregar una sin registrarla en la
        // allowlist. Debe rechazarse antes de construir cualquier argumento o iniciar un proceso.
        var request = new HypotheticalDeploymentSubCreateRequest
        {
            Location = "eastus2",
            TemplateFile = "infra/main.bicep",
        };

        Assert.Throws<AzureCliOperationNotAllowedException>(() => AzureCliCommandPolicy.BuildArguments(request));
    }

    [Fact]
    public void AzureCliOperation_NeverIncludesMutatingOrPrivilegedVerbs()
    {
        var forbiddenSubstrings = new[] { "Create", "Delete", "Update", "Register", "RoleAssignment", "Secret", "Rbac" };

        var operationNames = Enum.GetNames<AzureCliOperation>();

        foreach (var name in operationNames)
        {
            foreach (var forbidden in forbiddenSubstrings)
            {
                Assert.DoesNotContain(forbidden, name, StringComparison.OrdinalIgnoreCase);
            }
        }
    }

    private sealed record UnknownRequest : IAzureCliCommandRequest
    {
        public AzureCliOperation Operation => (AzureCliOperation)(-1);
    }

    private sealed record HypotheticalDeploymentSubCreateRequest : IAzureCliCommandRequest
    {
        public required string Location { get; init; }
        public required string TemplateFile { get; init; }

        // Reutiliza deliberadamente un valor de la enumeración existente: lo que importa es que el
        // switch de BuildArguments no tiene ninguna rama para este *tipo* de solicitud, por lo que
        // cae en el brazo por defecto sin importar qué Operation declare.
        public AzureCliOperation Operation => AzureCliOperation.DeploymentSubValidate;
    }
}
