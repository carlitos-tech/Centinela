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
        // RecordTraceSkill se ejecuta como parte de esta llamada: se agrega a sí misma a la
        // lista de skills ejecutadas para que la traza refleje el recorrido completo, evitando
        // duplicados si en el futuro ya llegara incluida.
        var skillsUsed = pluginResult.SkillsUsed.Contains(SkillName)
            ? pluginResult.SkillsUsed
            : [.. pluginResult.SkillsUsed, SkillName];

        var trace = new ExecutionTrace
        {
            TraceId = traceId,
            ConversationId = conversationId,
            Agent = agent,
            Plugin = plugin,
            SkillsUsed = skillsUsed,
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
