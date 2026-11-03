using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Serialization;
using Tetri.Core.Idempotency;
using Tetri.Core.Ledger;
using Tetri.Infrastructure.Idempotency;
using Tetri.Infrastructure.Ledger;

namespace Tetri.Api.Endpoints;

public static class TransferEndpoints
{
    private static readonly JsonSerializerOptions RequestJson = new(JsonSerializerOptions.Web)
    {
        PropertyNameCaseInsensitive = false,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
        NumberHandling = JsonNumberHandling.Strict,
        RespectRequiredConstructorParameters = true
    };

    public static void MapTransferEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost("/api/v1/transfers", PostAsync)
            .RequireAuthorization()
            .RequireRateLimiting("money")
            .Accepts<TransferRequest>("application/json")
            .WithName("CreateTransfer")
            .WithSummary("Send money to another Tetri user")
            .Produces<TransferReceipt>(StatusCodes.Status201Created)
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status401Unauthorized)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status409Conflict)
            .ProducesProblem(StatusCodes.Status422UnprocessableEntity);
    }

    private static async Task<IResult> PostAsync(
        HttpContext context,
        JsonElement body,
        LedgerService ledger,
        IdempotencyService idempotency,
        CancellationToken cancellationToken)
    {
        var subject = context.User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? context.User.FindFirstValue("sub");
        if (!Guid.TryParse(subject, out var userId) || userId == Guid.Empty)
        {
            return Problem("unauthorized", "Sign in to continue.", 401);
        }

        var keys = context.Request.Headers["Idempotency-Key"];
        if (keys.Count != 1 || !Guid.TryParse(keys[0], out var idempotencyKey))
        {
            return Problem("invalid_idempotency_key", "Send one UUID in the Idempotency-Key header.");
        }

        TransferRequest? request;
        string hash;
        try
        {
            request = body.Deserialize<TransferRequest>(RequestJson);
            hash = CanonicalJson.Hash(body.GetRawText());
        }
        catch (JsonException)
        {
            return Problem("invalid_request", "Check the recipient and enter an amount in integer minor units.");
        }

        if (request?.Amount is null || string.IsNullOrWhiteSpace(request.RecipientHandle))
        {
            return Problem("invalid_request", "Provide a recipient handle and an amount.");
        }

        if (request.Amount.Minor <= 0)
        {
            return Problem("invalid_amount", "Enter an amount greater than zero.");
        }

        if (request.Amount.Currency is not ("GEL" or "USD" or "EUR"))
        {
            return Problem("unsupported_currency", "Choose GEL, USD or EUR.");
        }

        var audit = new AuditContext(context.Connection.RemoteIpAddress?.ToString(), context.Request.Headers.UserAgent);
        var response = await idempotency.ExecuteAsync(
            userId, idempotencyKey.ToString("D"), "/api/v1/transfers", hash,
            async (connection, transaction, token) =>
            {
                var receipt = await ledger.TransferAsync(connection, transaction, userId, request, audit, token);
                return new StoredResponse(201, JsonSerializer.Serialize(receipt, JsonSerializerOptions.Web));
            },
            cancellationToken);

        var contentType = response.StatusCode >= 400 ? "application/problem+json" : "application/json";
        return Results.Content(response.Body, contentType, statusCode: response.StatusCode);
    }

    private static IResult Problem(string code, string detail, int status = 400) => Results.Problem(
        title: status == 401 ? "Sign in required" : "Check the request",
        detail: detail,
        statusCode: status,
        extensions: new Dictionary<string, object?> { ["code"] = code });
}
