using Centinela.Application.Abstractions;
using Centinela.Domain.Entities;

namespace Centinela.UnitTests.TestDoubles;

public sealed class FakeCatalogRepository : ICatalogRepository
{
    private readonly IReadOnlyList<Product> _products;

    public FakeCatalogRepository(IReadOnlyList<Product> products)
    {
        _products = products;
    }

    public IReadOnlyList<Product> GetAll() => _products;
}
