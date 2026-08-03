using System.Collections.Concurrent;
using Centinela.Application.Abstractions.AzureCli;

namespace Centinela.Infrastructure.AzureCli;

/// <summary>
/// Auditoría en memoria del gateway de Azure CLI. Se pierde al reiniciar el proceso; esta fase no
/// requiere persistencia durable ni escribe en ningún log real de Azure.
/// </summary>
public sealed class InMemoryAzureCliAuditSink : IAzureCliAuditSink
{
    private readonly ConcurrentQueue<AzureCliAuditRecord> _records = new();

    public void Record(AzureCliAuditRecord record) => _records.Enqueue(record);

    public IReadOnlyList<AzureCliAuditRecord> GetAll() => _records.ToArray();
}
