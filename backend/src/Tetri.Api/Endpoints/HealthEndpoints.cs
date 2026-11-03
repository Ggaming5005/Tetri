using Tetri.Infrastructure.Persistence;

namespace Tetri.Api.Endpoints;

public static class HealthEndpoints
{
    public static void MapHealthEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/health", async (
            TetriDbContext database,
            ILoggerFactory loggerFactory,
            CancellationToken cancellationToken) =>
        {
            if (await database.Database.CanConnectAsync(cancellationToken))
            {
                return Results.Ok(new { status = "ok", database = "ok" });
            }

            loggerFactory.CreateLogger("Health").LogWarning("Database health check failed");
            return Results.Problem(
                title: "Database unavailable",
                detail: "The database is temporarily unavailable. Try again shortly.",
                statusCode: StatusCodes.Status503ServiceUnavailable,
                extensions: new Dictionary<string, object?> { ["code"] = "database_unavailable" });
        })
        .WithName("GetHealth")
        .WithSummary("Check API and database availability")
        .Produces(StatusCodes.Status200OK)
        .ProducesProblem(StatusCodes.Status503ServiceUnavailable);
    }
}
