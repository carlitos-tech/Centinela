using System.Globalization;
using Centinela.Application.Abstractions;
using Centinela.Application.Common;
using Centinela.Domain.Entities;
using Centinela.Domain.Enums;

namespace Centinela.Infrastructure.Gateways;

/// <summary>
/// Implementación local, determinista y sin llamadas externas de <see cref="IModelGateway"/>.
/// Es una contingencia de desarrollo para este walking skeleton: NO es Claude, NO es Microsoft
/// Foundry, NO es ningún modelo de IA real, no usa tokens, claves ni servicios externos. Solo
/// aplica plantillas fijas sobre los hechos (facts) que le entregan las skills — nunca inventa
/// datos por sí misma. Debe reemplazarse por un gateway real en una fase futura, sujeta a
/// aprobación humana explícita (ver ADR-003).
/// </summary>
public sealed class FakeModelGateway : IModelGateway
{
    public string ProviderName => "FakeModelGateway (contingencia local de desarrollo, sin IA real)";

    private static readonly CultureInfo Currency = CultureInfo.GetCultureInfo("es-CO");

    private static readonly (CustomerIntent Intent, string[] Keywords)[] IntentKeywordRules =
    [
        (CustomerIntent.Complaint, ["reclamo", "reclamos", "queja", "quejas", "molesto", "molesta", "dañado", "dañada", "pésimo", "furioso", "indignado"]),
        (CustomerIntent.Policy, ["política", "políticas", "devolución", "devoluciones", "garantía", "envío", "envíos", "entrega", "entregas", "pago", "pagos"]),
        (CustomerIntent.Recommendation, ["recomiéndame", "recomienda", "necesito algo", "busco algo", "qué me recomiendas", "presupuesto", "organizar"]),
        (CustomerIntent.Features, ["característica", "características", "especificación", "especificaciones", "detalle", "detalles"]),
        (CustomerIntent.Availability, ["disponible", "disponibilidad", "hay stock", "existencia", "existencias", "tienen"]),
        (CustomerIntent.Price, ["cuánto cuesta", "precio", "vale", "cuesta"]),
    ];

    public CustomerIntent ClassifyIntent(string customerMessage)
    {
        var normalized = TextNormalizer.Normalize(customerMessage);

        foreach (var (intent, keywords) in IntentKeywordRules)
        {
            if (TextNormalizer.ContainsAny(normalized, keywords))
            {
                return intent;
            }
        }

        return CustomerIntent.Unknown;
    }

    public string SelectControlledResponse(CustomerIntent intent, IReadOnlyDictionary<string, string> facts) => intent switch
    {
        CustomerIntent.Price =>
            $"La {facts["productName"]} tiene un precio de ${facts["price"]} COP, según el catálogo local de NovaCasa S.A.S.",

        CustomerIntent.Availability =>
            $"La {facts["productName"]} está actualmente {facts["availability"]}, según el catálogo local de NovaCasa S.A.S.",

        CustomerIntent.Features =>
            $"La {facts["productName"]} tiene las siguientes características, según el catálogo local de NovaCasa S.A.S.: {facts["features"]}.",

        CustomerIntent.Policy =>
            $"{facts["policyTopic"]} (NovaCasa S.A.S.): {facts["policyContent"]}",

        CustomerIntent.Complaint =>
            "Lamentamos mucho el inconveniente. Hemos registrado tu caso y un asesor humano de NovaCasa S.A.S. se pondrá en contacto contigo para darle seguimiento prioritario.",

        _ => "No tenemos información suficiente para responder con confianza.",
    };

    public string BuildRecommendationNarrative(IReadOnlyList<Product> candidates, string customerMessage)
    {
        if (candidates.Count == 0)
        {
            return "No encontramos productos del catálogo local que cumplan la necesidad indicada.";
        }

        var items = candidates.Select(product => $"{product.Name} (${product.Price.ToString("N0", Currency)} COP, código {product.Code})");
        return $"Según tu necesidad, estos productos del catálogo local de NovaCasa S.A.S. podrían servirte: {string.Join("; ", items)}.";
    }

    public string SummarizeForHumanHandoff(string customerMessage, CustomerIntent intent, string reason)
    {
        var normalizedReason = reason.TrimEnd('.');
        return $"Caso escalado a atención humana. Intención detectada: {intent}. Motivo del escalamiento: {normalizedReason}. " +
               $"Mensaje original del cliente: \"{customerMessage}\".";
    }
}
