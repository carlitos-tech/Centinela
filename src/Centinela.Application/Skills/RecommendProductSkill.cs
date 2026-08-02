using System.Globalization;
using System.Text.RegularExpressions;
using Centinela.Application.Abstractions;
using Centinela.Application.Common;
using Centinela.Domain.Entities;
using Centinela.Domain.Enums;

namespace Centinela.Application.Skills;

/// <summary>
/// Skill: recomienda productos reales del catálogo local según la necesidad (categoría) y el
/// presupuesto expresado por el cliente. Nunca propone productos fuera del catálogo local.
/// </summary>
public sealed partial class RecommendProductSkill
{
    public const string SkillName = nameof(RecommendProductSkill);
    private const int MaxCandidates = 3;

    private readonly ICatalogRepository _catalogRepository;

    public RecommendProductSkill(ICatalogRepository catalogRepository)
    {
        _catalogRepository = catalogRepository;
    }

    public IReadOnlyList<Product> Recommend(string customerMessage)
    {
        var normalizedMessage = TextNormalizer.Normalize(customerMessage);
        var budget = ExtractBudget(customerMessage);

        IEnumerable<Product> candidates = _catalogRepository.GetAll()
            .Where(product => product.Availability != ProductAvailability.OutOfStock);

        var categoryMatches = candidates
            .Where(product => normalizedMessage.Contains(TextNormalizer.Normalize(product.Category), StringComparison.Ordinal))
            .ToList();

        if (categoryMatches.Count > 0)
        {
            candidates = categoryMatches;
        }

        if (budget.HasValue)
        {
            candidates = candidates.Where(product => product.Price <= budget.Value);
        }

        return candidates
            .OrderBy(product => product.Price)
            .Take(MaxCandidates)
            .ToList();
    }

    private static decimal? ExtractBudget(string customerMessage)
    {
        var match = BudgetRegex().Match(customerMessage);
        if (!match.Success)
        {
            return null;
        }

        var digitsOnly = new string(match.Value.Where(char.IsDigit).ToArray());
        return digitsOnly.Length == 0 ? null : decimal.Parse(digitsOnly, CultureInfo.InvariantCulture);
    }

    [GeneratedRegex(@"\d{1,3}(?:[.,]\d{3})+|\d+")]
    private static partial Regex BudgetRegex();
}
