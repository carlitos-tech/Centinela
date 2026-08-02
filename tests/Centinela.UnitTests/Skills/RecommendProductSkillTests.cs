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

        Assert.NotEmpty(result);
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
        var result = _skill.Recommend("Necesito muebles para almacenamiento");

        Assert.DoesNotContain(result, p => p.Code == "MUE-001");
    }

    [Fact]
    public void Recommend_ReturnsNoCandidates_WhenNeedDoesNotMatchAnyCatalogCategoryNameOrUseCase()
    {
        var result = _skill.Recommend("Recomiéndame un escritorio gamer con presupuesto de 100.000");

        Assert.Empty(result);
    }

    [Fact]
    public void Recommend_DoesNotFallBackToFullCatalog_WhenNoCategoryMatches_EvenIfBudgetFits()
    {
        var result = _skill.Recommend("Necesito un escritorio gamer con presupuesto de 500.000");

        Assert.Empty(result);
    }

    [Theory]
    [InlineData("Necesito algo para la cocina con presupuesto de 150000")]
    [InlineData("Necesito algo para la cocina con presupuesto de 150.000")]
    [InlineData("Necesito algo para la cocina con presupuesto de $150.000")]
    [InlineData("Necesito algo para la cocina con presupuesto máximo de 150.000")]
    [InlineData("Necesito algo para la cocina con máximo 150.000")]
    [InlineData("Necesito algo para la cocina hasta 150.000")]
    public void Recommend_ParsesBudget_AcrossNumberFormatsAndPhraseVariants(string message)
    {
        var result = _skill.Recommend(message);

        Assert.Contains(result, p => p.Code == "COC-001");
        Assert.DoesNotContain(result, p => p.Code == "COC-004");
    }

    [Fact]
    public void Recommend_DoesNotMisreadAnUnrelatedLeadingNumber_AsTheBudget()
    {
        var result = _skill.Recommend("Recomiéndame 2 productos de cocina con presupuesto de 150.000");

        Assert.Contains(result, p => p.Code == "COC-001");
        Assert.DoesNotContain(result, p => p.Code == "COC-004");
    }

    [Fact]
    public void Recommend_IncludesAllMatchingProductsRegardlessOfPrice_WhenMessageHasNoBudget()
    {
        var result = _skill.Recommend("Necesito algo para la cocina");

        Assert.Contains(result, p => p.Code == "COC-001");
        Assert.Contains(result, p => p.Code == "COC-004");
    }
}
