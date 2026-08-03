using System.Diagnostics;
using System.Text;

namespace Centinela.Infrastructure.AzureCli;

/// <summary>
/// Ejecuta el binario `az` sin intérprete de shell interactivo, usando
/// <see cref="ProcessStartInfo.ArgumentList"/> para que cada argumento viaje como un token
/// independiente. No expone ningún método para ejecutar comandos arbitrarios: solo recibe la
/// lista de argumentos ya construida y validada por <c>AzureCliCommandPolicy</c>. Nunca agrega
/// `--debug` ni imprime variables de entorno.
/// </summary>
public sealed class AzureCliProcessRunner : IAzureCliProcessRunner
{
    private const int MaxOutputChars = 200_000;

    public async Task<AzureCliRawProcessResult> RunAsync(
        IReadOnlyList<string> arguments,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var startInfo = BuildStartInfo(arguments);

        using var process = new Process { StartInfo = startInfo };
        using var timeoutCts = new CancellationTokenSource(timeout);
        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeoutCts.Token);

        var stdOut = new StringBuilder();
        var stdErr = new StringBuilder();
        var stdOutTruncated = false;
        var stdErrTruncated = false;

        process.OutputDataReceived += (_, e) => AppendBounded(stdOut, e.Data, ref stdOutTruncated);
        process.ErrorDataReceived += (_, e) => AppendBounded(stdErr, e.Data, ref stdErrTruncated);

        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        var timedOut = false;
        try
        {
            await process.WaitForExitAsync(linkedCts.Token).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            timedOut = timeoutCts.IsCancellationRequested && !cancellationToken.IsCancellationRequested;
            TryKill(process);

            if (!timedOut)
            {
                throw;
            }
        }

        return new AzureCliRawProcessResult
        {
            ExitCode = timedOut ? -1 : process.ExitCode,
            StandardOutput = stdOut.ToString(),
            StandardError = stdErr.ToString(),
            TimedOut = timedOut,
        };
    }

    private static void AppendBounded(StringBuilder builder, string? line, ref bool truncated)
    {
        if (line is null || truncated)
        {
            return;
        }

        if (builder.Length + line.Length > MaxOutputChars)
        {
            var remaining = Math.Max(0, MaxOutputChars - builder.Length);
            builder.Append(line.AsSpan(0, remaining));
            builder.Append("\n[SALIDA TRUNCADA: límite de tamaño alcanzado]");
            truncated = true;
            return;
        }

        builder.AppendLine(line);
    }

    private static void TryKill(Process process)
    {
        try
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
            }
        }
        catch
        {
            // El proceso ya pudo haber terminado entre la verificación y el intento de matarlo.
        }
    }

    private static ProcessStartInfo BuildStartInfo(IReadOnlyList<string> arguments)
    {
        ProcessStartInfo startInfo;

        if (OperatingSystem.IsWindows())
        {
            // Azure CLI se instala en Windows como script `az.cmd`, que el sistema operativo solo
            // puede ejecutar a través de cmd.exe (CreateProcess no puede cargar un .cmd como imagen
            // nativa). cmd.exe se invoca únicamente como lanzador obligatorio del script, con `/d`
            // (sin AutoRun) y `/c`; no se construye ninguna cadena de comando libre: cada argumento
            // sigue viajando como un token independiente de ArgumentList, y la política de comandos
            // ya validó su contenido antes de llegar aquí.
            startInfo = new ProcessStartInfo("cmd.exe") { UseShellExecute = false };
            startInfo.ArgumentList.Add("/d");
            startInfo.ArgumentList.Add("/c");
            startInfo.ArgumentList.Add("az");
        }
        else
        {
            startInfo = new ProcessStartInfo("az") { UseShellExecute = false };
        }

        foreach (var argument in arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

        startInfo.RedirectStandardOutput = true;
        startInfo.RedirectStandardError = true;
        startInfo.CreateNoWindow = true;

        return startInfo;
    }
}
