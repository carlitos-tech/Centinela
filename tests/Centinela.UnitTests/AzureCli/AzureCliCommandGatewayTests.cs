using Centinela.Application.Abstractions.AzureCli;
using Centinela.Infrastructure.AzureCli;
using Centinela.UnitTests.TestDoubles;

namespace Centinela.UnitTests.AzureCli;

public class AzureCliCommandGatewayTests
{
    private readonly FakeAzureCliProcessRunner _processRunner = new();
    private readonly InMemoryAzureCliAuditSink _auditSink = new();
    private readonly AzureCliCommandGateway _gateway;

    public AzureCliCommandGatewayTests()
    {
        _gateway = new AzureCliCommandGateway(_processRunner, _auditSink);
    }

    [Fact]
    public async Task ExecuteAsync_AllowedOperation_ReturnsSuccessResult()
    {
        _processRunner.NextResult = new AzureCliRawProcessResult
        {
            ExitCode = 0,
            StandardOutput = "{\"state\":\"Registered\"}",
            StandardError = string.Empty,
            TimedOut = false,
        };

        var result = await _gateway.ExecuteAsync(new AccountShowRequest());

        Assert.True(result.Success);
        Assert.Equal(0, result.ExitCode);
        Assert.Equal("{\"state\":\"Registered\"}", result.SanitizedStandardOutput);
        Assert.NotEmpty(result.CorrelationId);
    }

    [Fact]
    public async Task ExecuteAsync_AllowedOperation_PassesArgumentsAsDiscreteTokens_NeverAsSingleString()
    {
        await _gateway.ExecuteAsync(new ProviderShowRequest { Namespace = "Microsoft.Web" });

        Assert.Equal(1, _processRunner.CallCount);
        var receivedArgs = _processRunner.ReceivedArguments[0];
        Assert.Equal(["provider", "show", "--namespace", "Microsoft.Web", "--output", "json", "--only-show-errors"], receivedArgs);
        Assert.All(receivedArgs, token => Assert.DoesNotContain(' ', token.Trim()));
    }

    [Fact]
    public async Task ExecuteAsync_UnrecognizedRequestType_ThrowsAndNeverCallsProcessRunner()
    {
        var request = new UnknownRequestForGatewayTest();

        await Assert.ThrowsAsync<AzureCliOperationNotAllowedException>(() => _gateway.ExecuteAsync(request));

        Assert.Equal(0, _processRunner.CallCount);
    }

    [Fact]
    public async Task ExecuteAsync_UnrecognizedRequestType_RecordsDeniedAuditEntry()
    {
        var request = new UnknownRequestForGatewayTest();

        await Assert.ThrowsAsync<AzureCliOperationNotAllowedException>(() => _gateway.ExecuteAsync(request));

        var record = Assert.Single(_auditSink.GetAll());
        Assert.False(record.Allowed);
        Assert.Null(record.Success);
        Assert.NotNull(record.DenialReason);
        Assert.Empty(record.SanitizedArguments);
    }

    [Fact]
    public async Task ExecuteAsync_AllowedOperation_RecordsAllowedAuditEntryWithMatchingCorrelationId()
    {
        var result = await _gateway.ExecuteAsync(new AccountShowRequest());

        var record = Assert.Single(_auditSink.GetAll());
        Assert.True(record.Allowed);
        Assert.Equal(result.CorrelationId, record.CorrelationId);
        Assert.Equal(result.Success, record.Success);
        Assert.Equal(result.ExitCode, record.ExitCode);
    }

    [Fact]
    public async Task ExecuteAsync_NonZeroExitCode_ReturnsFailureResult()
    {
        _processRunner.NextResult = new AzureCliRawProcessResult
        {
            ExitCode = 1,
            StandardOutput = string.Empty,
            StandardError = "ERROR: something went wrong",
            TimedOut = false,
        };

        var result = await _gateway.ExecuteAsync(new AccountShowRequest());

        Assert.False(result.Success);
        Assert.Equal(1, result.ExitCode);
    }

    [Fact]
    public async Task ExecuteAsync_TimedOutRawResult_ReturnsFailureResultWithNegativeExitCode()
    {
        _processRunner.NextResult = new AzureCliRawProcessResult
        {
            ExitCode = -1,
            StandardOutput = string.Empty,
            StandardError = string.Empty,
            TimedOut = true,
        };

        var result = await _gateway.ExecuteAsync(new BicepVersionRequest());

        Assert.False(result.Success);
        Assert.Equal(-1, result.ExitCode);
    }

    [Fact]
    public async Task ExecuteAsync_CancelledToken_PropagatesCancellation()
    {
        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(
            () => _gateway.ExecuteAsync(new AccountShowRequest(), cts.Token));
    }

    [Fact]
    public async Task ExecuteAsync_CancelledToken_RecordsCancelledAuditEntryBeforePropagating()
    {
        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(
            () => _gateway.ExecuteAsync(new AccountShowRequest(), cts.Token));

        var record = Assert.Single(_auditSink.GetAll());
        Assert.True(record.Allowed);
        Assert.False(record.Success);
        Assert.True(record.Cancelled);
        Assert.NotEmpty(record.CorrelationId);
        Assert.DoesNotContain(record.SanitizedArguments, a => a.Contains("Password", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task ExecuteAsync_RunnerThrowsBecauseAzCliMissing_RecordsFailedAuditEntryAndPropagatesException()
    {
        _processRunner.ResultFactory = _ => throw new System.ComponentModel.Win32Exception("No such file or directory");

        await Assert.ThrowsAsync<System.ComponentModel.Win32Exception>(() => _gateway.ExecuteAsync(new BicepVersionRequest()));

        var record = Assert.Single(_auditSink.GetAll());
        Assert.True(record.Allowed);
        Assert.False(record.Success);
        Assert.False(record.Cancelled);
        Assert.NotNull(record.FailureReason);
        Assert.NotEmpty(record.CorrelationId);
    }

    [Fact]
    public async Task ExecuteAsync_RunnerThrowsUnexpectedException_RecordsFailedAuditEntryAndPropagatesException()
    {
        _processRunner.ResultFactory = _ => throw new InvalidOperationException("fallo inesperado del runner");

        await Assert.ThrowsAsync<InvalidOperationException>(() => _gateway.ExecuteAsync(new AccountShowRequest()));

        var record = Assert.Single(_auditSink.GetAll());
        Assert.True(record.Allowed);
        Assert.False(record.Success);
        Assert.False(record.Cancelled);
        Assert.NotNull(record.FailureReason);
    }

    [Fact]
    public async Task ExecuteAsync_FailureAuditEntry_NeverContainsSecretsFromExceptionMessage()
    {
        var path = FictitiousExampleBuilder.WindowsPath();
        var guid = FictitiousExampleBuilder.Guid();
        _processRunner.ResultFactory = _ => throw new InvalidOperationException($"fallo al ejecutar {path} con tenantId {guid}");

        await Assert.ThrowsAsync<InvalidOperationException>(() => _gateway.ExecuteAsync(new AccountShowRequest()));

        var record = Assert.Single(_auditSink.GetAll());
        Assert.DoesNotContain("devuser", record.FailureReason);
        Assert.DoesNotContain(guid, record.FailureReason);
    }

    [Fact]
    public async Task ExecuteAsync_OutputContainingSecrets_IsRedactedBeforeReturning()
    {
        var guid = FictitiousExampleBuilder.Guid();
        var email = FictitiousExampleBuilder.Email("admin.novacasa");

        _processRunner.NextResult = new AzureCliRawProcessResult
        {
            ExitCode = 0,
            StandardOutput = $"tenantId: {guid}, contact: {email}",
            StandardError = "AccountKey=SuperSecretValue123",
            TimedOut = false,
        };

        var result = await _gateway.ExecuteAsync(new AccountShowRequest());

        Assert.DoesNotContain(guid, result.SanitizedStandardOutput);
        Assert.DoesNotContain(email, result.SanitizedStandardOutput);
        Assert.DoesNotContain("SuperSecretValue123", result.SanitizedStandardError);
    }

    [Fact]
    public async Task ExecuteAsync_AuditRecord_NeverContainsSecretsFromArguments()
    {
        _processRunner.NextResult = new AzureCliRawProcessResult
        {
            ExitCode = 0,
            StandardOutput = string.Empty,
            StandardError = string.Empty,
            TimedOut = false,
        };

        await _gateway.ExecuteAsync(new DeploymentSubValidateRequest
        {
            Location = "eastus2",
            TemplateFile = "infra/main.bicep",
            ParametersFile = "infra/dev.bicepparam",
        });

        var record = Assert.Single(_auditSink.GetAll());
        Assert.All(record.SanitizedArguments, arg =>
        {
            Assert.DoesNotContain("Password", arg, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("Secret", arg, StringComparison.OrdinalIgnoreCase);
        });
    }

    [Fact]
    public async Task ExecuteAsync_NullRequest_ThrowsArgumentNullException()
    {
        await Assert.ThrowsAsync<ArgumentNullException>(() => _gateway.ExecuteAsync(null!));
    }

    private sealed record UnknownRequestForGatewayTest : IAzureCliCommandRequest
    {
        public AzureCliOperation Operation => (AzureCliOperation)(-1);
    }
}
