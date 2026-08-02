using System.Diagnostics;
using Centinela.Application.Abstractions;
using Centinela.Application.Contracts;
using Centinela.Application.Plugins;
using Centinela.Application.Skills;

namespace Centinela.Application.Orchestration;

/// <summary>
/// Agente de atención al cliente (nivel "Agente" de la jerarquía Proyecto → Agentes → Plugins →
/// Skills → Artifacts). Único agente real implementado en esta fase. Coordina el plugin de
/// atención al cliente y registra la traza de ejecución de cada interacción.
/// </summary>
public sealed class CustomerServiceOrchestrator
{
    public const string AgentName = nameof(CustomerServiceOrchestrator);

    private readonly ICustomerServicePlugin _plugin;
    private readonly RecordTraceSkill _recordTraceSkill;

    public CustomerServiceOrchestrator(ICustomerServicePlugin plugin, RecordTraceSkill recordTraceSkill)
    {
        _plugin = plugin;
        _recordTraceSkill = recordTraceSkill;
    }

    public async Task<ChatResult> HandleAsync(string? conversationId, string customerMessage, CancellationToken cancellationToken = default)
    {
        var resolvedConversationId = string.IsNullOrWhiteSpace(conversationId)
            ? Guid.NewGuid().ToString("n")
            : conversationId;
        var traceId = Guid.NewGuid().ToString("n");

        var stopwatch = Stopwatch.StartNew();
        var pluginResult = await _plugin.HandleAsync(resolvedConversationId, customerMessage, cancellationToken);
        stopwatch.Stop();

        _recordTraceSkill.Record(
            traceId,
            resolvedConversationId,
            AgentName,
            CustomerServicePlugin.PluginName,
            pluginResult,
            stopwatch.ElapsedMilliseconds);

        return new ChatResult
        {
            ConversationId = resolvedConversationId,
            Message = pluginResult.ResponseMessage,
            Intent = pluginResult.Intent,
            Sources = pluginResult.Sources,
            RequiresHumanHandoff = pluginResult.RequiresHumanHandoff,
            HandoffReason = pluginResult.HandoffReason,
            HumanSummary = pluginResult.HumanSummary,
            TraceId = traceId,
            DurationMs = stopwatch.ElapsedMilliseconds,
        };
    }
}
