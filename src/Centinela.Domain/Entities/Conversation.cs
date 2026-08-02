namespace Centinela.Domain.Entities;

public sealed class Conversation
{
    public required string Id { get; init; }
    public required List<Message> Messages { get; init; } = [];
    public required DateTimeOffset CreatedAtUtc { get; init; }
}
