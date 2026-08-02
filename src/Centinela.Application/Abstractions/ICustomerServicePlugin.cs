using Centinela.Application.Contracts;

namespace Centinela.Application.Abstractions;

/// <summary>Plugin de atención al cliente, invocado por el CustomerServiceOrchestrator.</summary>
public interface ICustomerServicePlugin
{
    Task<PluginResult> HandleAsync(string conversationId, string customerMessage, CancellationToken cancellationToken = default);
}
