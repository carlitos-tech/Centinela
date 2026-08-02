using System.Text.Json;
using Centinela.Application.Abstractions;
using Centinela.Domain.Entities;

namespace Centinela.Infrastructure.Repositories;

/// <summary>
/// Repositorio en memoria del catálogo ficticio de NovaCasa S.A.S. Carga los productos una sola
/// vez desde Data/catalog.json (dato local versionado, sin base de datos gestionada). Esta fase
/// no usa Azure SQL ni ninguna base de datos administrada.
/// </summary>
public sealed class InMemoryCatalogRepository : ICatalogRepository
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private readonly IReadOnlyList<Product> _products;

    public InMemoryCatalogRepository()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Data", "catalog.json");
        var json = File.ReadAllText(path);
        _products = JsonSerializer.Deserialize<List<Product>>(json, SerializerOptions)
            ?? throw new InvalidOperationException($"No se pudo cargar el catálogo ficticio local desde '{path}'.");
    }

    public IReadOnlyList<Product> GetAll() => _products;
}
