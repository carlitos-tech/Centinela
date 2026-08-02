using Centinela.Application.Abstractions;
using Centinela.Application.Orchestration;
using Centinela.Application.Plugins;
using Centinela.Application.Skills;
using Centinela.Infrastructure.Gateways;
using Centinela.Infrastructure.Repositories;
using Microsoft.Extensions.DependencyInjection;

namespace Centinela.Infrastructure;

/// <summary>
/// Composición de dependencias del walking skeleton local: repositorios en memoria,
/// FakeModelGateway, skills, plugin y agente. No registra ningún servicio de Azure ni
/// ningún modelo de IA real.
/// </summary>
public static class DependencyInjection
{
    public static IServiceCollection AddCentinelaInfrastructure(this IServiceCollection services)
    {
        services.AddSingleton<ICatalogRepository, InMemoryCatalogRepository>();
        services.AddSingleton<IPolicyRepository, InMemoryPolicyRepository>();
        services.AddSingleton<ITraceRepository, InMemoryTraceRepository>();
        services.AddSingleton<IModelGateway, FakeModelGateway>();

        services.AddScoped<ClassifyIntentSkill>();
        services.AddScoped<SearchCatalogSkill>();
        services.AddScoped<SearchPolicySkill>();
        services.AddScoped<RecommendProductSkill>();
        services.AddScoped<BuildGroundedResponseSkill>();
        services.AddScoped<DetermineHumanHandoffSkill>();
        services.AddScoped<RecordTraceSkill>();

        services.AddScoped<ICustomerServicePlugin, CustomerServicePlugin>();
        services.AddScoped<CustomerServiceOrchestrator>();

        return services;
    }
}
