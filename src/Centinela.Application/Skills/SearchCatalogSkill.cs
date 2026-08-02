using Centinela.Application.Abstractions;
using Centinela.Application.Common;
using Centinela.Domain.Entities;

namespace Centinela.Application.Skills;

/// <summary>
/// Skill: busca en el catálogo local un producto mencionado en el mensaje del cliente.
/// Regla antialucinación: el precio y la disponibilidad SIEMPRE salen de este catálogo local,
/// nunca se generan ni se completan por fuera de él.
/// </summary>
public sealed class SearchCatalogSkill
{
    public const string SkillName = nameof(SearchCatalogSkill);

    private readonly ICatalogRepository _catalogRepository;

    public SearchCatalogSkill(ICatalogRepository catalogRepository)
    {
        _catalogRepository = catalogRepository;
    }

    public Product? FindByMessage(string customerMessage)
    {
        var normalizedMessage = TextNormalizer.Normalize(customerMessage);

        return _catalogRepository.GetAll()
            .FirstOrDefault(product =>
                normalizedMessage.Contains(TextNormalizer.Normalize(product.Name), StringComparison.Ordinal) ||
                normalizedMessage.Contains(TextNormalizer.Normalize(product.Code), StringComparison.Ordinal));
    }
}
