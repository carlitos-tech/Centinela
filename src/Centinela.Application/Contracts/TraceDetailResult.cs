using Centinela.Domain.Entities;
using Centinela.Domain.Enums;

namespace Centinela.Application.Contracts;

public sealed class TraceDetailResult
{
    public required string TraceId { get; init; }
    public required string ConversationId { get; init; }
    public required string Agent { get; init; }
    public required string Plugin { get; init; }
    public required IReadOnlyList<string> SkillsUsed { get; init; }
    public required CustomerIntent Intent { get; init; }
    public required IReadOnlyList<SourceReference> Sources { get; init; }
    public required long DurationMs { get; init; }
    public required ExecutionResult Result { get; init; }
    public string? HandoffReason { get; init; }
}
