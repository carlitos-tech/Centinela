namespace Centinela.Application.Contracts;

public sealed class ChatRequest
{
    /// <summary>Opcional. Si se omite, el orquestador genera un identificador nuevo.</summary>
    public string? ConversationId { get; init; }

    public required string Message { get; init; }
}
