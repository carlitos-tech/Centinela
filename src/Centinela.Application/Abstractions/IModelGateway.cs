using Centinela.Domain.Entities;
using Centinela.Domain.Enums;

namespace Centinela.Application.Abstractions;

/// <summary>
/// Abstracción del proveedor de IA (ver docs/architecture/adr/ADR-003-model-gateway.md).
/// El dominio y los casos de uso dependen únicamente de este contrato, nunca de un SDK
/// de un proveedor concreto. La implementación de esta fase (FakeModelGateway) es una
/// contingencia local y determinística, sin ningún modelo de IA real.
/// </summary>
public interface IModelGateway
{
    /// <summary>Nombre del proveedor, para trazabilidad. Nunca debe afirmar ser Claude, Foundry u otro modelo real.</summary>
    string ProviderName { get; }

    /// <summary>Clasifica la intención del mensaje del cliente.</summary>
    CustomerIntent ClassifyIntent(string customerMessage);

    /// <summary>
    /// Selecciona una respuesta de tono controlado para la intención dada, insertando
    /// únicamente los datos provistos en <paramref name="facts"/> (nunca inventa datos adicionales).
    /// </summary>
    string SelectControlledResponse(CustomerIntent intent, IReadOnlyDictionary<string, string> facts);

    /// <summary>Construye una narrativa de recomendación a partir de productos reales ya filtrados por la skill.</summary>
    string BuildRecommendationNarrative(IReadOnlyList<Product> candidates, string customerMessage);

    /// <summary>Genera un resumen corto para que el agente humano no obligue al cliente a repetir el caso.</summary>
    string SummarizeForHumanHandoff(string customerMessage, CustomerIntent intent, string reason);
}
