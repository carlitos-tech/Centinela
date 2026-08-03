namespace Centinela.Application.Abstractions.AzureCli;

/// <summary>Almacén de auditoría del gateway. La implementación de esta fase es en memoria.</summary>
public interface IAzureCliAuditSink
{
    void Record(AzureCliAuditRecord record);

    IReadOnlyList<AzureCliAuditRecord> GetAll();
}
