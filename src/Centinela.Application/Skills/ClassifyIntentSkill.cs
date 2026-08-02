using Centinela.Application.Abstractions;
using Centinela.Domain.Enums;

namespace Centinela.Application.Skills;

/// <summary>Skill: clasifica la intención del mensaje del cliente, delegando en el IModelGateway.</summary>
public sealed class ClassifyIntentSkill
{
    public const string SkillName = nameof(ClassifyIntentSkill);

    private readonly IModelGateway _modelGateway;

    public ClassifyIntentSkill(IModelGateway modelGateway)
    {
        _modelGateway = modelGateway;
    }

    public CustomerIntent Classify(string customerMessage) => _modelGateway.ClassifyIntent(customerMessage);
}
