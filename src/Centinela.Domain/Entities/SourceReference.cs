namespace Centinela.Domain.Entities;

public sealed class SourceReference
{
    public required string Type { get; init; }
    public required string Id { get; init; }
    public required string Description { get; init; }
}
