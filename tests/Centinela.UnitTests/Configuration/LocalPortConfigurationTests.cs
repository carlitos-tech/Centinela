using System.Text.Json;

namespace Centinela.UnitTests.Configuration;

/// <summary>
/// Verifica que el puerto local documentado (5299 para la API, 4200 para Angular) coincide con la
/// configuración versionada, de modo que <c>dotnet run --project src/Centinela.Api</c> y
/// <c>npm start</c> funcionen sin depender de variables de entorno manuales como
/// <c>ASPNETCORE_URLS</c>.
/// </summary>
public class LocalPortConfigurationTests
{
    private const string ExpectedApiUrl = "http://localhost:5299";
    private const string ExpectedFrontendUrl = "http://localhost:4200";

    [Fact]
    public void LaunchSettings_DefaultProfile_BindsToDocumentedApiPort()
    {
        var launchSettingsPath = Path.Combine(RepositoryRoot(), "src", "Centinela.Api", "Properties", "launchSettings.json");
        using var document = JsonDocument.Parse(File.ReadAllText(launchSettingsPath));

        var profiles = document.RootElement.GetProperty("profiles");
        var firstProfile = profiles.EnumerateObject().First();
        var applicationUrl = firstProfile.Value.GetProperty("applicationUrl").GetString();

        Assert.NotNull(applicationUrl);
        Assert.Contains(ExpectedApiUrl, applicationUrl!.Split(';'));
    }

    [Fact]
    public void ApiConfig_FrontendPointsAtDocumentedApiPort()
    {
        var apiConfigPath = Path.Combine(RepositoryRoot(), "web", "centinela-web", "src", "app", "core", "api-config.ts");
        var content = File.ReadAllText(apiConfigPath);

        Assert.Contains($"'{ExpectedApiUrl}'", content);
    }

    [Fact]
    public void Readme_DocumentsTheSamePortsAsTheVersionedConfig()
    {
        var readmePath = Path.Combine(RepositoryRoot(), "README.md");
        var content = File.ReadAllText(readmePath);

        Assert.Contains(ExpectedApiUrl, content);
        Assert.Contains(ExpectedFrontendUrl, content);
    }

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Centinela.slnx")))
        {
            directory = directory.Parent;
        }

        return directory?.FullName
            ?? throw new InvalidOperationException("No se encontró Centinela.slnx al buscar la raíz del repositorio.");
    }
}
