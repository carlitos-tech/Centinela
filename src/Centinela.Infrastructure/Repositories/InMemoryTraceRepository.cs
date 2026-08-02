using System.Collections.Concurrent;
using Centinela.Application.Abstractions;
using Centinela.Domain.Entities;

namespace Centinela.Infrastructure.Repositories;

/// <summary>
/// Repositorio en memoria de trazas de ejecución. Las trazas se pierden al reiniciar el proceso;
/// esta fase es un walking skeleton local, no requiere persistencia durable.
/// </summary>
public sealed class InMemoryTraceRepository : ITraceRepository
{
    private readonly ConcurrentDictionary<string, ExecutionTrace> _traces = new();

    public void Save(ExecutionTrace trace) => _traces[trace.TraceId] = trace;

    public ExecutionTrace? FindById(string traceId) => _traces.GetValueOrDefault(traceId);
}
