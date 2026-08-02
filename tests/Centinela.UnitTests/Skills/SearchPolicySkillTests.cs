using Centinela.Application.Skills;
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
}
