using System.Globalization;
using System.Text.RegularExpressions;
using Centinela.Application.Abstractions;
using Centinela.Application.Common;
using Centinela.Domain.Entities;
using Centinela.Domain.Enums;

namespace Centinela.Application.Skills;

/// <summary>
/// Skill: recomienda productos reales del catálogo local según la necesidad (categoría, nombre o
/// caso de uso) y el presupuesto expresado por el cliente. Nunca propone productos fuera del
/// catálogo local: si la necesidad indicada no coincide con ninguna categoría, nombre o caso de
/// uso del catálogo, no se recomienda ningún producto solo porque encaje en el presupuesto.
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
        var budget = ExtractBudget(normalizedMessage);

        var matchingProducts = _catalogRepository.GetAll()
            .Where(product => product.Availability != ProductAvailability.OutOfStock)
            .Where(product => MatchesCustomerNeed(product, normalizedMessage))
            .ToList();

        if (matchingProducts.Count == 0)
        {
            return [];
        }

        IEnumerable<Product> candidates = matchingProducts;
        if (budget.HasValue)
        {
            candidates = candidates.Where(product => product.Price <= budget.Value);
        }

        return candidates
            .OrderBy(product => product.Price)
            .Take(MaxCandidates)
            .ToList();
    }

    /// <summary>
    /// Un producto coincide con la necesidad del cliente solo si el mensaje menciona, como
    /// palabra o frase completa, su categoría, su nombre o alguno de sus casos de uso declarados
    /// en el catálogo local. El presupuesto nunca es, por sí solo, motivo de coincidencia.
    /// </summary>
    private static bool MatchesCustomerNeed(Product product, string normalizedMessage)
    {
        var candidateTerms = new List<string>(product.UseCases.Count + 2)
        {
            product.Category,
            product.Name,
        };
        candidateTerms.AddRange(product.UseCases);

        return TextNormalizer.ContainsAny(normalizedMessage, candidateTerms);
    }

    /// <summary>
    /// Extrae el presupuesto asociado a frases explícitas ("presupuesto de", "presupuesto máximo
    /// de", "máximo de", "máximo", "hasta") tomando el número que aparece después de la frase.
    /// Ignora cualquier otro número presente en el mensaje (p. ej. una cantidad de productos
    /// mencionada antes de la frase de presupuesto). No realiza ninguna conversión de moneda: los
    /// dígitos se interpretan tal como aparecen, sin importar el símbolo o sufijo de moneda.
    /// </summary>
    private static decimal? ExtractBudget(string normalizedMessage)
    {
        var keywordMatch = BudgetKeywordRegex().Match(normalizedMessage);
        if (!keywordMatch.Success)
        {
            return null;
        }

        var remainder = normalizedMessage[(keywordMatch.Index + keywordMatch.Length)..];
        var numberMatch = NumberRegex().Match(remainder);
        if (!numberMatch.Success)
        {
            return null;
        }

        var digitsOnly = new string(numberMatch.Value.Where(char.IsDigit).ToArray());
        return digitsOnly.Length == 0 ? null : decimal.Parse(digitsOnly, CultureInfo.InvariantCulture);
    }

    [GeneratedRegex(@"presupuesto\s+maximo\s+de|presupuesto\s+de|maximo\s+de|maximo|hasta")]
    private static partial Regex BudgetKeywordRegex();

    [GeneratedRegex(@"\d{1,3}(?:[.,]\d{3})+|\d+")]
    private static partial Regex NumberRegex();
}
