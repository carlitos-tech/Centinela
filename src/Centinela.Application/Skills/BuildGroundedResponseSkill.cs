using System.Globalization;
using Centinela.Application.Abstractions;
using Centinela.Domain.Entities;
using Centinela.Domain.Enums;

namespace Centinela.Application.Skills;

/// <summary>
/// Skill: construye la respuesta final fundamentada y sus referencias de fuente.
/// Regla antialucinación: cuando no hay información suficiente, nunca la inventa —
/// devuelve un mensaje fijo de seguridad y cero fuentes, dejando la señal de
/// escalamiento a cargo de DetermineHumanHandoffSkill.
/// </summary>
public sealed class BuildGroundedResponseSkill
{
    public const string SkillName = nameof(BuildGroundedResponseSkill);

    private static readonly CultureInfo Currency = CultureInfo.GetCultureInfo("es-CO");

    private readonly IModelGateway _modelGateway;

    public BuildGroundedResponseSkill(IModelGateway modelGateway)
    {
        _modelGateway = modelGateway;
    }

    public (string Message, IReadOnlyList<SourceReference> Sources) Build(
        CustomerIntent intent,
        Product? matchedProduct,
        BusinessPolicy? matchedPolicy,
        IReadOnlyList<Product> recommendationCandidates)
    {
        return intent switch
        {
            CustomerIntent.Price => matchedProduct is not null
                ? (BuildPriceResponse(matchedProduct), [ToSource(matchedProduct)])
                : (NotFoundMessage(), []),

            CustomerIntent.Availability => matchedProduct is not null
                ? (BuildAvailabilityResponse(matchedProduct), [ToSource(matchedProduct)])
                : (NotFoundMessage(), []),

            CustomerIntent.Features => matchedProduct is not null
                ? (BuildFeaturesResponse(matchedProduct), [ToSource(matchedProduct)])
                : (NotFoundMessage(), []),

            CustomerIntent.Policy => matchedPolicy is not null
                ? (BuildPolicyResponse(matchedPolicy), [ToSource(matchedPolicy)])
                : (PolicyNotFoundMessage(), []),

            CustomerIntent.Recommendation => recommendationCandidates.Count > 0
                ? (_modelGateway.BuildRecommendationNarrative(recommendationCandidates, string.Empty), recommendationCandidates.Select(ToSource).ToArray())
                : (RecommendationNotFoundMessage(), []),

            CustomerIntent.Complaint => (BuildComplaintResponse(), []),

            _ => (UnknownIntentMessage(), []),
        };
    }

    public string BuildHumanSummary(string customerMessage, CustomerIntent intent, string handoffReason)
        => _modelGateway.SummarizeForHumanHandoff(customerMessage, intent, handoffReason);

    private string BuildPriceResponse(Product product)
    {
        var facts = new Dictionary<string, string>
        {
            ["productName"] = product.Name,
            ["price"] = product.Price.ToString("N0", Currency),
        };
        return _modelGateway.SelectControlledResponse(CustomerIntent.Price, facts);
    }

    private string BuildAvailabilityResponse(Product product)
    {
        var facts = new Dictionary<string, string>
        {
            ["productName"] = product.Name,
            ["availability"] = DescribeAvailability(product.Availability),
        };
        return _modelGateway.SelectControlledResponse(CustomerIntent.Availability, facts);
    }

    private string BuildFeaturesResponse(Product product)
    {
        var facts = new Dictionary<string, string>
        {
            ["productName"] = product.Name,
            ["features"] = string.Join(", ", product.Features),
        };
        return _modelGateway.SelectControlledResponse(CustomerIntent.Features, facts);
    }

    private string BuildPolicyResponse(BusinessPolicy policy)
    {
        var facts = new Dictionary<string, string>
        {
            ["policyTopic"] = policy.Title,
            ["policyContent"] = policy.Content,
        };
        return _modelGateway.SelectControlledResponse(CustomerIntent.Policy, facts);
    }

    private string BuildComplaintResponse()
        => _modelGateway.SelectControlledResponse(CustomerIntent.Complaint, new Dictionary<string, string>());

    private static string DescribeAvailability(ProductAvailability availability) => availability switch
    {
        ProductAvailability.InStock => "disponible en inventario",
        ProductAvailability.Limited => "disponibilidad limitada (existencias reducidas)",
        ProductAvailability.OutOfStock => "agotado temporalmente",
        _ => "sin información de disponibilidad",
    };

    private static SourceReference ToSource(Product product) => new()
    {
        Type = "Catalog",
        Id = product.Code,
        Description = product.Source,
    };

    private static SourceReference ToSource(BusinessPolicy policy) => new()
    {
        Type = "Policy",
        Id = policy.Topic,
        Description = policy.Source,
    };

    private static string NotFoundMessage() =>
        "No encontramos ese producto en el catálogo local de NovaCasa S.A.S. Para no darte información incorrecta, tu caso será revisado por una persona del equipo.";

    private static string PolicyNotFoundMessage() =>
        "No encontramos una política local de NovaCasa S.A.S. que cubra tu consulta. Tu caso será revisado por una persona del equipo.";

    private static string RecommendationNotFoundMessage() =>
        "No encontramos productos del catálogo local que cumplan la necesidad o el presupuesto indicado. Tu caso será revisado por una persona del equipo.";

    private static string UnknownIntentMessage() =>
        "No tenemos información suficiente para responder tu consulta con confianza. Tu caso será revisado por una persona del equipo.";
}
