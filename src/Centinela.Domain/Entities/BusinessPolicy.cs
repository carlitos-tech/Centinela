namespace Centinela.Domain.Entities;

public sealed class BusinessPolicy
{
    public required string Topic { get; init; }
    public required string Title { get; init; }
    public required string Content { get; init; }
    public required IReadOnlyList<string> Keywords { get; init; }
    public required string Source { get; init; }
}
