using Centinela.Application.Abstractions;
using Centinela.Application.Common;
using Centinela.Domain.Entities;

namespace Centinela.Application.Skills;

/// <summary>
/// Skill: busca en las políticas locales la que cubre el mensaje del cliente.
/// Regla antialucinación: el contenido de política SIEMPRE sale de las políticas locales.
/// </summary>
public sealed class SearchPolicySkill
{
    public const string SkillName = nameof(SearchPolicySkill);

    private readonly IPolicyRepository _policyRepository;

    public SearchPolicySkill(IPolicyRepository policyRepository)
    {
        _policyRepository = policyRepository;
    }

    public BusinessPolicy? FindByMessage(string customerMessage)
    {
        var normalizedMessage = TextNormalizer.Normalize(customerMessage);

        return _policyRepository.GetAll()
            .FirstOrDefault(policy => TextNormalizer.ContainsAny(normalizedMessage, policy.Keywords));
    }
}
