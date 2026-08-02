using Centinela.Application.Skills;
using Centinela.Domain.Enums;
using Centinela.UnitTests.TestDoubles;

namespace Centinela.UnitTests.Skills;

public class DetermineHumanHandoffSkillTests
{
    private readonly DetermineHumanHandoffSkill _skill = new();

    [Fact]
    public void Determine_AlwaysEscalates_OnComplaintIntent()
    {
        var (requiresHandoff, reason) = _skill.Determine(CustomerIntent.Complaint, SampleData.LamparaAurora, null, []);

        Assert.True(requiresHandoff);
        Assert.NotNull(reason);
    }

    [Fact]
    public void Determine_Escalates_WhenPriceIntentHasNoMatchedProduct()
    {
        var (requiresHandoff, reason) = _skill.Determine(CustomerIntent.Price, null, null, []);

        Assert.True(requiresHandoff);
        Assert.Contains("catálogo local", reason);
    }

    [Fact]
    public void Determine_DoesNotEscalate_WhenPriceIntentHasMatchedProduct()
    {
        var (requiresHandoff, reason) = _skill.Determine(CustomerIntent.Price, SampleData.LamparaAurora, null, []);

        Assert.False(requiresHandoff);
        Assert.Null(reason);
    }

    [Fact]
    public void Determine_Escalates_WhenPolicyIntentHasNoMatchedPolicy()
    {
        var (requiresHandoff, reason) = _skill.Determine(CustomerIntent.Policy, null, null, []);

        Assert.True(requiresHandoff);
        Assert.NotNull(reason);
    }

    [Fact]
    public void Determine_Escalates_WhenRecommendationHasNoCandidates()
    {
        var (requiresHandoff, reason) = _skill.Determine(CustomerIntent.Recommendation, null, null, []);

        Assert.True(requiresHandoff);
        Assert.NotNull(reason);
    }

    [Fact]
    public void Determine_DoesNotEscalate_WhenRecommendationHasCandidates()
    {
        var (requiresHandoff, reason) = _skill.Determine(
            CustomerIntent.Recommendation, null, null, [SampleData.CocinaEconomica]);

        Assert.False(requiresHandoff);
        Assert.Null(reason);
    }

    [Fact]
    public void Determine_Escalates_OnUnknownIntent_ForLowConfidenceCases()
    {
        var (requiresHandoff, reason) = _skill.Determine(CustomerIntent.Unknown, null, null, []);

        Assert.True(requiresHandoff);
        Assert.NotNull(reason);
    }
}
