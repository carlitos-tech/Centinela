using Centinela.Domain.Entities;

namespace Centinela.Application.Abstractions;

/// <summary>Acceso de solo lectura a las políticas ficticias locales de NovaCasa S.A.S.</summary>
public interface IPolicyRepository
{
    IReadOnlyList<BusinessPolicy> GetAll();
}
