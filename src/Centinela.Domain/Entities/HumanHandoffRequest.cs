namespace Centinela.Domain.Entities;

/// <summary>
/// Señal de escalamiento a atención humana. La bandeja humana real se implementa en la Fase 07;
/// en esta fase solo se genera la señal y el resumen en memoria.
/// </summary>
public sealed class HumanHandoffRequest
{
    public required string Reason { get; init; }
    public required string Summary { get; init; }
    public required DateTimeOffset CreatedAtUtc { get; init; }
}
