using Centinela.Domain.Enums;

namespace Centinela.Domain.Entities;

/// <summary>
/// Traza en memoria del recorrido agente/plugin/skills de una interacción. Registra únicamente
/// los componentes reales de la Fase 02; cualquier agente/plugin planeado para fases posteriores
/// no debe aparecer aquí como si ya existiera.
/// </summary>
public sealed class ExecutionTrace
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
    public required DateTimeOffset CreatedAtUtc { get; init; }
}
