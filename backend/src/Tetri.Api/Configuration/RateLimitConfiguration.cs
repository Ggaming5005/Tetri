using System.Globalization;
using System.Security.Claims;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

namespace Tetri.Api.Configuration;

public static class RateLimitConfiguration
{
    public static IServiceCollection AddTetriRateLimits(this IServiceCollection services, IConfiguration configuration)
    {
        return services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            options.OnRejected = async (context, token) =>
            {
                if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
                {
                    context.HttpContext.Response.Headers.RetryAfter = Math.Ceiling(retryAfter.TotalSeconds)
                        .ToString(CultureInfo.InvariantCulture);
                }

                await Results.Problem(
                    title: "Too many requests",
                    detail: "Wait a moment, then try again.",
                    statusCode: StatusCodes.Status429TooManyRequests,
                    extensions: new Dictionary<string, object?> { ["code"] = "rate_limited" })
                    .ExecuteAsync(context.HttpContext);
            };
            var window = TimeSpan.FromSeconds(configuration.GetValue("RateLimits:WindowSeconds", 60));
            AddPolicy(options, "auth", configuration.GetValue("RateLimits:AuthPermitLimit", 5), window, byUser: false);
            AddPolicy(options, "handle", configuration.GetValue("RateLimits:HandlePermitLimit", 20), window, byUser: false);
            AddPolicy(options, "money", configuration.GetValue("RateLimits:MoneyPermitLimit", 30), window, byUser: true);
        });
    }

    private static void AddPolicy(RateLimiterOptions options, string name, int limit, TimeSpan window, bool byUser)
    {
        if (limit < 1 || window <= TimeSpan.Zero)
        {
            throw new InvalidOperationException($"The {name} rate limit must be positive.");
        }

        options.AddPolicy(name, context => RateLimitPartition.GetFixedWindowLimiter(
            byUser
                ? context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "anonymous"
                : context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = limit,
                Window = window,
                AutoReplenishment = true,
                QueueLimit = 0
            }));
    }
}
