using Tetri.Infrastructure.Idempotency;
using Tetri.Infrastructure.Ledger;

namespace Tetri.Api.Background;

public sealed class LedgerMaintenanceService(
    IServiceScopeFactory scopeFactory,
    TimeProvider timeProvider,
    ILogger<LedgerMaintenanceService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromHours(1), timeProvider);
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                try
                {
                    await using var scope = scopeFactory.CreateAsyncScope();
                    var ledger = scope.ServiceProvider.GetRequiredService<LedgerService>();
                    var violations = await ledger.ReconcileAsync(stoppingToken);
                    foreach (var violation in violations)
                    {
                        logger.LogError("Ledger invariant {Code} failed for {Count} records", violation.Code, violation.Count);
                    }

                    var idempotency = scope.ServiceProvider.GetRequiredService<IdempotencyService>();
                    var removed = await idempotency.CleanupAsync(stoppingToken);
                    logger.LogInformation("Ledger reconciliation found {Count} violations; removed {Keys} expired idempotency keys",
                        violations.Count, removed);
                }
                catch (Exception exception) when (exception is not OperationCanceledException)
                {
                    logger.LogError(exception, "Ledger maintenance failed; it will retry on the next interval");
                }
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
        }
    }
}
