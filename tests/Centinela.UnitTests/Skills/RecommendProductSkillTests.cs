using Centinela.Application.Skills;
using Centinela.UnitTests.TestDoubles;

namespace Centinela.UnitTests.Skills;

public class RecommendProductSkillTests
{
    private readonly RecommendProductSkill _skill = new(
        new FakeCatalogRepository([
            SampleData.LamparaAurora,
            SampleData.CocinaEconomica,
            SampleData.CocinaPremiumFueraDePresupuesto,
            SampleData.MuebleAgotado,
        ]));

    [Fact]
    public void Recommend_FiltersByCategory_WhenMessageMentionsCategory()
    {
        var result = _skill.Recommend("Necesito algo para la cocina");

        Assert.All(result, product => Assert.Equal("Cocina", product.Category));
    }

    [Fact]
    public void Recommend_FiltersByBudget_ExcludingProductsAboveIt()
    {
        var result = _skill.Recommend("Necesito algo para la cocina con presupuesto de 150.000");

        Assert.Contains(result, p => p.Code == "COC-001");
        Assert.DoesNotContain(result, p => p.Code == "COC-004");
    }

    [Fact]
    public void Recommend_NeverIncludesOutOfStockProducts()
    {
        var result = _skill.Recommend("Necesito muebles");

        Assert.DoesNotContain(result, p => p.Code == "MUE-001");
    }

    [Fact]
    public void Recommend_NeverProposesProductsOutsideLocalCatalog()
    {
        var result = _skill.Recommend("Necesito un escritorio gamer con presupuesto de 100.000");

        Assert.All(result, product => Assert.Contains(product.Code, new[] { "LAM-001", "COC-001", "COC-004", "MUE-001" }));
    }
}
