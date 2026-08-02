using Centinela.Application.Abstractions;
using Centinela.Application.Contracts;
using Centinela.Domain.Entities;
using Centinela.Domain.Enums;

namespace Centinela.Application.Skills;

/// <summary>
/// Skill: registra la traza de ejecución (agente, plugin, skills, intención, fuentes, duración,
/// resultado) del recorrido completo de una interacción, invocada por el orquestador.
/// </summary>
public sealed class RecordTraceSkill
{
    public const string SkillName = nameof(RecordTraceSkill);

    private readonly ITraceRepository _traceRepository;

    public RecordTraceSkill(ITraceRepository traceRepository)
    {
        _traceRepository = traceRepository;
    }

    public ExecutionTrace Record(
        string traceId,
        string conversationId,
        string agent,
        string plugin,
        PluginResult pluginResult,
        long durationMs)
    {
        var trace = new ExecutionTrace
        {
            TraceId = traceId,
            ConversationId = conversationId,
            Agent = agent,
            Plugin = plugin,
            SkillsUsed = pluginResult.SkillsUsed,
            Intent = pluginResult.Intent,
            Sources = pluginResult.Sources,
            DurationMs = durationMs,
            Result = pluginResult.RequiresHumanHandoff ? ExecutionResult.EscalatedToHuman : ExecutionResult.Resolved,
            HandoffReason = pluginResult.HandoffReason,
            CreatedAtUtc = DateTimeOffset.UtcNow,
        };

        _traceRepository.Save(trace);
        return trace;
    }
}
