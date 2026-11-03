using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;
using Tetri.Core.Fx;
using Tetri.Core.Idempotency;
using Tetri.Core.Ledger;
using Tetri.Infrastructure.Fx;
using Tetri.Infrastructure.Idempotency;

namespace Tetri.Api.Endpoints;

public static class FxEndpoints
{
    private static readonly JsonSerializerOptions RequestJson = new(JsonSerializerOptions.Web)
    {
        PropertyNameCaseInsensitive = false,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
        NumberHandling = JsonNumberHandling.Strict,
        RespectRequiredConstructorParameters = true
    };

    public static void MapFxEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/fx/rates", async (FxRateService rates, IOptions<FxOptions> options, CancellationToken ct) =>
                new FxRatesResponse(await rates.GetCurrentAsync(ct), options.Value.Spread))
            .RequireAuthorization().WithName("GetExchangeRates").ProducesProblem(503);
        endpoints.MapPost("/api/v1/fx/quote", QuoteAsync)
            .RequireAuthorization().WithName("CreateConversionQuote")
            .Accepts<FxQuoteRequest>("application/json")
            .Produces<FxQuoteResponse>(201).ProducesProblem(400).ProducesProblem(422).ProducesProblem(503);
        endpoints.MapPost("/api/v1/conversions", ConvertAsync)
            .RequireAuthorization().RequireRateLimiting("money").WithName("CreateConversion")
            .Accepts<ConversionRequest>("application/json")
            .Produces<ConversionReceipt>(201).ProducesProblem(400).ProducesProblem(404)
            .ProducesProblem(409).ProducesProblem(422);
    }

    private static async Task<IResult> QuoteAsync(HttpContext context, JsonElement body, FxService fx, CancellationToken ct)
    {
        var userId = UserId(context);
        FxQuoteRequest? request;
        try
        {
            request = body.Deserialize<FxQuoteRequest>(RequestJson);
            _ = CanonicalJson.Canonicalize(body.GetRawText());
        }
        catch (JsonException)
        {
            return InvalidRequest();
        }

        FxService.ValidateQuoteRequest(request);
        return Results.Json(await fx.CreateQuoteAsync(userId, request!, ct), statusCode: 201);
    }

    private static async Task<IResult> ConvertAsync(HttpContext context, JsonElement body,
        FxService fx, IdempotencyService idempotency, CancellationToken ct)
    {
        var userId = UserId(context);
        var keys = context.Request.Headers["Idempotency-Key"];
        if (keys.Count != 1 || !Guid.TryParse(keys[0], out var key))
            throw new DomainException("invalid_idempotency_key", "Send one UUID in the Idempotency-Key header.", 400);

        ConversionRequest? request;
        string hash;
        try
        {
            request = body.Deserialize<ConversionRequest>(RequestJson);
            hash = CanonicalJson.Hash(body.GetRawText());
        }
        catch (JsonException)
        {
            return InvalidRequest();
        }

        if (request is null || request.QuoteId == Guid.Empty)
            return InvalidRequest();
        var audit = new AuditContext(context.Connection.RemoteIpAddress?.ToString(), context.Request.Headers.UserAgent);
        var response = await idempotency.ExecuteAsync(userId, key.ToString("D"), "/api/v1/conversions", hash,
            async (connection, transaction, token) =>
            {
                var receipt = await fx.ConvertAsync(connection, transaction, userId, request.QuoteId, audit, token);
                return new StoredResponse(201, JsonSerializer.Serialize(receipt, JsonSerializerOptions.Web));
            }, ct);
        return Results.Content(response.Body, response.StatusCode >= 400 ? "application/problem+json" : "application/json",
            statusCode: response.StatusCode);
    }

    private static Guid UserId(HttpContext context)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out var userId) || userId == Guid.Empty)
            throw new DomainException("unauthorized", "Sign in to continue.", 401);
        return userId;
    }

    private static IResult InvalidRequest() => Results.Problem(statusCode: 400, title: "Check the request",
        detail: "Choose an amount and currencies, or provide the quote you reviewed.",
        extensions: new Dictionary<string, object?> { ["code"] = "invalid_request" });
}
