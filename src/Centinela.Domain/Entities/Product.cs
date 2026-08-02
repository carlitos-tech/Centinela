using Centinela.Domain.Enums;

namespace Centinela.Domain.Entities;

public sealed class Product
{
    public required string Code { get; init; }
    public required string Name { get; init; }
    public required string Category { get; init; }
    public required string Description { get; init; }
    public required decimal Price { get; init; }
    public required ProductAvailability Availability { get; init; }
    public required IReadOnlyList<string> Features { get; init; }
    public required IReadOnlyList<string> UseCases { get; init; }
    public required IReadOnlyList<string> Warnings { get; init; }
    public required string Source { get; init; }
}
