using System.Diagnostics;
using Centinela.Application.Abstractions.AzureCli;
using Centinela.Infrastructure.AzureCli;

namespace Centinela.IntegrationTests;

/// <summary>
/// Pruebas de integración locales controladas: ejecutan el gateway real contra el binario `az`
/// real, pero exclusivamente con operaciones de solo lectura/validación de la allowlist (nunca
/// `create`, `delete`, `update`, `provider register` ni cambios de RBAC — esas operaciones ni
/// siquiera existen como solicitudes tipadas en este proyecto). Si Azure CLI no está instalado en
/// el entorno donde corre `dotnet test` (por ejemplo, un runner de CI sin `az`), estas pruebas se
/// omiten en tiempo de ejecución en lugar de fallar, para no acoplar la suite general a una
/// dependencia externa opcional.
/// </summary>
public class AzureCliGatewayIntegrationTests
{
    private static readonly bool AzureCliAvailable = DetectAzureCli();

    private readonly AzureCliCommandGateway _gateway = new(new AzureCliProcessRunner(), new InMemoryAzureCliAuditSink());

    [Fact]
    public async Task ExecuteAsync_BicepVersion_SucceedsAgainstRealAzureCli()
    {
        if (!AzureCliAvailable)
        {
            return;
        }

        var result = await _gateway.ExecuteAsync(new BicepVersionRequest());

        Assert.True(result.Success);
        Assert.Equal(0, result.ExitCode);
        Assert.Contains("Bicep CLI version", result.SanitizedStandardOutput);
    }

    [Fact]
    public async Task ExecuteAsync_ProviderShow_CompletesWithoutThrowing()
    {
        if (!AzureCliAvailable)
        {
            return;
        }

        var result = await _gateway.ExecuteAsync(new ProviderShowRequest { Namespace = "Microsoft.Web" });

        // No se afirma éxito: si la sesión local no tiene una cuenta autenticada, `az` devuelve un
        // código de salida distinto de cero, y eso es un resultado válido y esperado — lo que esta
        // prueba verifica es que el gateway ejecuta la operación de solo lectura de punta a punta
        // (política -> proceso real -> redacción -> resultado) sin lanzar ninguna excepción.
        Assert.NotNull(result.CorrelationId);
    }

    [Fact]
    public async Task ExecuteAsync_HypotheticalDeploymentCreateShape_IsRejectedBeforeTouchingRealProcess()
    {
        var request = new HypotheticalCreateRequest();

        await Assert.ThrowsAsync<AzureCliOperationNotAllowedException>(() => _gateway.ExecuteAsync(request));
    }

    [Fact]
    public async Task RunAsync_WithVeryShortTimeout_ReturnsTimedOutTrue()
    {
        if (!AzureCliAvailable)
        {
            return;
        }

        var runner = new AzureCliProcessRunner();

        var result = await runner.RunAsync(["bicep", "version"], TimeSpan.FromMilliseconds(1), CancellationToken.None);

        Assert.True(result.TimedOut);
        Assert.Equal(-1, result.ExitCode);
    }

    [Fact]
    public async Task RunAsync_WithPreCancelledToken_ThrowsOperationCanceled()
    {
        if (!AzureCliAvailable)
        {
            return;
        }

        var runner = new AzureCliProcessRunner();
        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(
            () => runner.RunAsync(["bicep", "version"], TimeSpan.FromSeconds(30), cts.Token));
    }

    /// <summary>
    /// Repite el escenario de timeout varias veces en el mismo proceso de prueba para exponer
    /// condiciones de carrera entre Kill(entireProcessTree: true) y el retorno de RunAsync: antes
    /// de la corrección, el método podía retornar sin esperar a que el proceso matado terminara
    /// realmente, dejando una ventana en la que un proceso `az` seguía vivo (huérfano) y los
    /// manejadores de salida aún podían escribir de forma asíncrona sobre los StringBuilder ya
    /// leídos por ToString(). Ejecuciones repetidas hacen que esa ventana de carrera, si existiera,
    /// se manifieste con alta probabilidad como una excepción, un hang o un resultado inconsistente.
    /// </summary>
    [Fact]
    public async Task RunAsync_WithVeryShortTimeout_RepeatedRuns_NeverThrowsAndAlwaysReportsTimedOut()
    {
        if (!AzureCliAvailable)
        {
            return;
        }

        var runner = new AzureCliProcessRunner();

        for (var i = 0; i < 5; i++)
        {
            var result = await runner.RunAsync(["bicep", "version"], TimeSpan.FromMilliseconds(1), CancellationToken.None);

            Assert.True(result.TimedOut);
            Assert.Equal(-1, result.ExitCode);
        }
    }

    /// <summary>
    /// Repite el escenario de cancelación del caller varias veces para verificar que, tras la
    /// corrección que espera la terminación del proceso matado, la cancelación se sigue propagando
    /// de forma consistente en cada intento (y no se pierde ni queda enmascarada por la espera
    /// agregada en KillAndWaitAsync).
    /// </summary>
    [Fact]
    public async Task RunAsync_WithPreCancelledToken_RepeatedRuns_AlwaysThrowsOperationCanceled()
    {
        if (!AzureCliAvailable)
        {
            return;
        }

        var runner = new AzureCliProcessRunner();

        for (var i = 0; i < 5; i++)
        {
            using var cts = new CancellationTokenSource();
            await cts.CancelAsync();

            await Assert.ThrowsAnyAsync<OperationCanceledException>(
                () => runner.RunAsync(["bicep", "version"], TimeSpan.FromSeconds(30), cts.Token));
        }
    }

    private sealed record HypotheticalCreateRequest : IAzureCliCommandRequest
    {
        public AzureCliOperation Operation => (AzureCliOperation)(-1);
    }

    private static bool DetectAzureCli()
    {
        try
        {
            var startInfo = OperatingSystem.IsWindows()
                ? new ProcessStartInfo("cmd.exe") { ArgumentList = { "/d", "/c", "az", "--version" } }
                : new ProcessStartInfo("az") { ArgumentList = { "--version" } };

            startInfo.UseShellExecute = false;
            startInfo.RedirectStandardOutput = true;
            startInfo.RedirectStandardError = true;
            startInfo.CreateNoWindow = true;

            using var process = Process.Start(startInfo);
            if (process is null)
            {
                return false;
            }

            process.WaitForExit(10_000);
            return process.HasExited && process.ExitCode == 0;
        }
        catch
        {
            return false;
        }
    }
}
