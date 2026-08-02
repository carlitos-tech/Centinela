using Centinela.Application.Skills;
using Centinela.Domain.Enums;
using Centinela.Infrastructure.Gateways;
using Centinela.UnitTests.TestDoubles;

namespace Centinela.UnitTests.Skills;

public class BuildGroundedResponseSkillTests
{
    private readonly BuildGroundedResponseSkill _skill = new(new FakeModelGateway());

    [Fact]
    public void Build_ReturnsSourceCitingTheProduct_WhenPriceIntentMatchesProduct()
    {
        var (message, sources) = _skill.Build(CustomerIntent.Price, SampleData.LamparaAurora, null, []);

        Assert.Contains("Lámpara Aurora", message);
        Assert.Single(sources);
        Assert.Equal("LAM-001", sources[0].Id);
    }

    [Fact]
    public void Build_ReturnsFixedSafetyMessageWithNoSources_WhenProductNotFound()
    {
        var (message, sources) = _skill.Build(CustomerIntent.Price, null, null, []);

        Assert.Empty(sources);
        Assert.Contains("No encontramos ese producto", message);
    }

    [Fact]
    public void Build_ReturnsFixedSafetyMessageWithNoSources_WhenPolicyNotFound()
    {
        var (message, sources) = _skill.Build(CustomerIntent.Policy, null, null, []);

        Assert.Empty(sources);
        Assert.Contains("No encontramos una política local", message);
    }

    [Fact]
    public void Build_CitesEveryRecommendedProduct_WhenRecommendationHasCandidates()
    {
        IReadOnlyList<Centinela.Domain.Entities.Product> candidates =
            [SampleData.LamparaAurora, SampleData.CocinaEconomica];

        var (_, sources) = _skill.Build(CustomerIntent.Recommendation, null, null, candidates);

        Assert.Equal(2, sources.Count);
        Assert.Contains(sources, s => s.Id == "LAM-001");
        Assert.Contains(sources, s => s.Id == "COC-001");
    }

    [Fact]
    public void Build_ReturnsFixedSafetyMessageWithNoSources_OnUnknownIntent()
    {
        var (message, sources) = _skill.Build(CustomerIntent.Unknown, null, null, []);

        Assert.Empty(sources);
        Assert.Contains("No tenemos información suficiente", message);
    }
}
