using Centinela.Application.Abstractions;
using Centinela.Application.Contracts;
using Centinela.Application.Skills;
using Centinela.Domain.Entities;
using Centinela.Domain.Enums;

namespace Centinela.Application.Plugins;

/// <summary>
/// Plugin de atención al cliente (nivel "Plugin" de la jerarquía Proyecto → Agentes → Plugins →
/// Skills → Artifacts). Orquesta las skills mínimas de esta fase. Ningún otro plugin existe
/// todavía: los planeados para fases posteriores no se simulan aquí.
/// </summary>
public sealed class CustomerServicePlugin : ICustomerServicePlugin
{
    public const string PluginName = nameof(CustomerServicePlugin);

    private readonly ClassifyIntentSkill _classifyIntentSkill;
    private readonly SearchCatalogSkill _searchCatalogSkill;
    private readonly SearchPolicySkill _searchPolicySkill;
    private readonly RecommendProductSkill _recommendProductSkill;
    private readonly BuildGroundedResponseSkill _buildGroundedResponseSkill;
    private readonly DetermineHumanHandoffSkill _determineHumanHandoffSkill;

    public CustomerServicePlugin(
        ClassifyIntentSkill classifyIntentSkill,
        SearchCatalogSkill searchCatalogSkill,
        SearchPolicySkill searchPolicySkill,
        RecommendProductSkill recommendProductSkill,
        BuildGroundedResponseSkill buildGroundedResponseSkill,
        DetermineHumanHandoffSkill determineHumanHandoffSkill)
    {
        _classifyIntentSkill = classifyIntentSkill;
        _searchCatalogSkill = searchCatalogSkill;
        _searchPolicySkill = searchPolicySkill;
        _recommendProductSkill = recommendProductSkill;
        _buildGroundedResponseSkill = buildGroundedResponseSkill;
        _determineHumanHandoffSkill = determineHumanHandoffSkill;
    }

    public Task<PluginResult> HandleAsync(string conversationId, string customerMessage, CancellationToken cancellationToken = default)
    {
        var skillsUsed = new List<string> { ClassifyIntentSkill.SkillName };
        var intent = _classifyIntentSkill.Classify(customerMessage);

        Product? matchedProduct = null;
        BusinessPolicy? matchedPolicy = null;
        IReadOnlyList<Product> recommendationCandidates = [];

        switch (intent)
        {
            case CustomerIntent.Price:
            case CustomerIntent.Availability:
            case CustomerIntent.Features:
                skillsUsed.Add(SearchCatalogSkill.SkillName);
                matchedProduct = _searchCatalogSkill.FindByMessage(customerMessage);
                break;

            case CustomerIntent.Policy:
                skillsUsed.Add(SearchPolicySkill.SkillName);
                matchedPolicy = _searchPolicySkill.FindByMessage(customerMessage);
                break;

            case CustomerIntent.Recommendation:
                skillsUsed.Add(RecommendProductSkill.SkillName);
                recommendationCandidates = _recommendProductSkill.Recommend(customerMessage);
                break;

            case CustomerIntent.Complaint:
            case CustomerIntent.Unknown:
            default:
                break;
        }

        skillsUsed.Add(DetermineHumanHandoffSkill.SkillName);
        var (requiresHandoff, handoffReason) = _determineHumanHandoffSkill.Determine(
            intent, matchedProduct, matchedPolicy, recommendationCandidates);

        skillsUsed.Add(BuildGroundedResponseSkill.SkillName);
        var (responseMessage, sources) = _buildGroundedResponseSkill.Build(
            intent, matchedProduct, matchedPolicy, recommendationCandidates);

        string? humanSummary = null;
        if (requiresHandoff)
        {
            humanSummary = _buildGroundedResponseSkill.BuildHumanSummary(customerMessage, intent, handoffReason!);
        }

        var result = new PluginResult
        {
            ResponseMessage = responseMessage,
            Intent = intent,
            Sources = sources,
            RequiresHumanHandoff = requiresHandoff,
            HandoffReason = handoffReason,
            HumanSummary = humanSummary,
            SkillsUsed = skillsUsed,
        };

        return Task.FromResult(result);
    }
}
