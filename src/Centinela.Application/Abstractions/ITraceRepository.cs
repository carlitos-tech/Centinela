using Centinela.Domain.Entities;

namespace Centinela.Application.Abstractions;

/// <summary>Repositorio en memoria de trazas de ejecución (agente/plugin/skills) de esta fase.</summary>
public interface ITraceRepository
{
    void Save(ExecutionTrace trace);

    ExecutionTrace? FindById(string traceId);
}
