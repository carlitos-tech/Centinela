using Centinela.Infrastructure.AzureCli;

namespace Centinela.UnitTests.AzureCli;

public class AzureCliOutputRedactorTests
{
    [Fact]
    public void Redact_Guid_IsMasked()
    {
        var guid = FictitiousExampleBuilder.Guid();

        var redacted = AzureCliOutputRedactor.Redact($"tenantId: {guid}");

        Assert.DoesNotContain(guid, redacted);
        Assert.Contains("[REDACTED-GUID]", redacted);
    }

    [Fact]
    public void Redact_Email_IsMasked()
    {
        var email = FictitiousExampleBuilder.Email();

        var redacted = AzureCliOutputRedactor.Redact($"contacto: {email}");

        Assert.DoesNotContain(email, redacted);
        Assert.Contains("[REDACTED-EMAIL]", redacted);
    }

    [Theory]
    [InlineData("AccountKey=abc123XYZ+/==")]
    [InlineData("SharedAccessKey=someSecretValue")]
    [InlineData("Password=Sup3rSecret!")]
    [InlineData("Pwd=Sup3rSecret!")]
    public void Redact_ConnectionStringKeys_AreMasked(string input)
    {
        var redacted = AzureCliOutputRedactor.Redact(input);

        Assert.Contains("[REDACTED]", redacted);
        Assert.DoesNotContain("Sup3rSecret", redacted, StringComparison.Ordinal);
        Assert.DoesNotContain("abc123XYZ", redacted, StringComparison.Ordinal);
        Assert.DoesNotContain("someSecretValue", redacted, StringComparison.Ordinal);
    }

    [Fact]
    public void Redact_BearerToken_IsMasked()
    {
        var redacted = AzureCliOutputRedactor.Redact("Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig");

        Assert.DoesNotContain("eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9", redacted);
        Assert.Contains("Bearer [REDACTED-TOKEN]", redacted);
    }

    [Theory]
    [InlineData("\"accessToken\": \"secretvalue\"")]
    [InlineData("\"token\": \"secretvalue\"")]
    [InlineData("\"password\": \"secretvalue\"")]
    [InlineData("\"secret\": \"secretvalue\"")]
    [InlineData("\"apiKey\": \"secretvalue\"")]
    [InlineData("\"api_key\": \"secretvalue\"")]
    [InlineData("\"connectionString\": \"secretvalue\"")]
    [InlineData("\"clientSecret\": \"secretvalue\"")]
    public void Redact_JsonSecretFields_AreMasked(string json)
    {
        var redacted = AzureCliOutputRedactor.Redact(json);

        Assert.DoesNotContain("secretvalue", redacted);
        Assert.Contains("[REDACTED]", redacted);
    }

    [Fact]
    public void Redact_WindowsLocalPath_IsMasked()
    {
        var path = FictitiousExampleBuilder.WindowsPath();

        var redacted = AzureCliOutputRedactor.Redact($"al ejecutar {path} falló");

        Assert.DoesNotContain(path, redacted);
        Assert.Contains("[REDACTED-PATH]", redacted);
    }

    [Fact]
    public void Redact_HomeLocalPath_IsMasked()
    {
        var path = FictitiousExampleBuilder.HomePath();

        var redacted = AzureCliOutputRedactor.Redact(path);

        Assert.DoesNotContain("devuser", redacted);
        Assert.Contains("[REDACTED-PATH]", redacted);
    }

    [Fact]
    public void Redact_UsersLocalPath_IsMasked()
    {
        var path = FictitiousExampleBuilder.UsersPath();

        var redacted = AzureCliOutputRedactor.Redact(path);

        Assert.DoesNotContain("devuser", redacted);
        Assert.Contains("[REDACTED-PATH]", redacted);
    }

    [Fact]
    public void Redact_NullOrEmpty_ReturnsEmpty()
    {
        Assert.Equal(string.Empty, AzureCliOutputRedactor.Redact(null));
        Assert.Equal(string.Empty, AzureCliOutputRedactor.Redact(string.Empty));
    }

    [Fact]
    public void Redact_PlainTextWithoutSecrets_IsUnchanged()
    {
        const string plain = "Bicep CLI version 0.46.1 (545b338e2c)";

        var redacted = AzureCliOutputRedactor.Redact(plain);

        Assert.Equal(plain, redacted);
    }

    [Fact]
    public void Redact_MultiplePatternsInSameText_AreAllMasked()
    {
        var guid = FictitiousExampleBuilder.Guid();
        var email = FictitiousExampleBuilder.Email();

        var input = $"tenantId={guid}; contact={email}; " +
                    "AccountKey=abc123; Authorization: Bearer tok123";

        var redacted = AzureCliOutputRedactor.Redact(input);

        Assert.DoesNotContain(guid, redacted);
        Assert.DoesNotContain(email, redacted);
        Assert.DoesNotContain("abc123", redacted);
        Assert.DoesNotContain("tok123", redacted);
    }
}
