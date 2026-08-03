using System.Diagnostics;
using Centinela.Application.Abstractions.AzureCli;

namespace Centinela.Infrastructure.AzureCli;

/// <inheritdoc cref="IAzureCliCommandGateway"/>
public sealed class AzureCliCommandGateway : IAzureCliCommandGateway
{
    private static readonly TimeSpan DefaultTimeout = TimeSpan.FromSeconds(60);

    private readonly IAzureCliProcessRunner _processRunner;
    private readonly IAzureCliAuditSink _auditSink;

    public AzureCliCommandGateway(IAzureCliProcessRunner processRunner, IAzureCliAuditSink auditSink)
    {
        _processRunner = processRunner;
        _auditSink = auditSink;
    }

    public async Task<AzureCliCommandResult> ExecuteAsync(IAzureCliCommandRequest request, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);

        var correlationId = Guid.NewGuid().ToString("N");
        var startedAtUtc = DateTimeOffset.UtcNow;
        var stopwatch = Stopwatch.StartNew();

        IReadOnlyList<string> arguments;
        try
        {
            arguments = AzureCliCommandPolicy.BuildArguments(request);
        }
        catch (AzureCliOperationNotAllowedException ex)
        {
            stopwatch.Stop();
            _auditSink.Record(new AzureCliAuditRecord
            {
                CorrelationId = correlationId,
                TimestampUtc = startedAtUtc,
                Operation = request.Operation,
                SanitizedArguments = [],
                Allowed = false,
                DenialReason = AzureCliOutputRedactor.Redact(ex.Message),
                Duration = stopwatch.Elapsed,
            });
            throw;
        }

        var sanitizedArguments = arguments.Select(AzureCliOutputRedactor.Redact).ToArray();

        var raw = await _processRunner.RunAsync(arguments, DefaultTimeout, cancellationToken).ConfigureAwait(false);
        stopwatch.Stop();

        var result = new AzureCliCommandResult
        {
            Success = raw is { TimedOut: false, ExitCode: 0 },
            ExitCode = raw.ExitCode,
            SanitizedStandardOutput = AzureCliOutputRedactor.Redact(raw.StandardOutput),
            SanitizedStandardError = AzureCliOutputRedactor.Redact(raw.StandardError),
            Duration = stopwatch.Elapsed,
            CorrelationId = correlationId,
        };

        _auditSink.Record(new AzureCliAuditRecord
        {
            CorrelationId = correlationId,
            TimestampUtc = startedAtUtc,
            Operation = request.Operation,
            SanitizedArguments = sanitizedArguments,
            Allowed = true,
            Success = result.Success,
            ExitCode = result.ExitCode,
            Duration = result.Duration,
        });

        return result;
    }
}
