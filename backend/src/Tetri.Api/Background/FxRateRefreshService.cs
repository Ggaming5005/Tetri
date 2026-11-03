using Microsoft.Extensions.Options;
using Tetri.Core.Fx;
using Tetri.Infrastructure.Fx;

namespace Tetri.Api.Background;

public sealed class FxRateRefreshService(IServiceScopeFactory scopes, IOptions<FxOptions> options,
    TimeProvider timeProvider, ILogger<FxRateRefreshService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.FetchEnabled)
            return;
        using var timer = new PeriodicTimer(TimeSpan.FromHours(options.Value.RefreshHours), timeProvider);
        try
        {
            do
            {
                try
                {
                    await using var scope = scopes.CreateAsyncScope();
                    await scope.ServiceProvider.GetRequiredService<FxRateService>().RefreshAsync(stoppingToken);
                    logger.LogInformation("Official exchange rates refreshed");
                }
                catch (Exception exception) when (!stoppingToken.IsCancellationRequested)
                {
                    logger.LogWarning(exception, "Exchange rate refresh failed; keeping the last stored rates");
                }
            } while (await timer.WaitForNextTickAsync(stoppingToken));
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
        }
    }
}
