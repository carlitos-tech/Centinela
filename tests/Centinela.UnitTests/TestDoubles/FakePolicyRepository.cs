using Centinela.Application.Abstractions;
using Centinela.Domain.Entities;

namespace Centinela.UnitTests.TestDoubles;

public sealed class FakePolicyRepository : IPolicyRepository
{
    private readonly IReadOnlyList<BusinessPolicy> _policies;

    public FakePolicyRepository(IReadOnlyList<BusinessPolicy> policies)
    {
        _policies = policies;
    }

    public IReadOnlyList<BusinessPolicy> GetAll() => _policies;
}
