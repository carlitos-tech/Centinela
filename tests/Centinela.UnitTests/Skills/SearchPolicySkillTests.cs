using Centinela.Application.Skills;
using Centinela.Domain.Entities;
using Centinela.UnitTests.TestDoubles;

namespace Centinela.UnitTests.Skills;

public class SearchPolicySkillTests
{
    private readonly SearchPolicySkill _skill = new(
        new FakePolicyRepository([SampleData.PoliticaDevoluciones]));

    [Fact]
    public void FindByMessage_ReturnsPolicy_WhenMessageMatchesKeyword()
    {
        var result = _skill.FindByMessage("¿Cuál es la política de devoluciones?");

        Assert.NotNull(result);
        Assert.Equal("devoluciones", result!.Topic);
    }

    [Fact]
    public void FindByMessage_ReturnsNull_WhenNoLocalPolicyCoversTheQuery()
    {
        var result = _skill.FindByMessage("¿Hacen instalaciones a domicilio?");

        Assert.Null(result);
    }

    [Fact]
    public void FindByMessage_ReturnsNull_WhenKeywordOnlyMatchesAsArbitrarySubstring()
    {
        var skill = new SearchPolicySkill(new FakePolicyRepository([
            new()
            {
                Topic = "pagos",
                Title = "Política de pagos",
                Content = "Aceptamos pagos con tarjeta o efectivo.",
                Keywords = ["pago", "pagos"],
                Source = "Políticas locales NovaCasa S.A.S. - pagos",
            },
        ]));

        var result = skill.FindByMessage("La lámpara se apagó, ¿qué hago?");

        Assert.Null(result);
    }
}
