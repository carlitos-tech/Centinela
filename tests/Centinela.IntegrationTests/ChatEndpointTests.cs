using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Centinela.Application.Contracts;
using Centinela.Domain.Enums;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Centinela.IntegrationTests;

public class ChatEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() },
    };

    private readonly HttpClient _client;

    public ChatEndpointTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Health_ReturnsOk()
    {
        var response = await _client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task PostChat_WithEmptyMessage_ReturnsValidationProblem()
    {
        var response = await _client.PostAsJsonAsync("/api/chat", new ChatRequest { Message = "   " });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task PostChat_PriceQuestionForExistingProduct_ReturnsGroundedAnswerWithSource()
    {
        var response = await _client.PostAsJsonAsync(
            "/api/chat", new ChatRequest { Message = "¿Cuánto cuesta la Lámpara Aurora?" });

        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<ChatResult>(JsonOptions);

        Assert.NotNull(result);
        Assert.Equal(CustomerIntent.Price, result!.Intent);
        Assert.False(result.RequiresHumanHandoff);
        Assert.NotEmpty(result.Sources);
        Assert.Contains("Lámpara Aurora", result.Message);
    }

    [Fact]
    public async Task PostChat_NonexistentProduct_EscalatesToHumanWithNoInventedData()
    {
        var response = await _client.PostAsJsonAsync(
            "/api/chat", new ChatRequest { Message = "¿Tienen escritorios gamer disponibles?" });

        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<ChatResult>(JsonOptions);

        Assert.NotNull(result);
        Assert.True(result!.RequiresHumanHandoff);
        Assert.NotNull(result.HandoffReason);
        Assert.Empty(result.Sources);
    }

    [Fact]
    public async Task PostChat_Complaint_EscalatesToHumanAndProducesHandoffSummary()
    {
        var response = await _client.PostAsJsonAsync(
            "/api/chat",
            new ChatRequest { Message = "Estoy muy molesto, el producto llegó dañado y es un reclamo" });

        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<ChatResult>(JsonOptions);

        Assert.NotNull(result);
        Assert.Equal(CustomerIntent.Complaint, result!.Intent);
        Assert.True(result.RequiresHumanHandoff);
        Assert.NotNull(result.HumanSummary);
    }

    [Fact]
    public async Task PostChat_ThenGetTrace_ReturnsRecordedExecutionTrace()
    {
        var chatResponse = await _client.PostAsJsonAsync(
            "/api/chat", new ChatRequest { Message = "¿Cuánto cuesta la Lámpara Aurora?" });
        var chatResult = await chatResponse.Content.ReadFromJsonAsync<ChatResult>(JsonOptions);

        var traceResponse = await _client.GetAsync($"/api/traces/{chatResult!.TraceId}");

        Assert.Equal(HttpStatusCode.OK, traceResponse.StatusCode);
    }

    [Fact]
    public async Task PostChat_ThenGetTrace_ReturnsFullyPopulatedTraceIncludingRecordTraceSkillItself()
    {
        var chatResponse = await _client.PostAsJsonAsync(
            "/api/chat", new ChatRequest { Message = "¿Cuánto cuesta la Lámpara Aurora?" });
        var chatResult = await chatResponse.Content.ReadFromJsonAsync<ChatResult>(JsonOptions);

        var traceResponse = await _client.GetAsync($"/api/traces/{chatResult!.TraceId}");
        var trace = await traceResponse.Content.ReadFromJsonAsync<TraceDetailResult>(JsonOptions);

        Assert.NotNull(trace);
        Assert.Equal(chatResult.TraceId, trace!.TraceId);
        Assert.Equal("CustomerServiceOrchestrator", trace.Agent);
        Assert.Equal("CustomerServicePlugin", trace.Plugin);
        Assert.Contains("ClassifyIntentSkill", trace.SkillsUsed);
        Assert.Contains("SearchCatalogSkill", trace.SkillsUsed);
        Assert.Contains("DetermineHumanHandoffSkill", trace.SkillsUsed);
        Assert.Contains("BuildGroundedResponseSkill", trace.SkillsUsed);
        Assert.Contains("RecordTraceSkill", trace.SkillsUsed);
        Assert.Equal(trace.SkillsUsed.Count, trace.SkillsUsed.Distinct().Count());
        Assert.Equal(CustomerIntent.Price, trace.Intent);
        Assert.NotEmpty(trace.Sources);
        Assert.Equal(ExecutionResult.Resolved, trace.Result);
        Assert.True(trace.DurationMs >= 0);
    }

    [Fact]
    public async Task PostChat_RecommendationWithNoCatalogMatch_EscalatesWithNoIrrelevantProducts()
    {
        var response = await _client.PostAsJsonAsync(
            "/api/chat",
            new ChatRequest { Message = "Recomiéndame un escritorio gamer con presupuesto de 100.000" });

        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<ChatResult>(JsonOptions);

        Assert.NotNull(result);
        Assert.Equal(CustomerIntent.Recommendation, result!.Intent);
        Assert.True(result.RequiresHumanHandoff);
        Assert.NotNull(result.HandoffReason);
        Assert.Empty(result.Sources);
    }

    [Fact]
    public async Task GetTrace_WithUnknownTraceId_ReturnsNotFound()
    {
        var response = await _client.GetAsync("/api/traces/does-not-exist");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
