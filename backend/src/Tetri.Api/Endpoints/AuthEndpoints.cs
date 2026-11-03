using System.Security.Claims;
using Tetri.Core.Auth;
using Tetri.Core.Ledger;
using Tetri.Infrastructure.Auth;

namespace Tetri.Api.Endpoints;

public static class AuthEndpoints
{
    public static void MapAuthEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/v1/auth").WithTags("Authentication");
        group.MapPost("/register", RegisterAsync).AllowAnonymous().RequireRateLimiting("auth")
            .WithName("Register").Produces<AuthResponse>(201).ProducesProblem(400).ProducesProblem(409);
        group.MapPost("/login", LoginAsync).AllowAnonymous().RequireRateLimiting("auth")
            .WithName("Login").Produces<AuthResponse>().ProducesProblem(400).ProducesProblem(401);
        group.MapPost("/refresh", RefreshAsync).AllowAnonymous()
            .WithName("Refresh").Produces<AuthResponse>().ProducesProblem(401);
        group.MapPost("/logout", LogoutAsync).RequireAuthorization()
            .WithName("Logout").Produces(204).ProducesProblem(401).ProducesProblem(403);
        group.MapGet("/handle-available", HandleAvailableAsync).AllowAnonymous().RequireRateLimiting("handle")
            .WithName("HandleAvailability").Produces<HandleAvailability>().ProducesProblem(400);
    }

    private static async Task<IResult> RegisterAsync(
        RegisterRequest request, HttpContext context, AuthService auth, CancellationToken ct)
    {
        var response = await auth.RegisterAsync(request, Audit(context), ct);
        return Results.Json(response, statusCode: StatusCodes.Status201Created);
    }

    private static async Task<IResult> LoginAsync(
        LoginRequest request, HttpContext context, AuthService auth, CancellationToken ct) =>
        Results.Ok(await auth.LoginAsync(request, Audit(context), ct));

    private static async Task<IResult> RefreshAsync(
        RefreshRequest request, HttpContext context, AuthService auth, CancellationToken ct) =>
        Results.Ok(await auth.RefreshAsync(request, Audit(context), ct));

    private static async Task<IResult> LogoutAsync(
        RefreshRequest request, HttpContext context, AuthService auth, CancellationToken ct)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        var session = context.User.FindFirstValue("sid");
        if (!Guid.TryParse(subject, out var userId) || !Guid.TryParse(session, out var familyId))
        {
            throw new DomainException("unauthorized", "Sign in to continue.", 401);
        }

        await auth.LogoutAsync(userId, familyId, request, Audit(context), ct);
        return Results.NoContent();
    }

    private static async Task<IResult> HandleAvailableAsync(string handle, AuthService auth, CancellationToken ct) =>
        Results.Ok(await auth.HandleAvailableAsync(handle, ct));

    private static AuditContext Audit(HttpContext context) =>
        new(context.Connection.RemoteIpAddress?.ToString(), context.Request.Headers.UserAgent);
}
