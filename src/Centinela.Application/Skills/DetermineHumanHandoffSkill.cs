using Centinela.Domain.Entities;
using Centinela.Domain.Enums;

namespace Centinela.Application.Skills;

/// <summary>
/// Skill: decide si un caso debe escalarse a atención humana. Implementa las reglas
/// antialucinación 6-9 (docs/planning/implementation-plan.md, Fase 02):
/// reclamos, clientes molestos, solicitudes fuera de catálogo, producto/política
/// inexistente o confianza insuficiente generan una señal de escalamiento.
/// </summary>
public sealed class DetermineHumanHandoffSkill
{
    public const string SkillName = nameof(DetermineHumanHandoffSkill);

    public (bool RequiresHandoff, string? Reason) Determine(
        CustomerIntent intent,
        Product? matchedProduct,
        BusinessPolicy? matchedPolicy,
        IReadOnlyList<Product> recommendationCandidates)
    {
        switch (intent)
        {
            case CustomerIntent.Complaint:
                return (true, "Reclamo o cliente molesto: requiere atención humana.");

            case CustomerIntent.Price:
            case CustomerIntent.Availability:
            case CustomerIntent.Features:
                return matchedProduct is null
                    ? (true, "Producto no encontrado en el catálogo local.")
                    : (false, null);

            case CustomerIntent.Policy:
                return matchedPolicy is null
                    ? (true, "No se encontró una política local que cubra la consulta.")
                    : (false, null);

            case CustomerIntent.Recommendation:
                return recommendationCandidates.Count == 0
                    ? (true, "No hay productos del catálogo local que cumplan la necesidad o el presupuesto indicado.")
                    : (false, null);

            case CustomerIntent.Unknown:
            default:
                return (true, "Intención no reconocida: información insuficiente para responder con confianza.");
        }
    }
}
