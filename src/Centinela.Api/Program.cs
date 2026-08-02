using System.Text.Json.Serialization;
using Centinela.Application.Abstractions;
using Centinela.Application.Contracts;
using Centinela.Application.Orchestration;
using Centinela.Infrastructure;

const string FrontendCorsPolicy = "CentinelaFrontend";

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddCentinelaInfrastructure();
builder.Services.AddProblemDetails();

builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter());
});

var frontendOrigin = builder.Configuration["Centinela:FrontendOrigin"] ?? "http://localhost:4200";
builder.Services.AddCors(options =>
{
    options.AddPolicy(FrontendCorsPolicy, policy =>
        policy.WithOrigins(frontendOrigin)
              .AllowAnyHeader()
              .AllowAnyMethod());
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsJsonAsync(new
        {
            error = "Ocurrió un error interno al procesar la solicitud. Intenta nuevamente.",
        });
    });
});

app.UseHttpsRedirection();
app.UseCors(FrontendCorsPolicy);

// Nota de fase: este walking skeleton local no usa Azure ni ningún modelo de IA real.
// El gateway de IA es FakeModelGateway (Centinela.Infrastructure), determinista y local.

app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "Centinela.Api" }));

app.MapPost("/api/chat", async (ChatRequest request, CustomerServiceOrchestrator orchestrator, CancellationToken cancellationToken) =>
{
    if (string.IsNullOrWhiteSpace(request.Message))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["message"] = ["El mensaje del cliente es obligatorio."],
        });
    }

    var result = await orchestrator.HandleAsync(request.ConversationId, request.Message, cancellationToken);
    return Results.Ok(result);
});

app.MapGet("/api/traces/{traceId}", (string traceId, ITraceRepository traceRepository) =>
{
    var trace = traceRepository.FindById(traceId);
    if (trace is null)
    {
        return Results.NotFound();
    }

    var detail = new TraceDetailResult
    {
        TraceId = trace.TraceId,
        ConversationId = trace.ConversationId,
        Agent = trace.Agent,
        Plugin = trace.Plugin,
        SkillsUsed = trace.SkillsUsed,
        Intent = trace.Intent,
        Sources = trace.Sources,
        DurationMs = trace.DurationMs,
        Result = trace.Result,
        HandoffReason = trace.HandoffReason,
    };
    return Results.Ok(detail);
});

app.Run();

public partial class Program;
