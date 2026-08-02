using Centinela.Domain.Entities;

namespace Centinela.Application.Abstractions;

/// <summary>Acceso de solo lectura al catálogo ficticio local de NovaCasa S.A.S.</summary>
public interface ICatalogRepository
{
    IReadOnlyList<Product> GetAll();
}
