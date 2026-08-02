using Centinela.Domain.Enums;
using Centinela.Infrastructure.Gateways;
using Centinela.UnitTests.TestDoubles;

namespace Centinela.UnitTests.Gateways;

public class FakeModelGatewayTests
{
    private readonly FakeModelGateway _gateway = new();

    [Theory]
    [InlineData("Tengo un reclamo, el producto llegó dañado", CustomerIntent.Complaint)]
    [InlineData("¿Cuál es la política de devoluciones?", CustomerIntent.Policy)]
    [InlineData("Recomiéndame algo para organizar la sala", CustomerIntent.Recommendation)]
    [InlineData("¿Qué características tiene la Lámpara Aurora?", CustomerIntent.Features)]
    [InlineData("¿Hay disponibilidad de la Lámpara Aurora?", CustomerIntent.Availability)]
    [InlineData("¿Cuánto cuesta la Lámpara Aurora?", CustomerIntent.Price)]
    [InlineData("Hola, buenos días", CustomerIntent.Unknown)]
    public void ClassifyIntent_MatchesExpectedIntent(string message, CustomerIntent expected)
    {
        var result = _gateway.ClassifyIntent(message);

        Assert.Equal(expected, result);
    }

    [Fact]
    public void ClassifyIntent_PrioritizesComplaintOverPolicyKeywords()
    {
        var result = _gateway.ClassifyIntent("Estoy molesto por la política de devoluciones, el producto llegó dañado");

        Assert.Equal(CustomerIntent.Complaint, result);
    }

    [Fact]
    public void ClassifyIntent_DoesNotMatchPolicyKeyword_AsArbitrarySubstring()
    {
        var result = _gateway.ClassifyIntent("La lámpara se apagó, ¿qué hago?");

        Assert.Equal(CustomerIntent.Unknown, result);
    }

    [Fact]
    public void SummarizeForHumanHandoff_DoesNotDuplicateTrailingPeriod()
    {
        var summary = _gateway.SummarizeForHumanHandoff(
            "¿Tienen escritorios gamer?",
            CustomerIntent.Availability,
            "Producto no encontrado en el catálogo local.");

        Assert.DoesNotContain("..", summary);
    }

    [Fact]
    public void SummarizeForHumanHandoff_IncludesOriginalCustomerMessage_SoHumanDoesNotAskAgain()
    {
        const string originalMessage = "¿Tienen escritorios gamer?";

        var summary = _gateway.SummarizeForHumanHandoff(originalMessage, CustomerIntent.Availability, "Producto no encontrado.");

        Assert.Contains(originalMessage, summary);
    }

    [Fact]
    public void SelectControlledResponse_Price_OnlyUsesInjectedFacts()
    {
        var facts = new Dictionary<string, string> { ["productName"] = "Lámpara Aurora", ["price"] = "89.000" };

        var response = _gateway.SelectControlledResponse(CustomerIntent.Price, facts);

        Assert.Contains("Lámpara Aurora", response);
        Assert.Contains("89.000", response);
    }
}
