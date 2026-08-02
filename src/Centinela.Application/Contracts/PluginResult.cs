using Centinela.Domain.Entities;
using Centinela.Domain.Enums;

namespace Centinela.Application.Contracts;

/// <summary>Resultado interno del CustomerServicePlugin, consumido por el CustomerServiceOrchestrator.</summary>
public sealed class PluginResult
{
    public required string ResponseMessage { get; init; }
    public required CustomerIntent Intent { get; init; }
    public required IReadOnlyList<SourceReference> Sources { get; init; }
    public required bool RequiresHumanHandoff { get; init; }
    public string? HandoffReason { get; init; }
    public string? HumanSummary { get; init; }
    public required IReadOnlyList<string> SkillsUsed { get; init; }
}
