using Centinela.Application.Skills;
using Centinela.UnitTests.TestDoubles;

namespace Centinela.UnitTests.Skills;

public class SearchCatalogSkillTests
{
    private readonly SearchCatalogSkill _skill = new(
        new FakeCatalogRepository([SampleData.LamparaAurora, SampleData.CocinaEconomica]));

    [Fact]
    public void FindByMessage_ReturnsProduct_WhenMessageMentionsProductName()
    {
        var result = _skill.FindByMessage("¿Cuánto cuesta la Lámpara Aurora?");

        Assert.NotNull(result);
        Assert.Equal("LAM-001", result!.Code);
    }

    [Fact]
    public void FindByMessage_ReturnsProduct_WhenMessageMentionsProductCode()
    {
        var result = _skill.FindByMessage("Quiero información del producto LAM-001");

        Assert.NotNull(result);
        Assert.Equal("Lámpara Aurora", result!.Name);
    }

    [Fact]
    public void FindByMessage_ReturnsNull_WhenProductDoesNotExistInLocalCatalog()
    {
        var result = _skill.FindByMessage("¿Tienen escritorios gamer?");

        Assert.Null(result);
    }
}
