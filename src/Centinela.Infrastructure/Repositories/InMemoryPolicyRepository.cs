using System.Text.Json;
using Centinela.Application.Abstractions;
using Centinela.Domain.Entities;

namespace Centinela.Infrastructure.Repositories;

/// <summary>
/// Repositorio en memoria de las políticas ficticias de NovaCasa S.A.S. Carga las políticas una
/// sola vez desde Data/policies.json (dato local versionado, sin base de datos gestionada).
/// </summary>
public sealed class InMemoryPolicyRepository : IPolicyRepository
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private readonly IReadOnlyList<BusinessPolicy> _policies;

    public InMemoryPolicyRepository()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Data", "policies.json");
        var json = File.ReadAllText(path);
        _policies = JsonSerializer.Deserialize<List<BusinessPolicy>>(json, SerializerOptions)
            ?? throw new InvalidOperationException($"No se pudieron cargar las políticas ficticias locales desde '{path}'.");
    }

    public IReadOnlyList<BusinessPolicy> GetAll() => _policies;
}
