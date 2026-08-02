using Centinela.Domain.Enums;

namespace Centinela.Domain.Entities;

public sealed class Message
{
    public required string Id { get; init; }
    public required MessageRole Role { get; init; }
    public required string Content { get; init; }
    public required DateTimeOffset TimestampUtc { get; init; }
}
