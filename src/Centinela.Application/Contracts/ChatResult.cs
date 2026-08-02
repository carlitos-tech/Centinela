using Centinela.Domain.Entities;
using Centinela.Domain.Enums;

namespace Centinela.Application.Contracts;

public sealed class ChatResult
{
    public required string ConversationId { get; init; }
    public required string Message { get; init; }
    public required CustomerIntent Intent { get; init; }
    public required IReadOnlyList<SourceReference> Sources { get; init; }
    public required bool RequiresHumanHandoff { get; init; }
    public string? HandoffReason { get; init; }
    public string? HumanSummary { get; init; }
    public required string TraceId { get; init; }
    public required long DurationMs { get; init; }
}
