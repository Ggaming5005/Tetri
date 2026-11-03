namespace Tetri.Infrastructure.Idempotency;

public interface IIdempotencyTestHooks
{
    Task AfterClaimAsync(Guid userId, string key, Guid attemptToken, CancellationToken cancellationToken);

    Task BeforeCommitAsync(Guid userId, string key, Guid attemptToken, CancellationToken cancellationToken);

    Task BeforeRejectionAsync(Guid userId, string key, Guid attemptToken, CancellationToken cancellationToken);
}

public sealed class NoOpIdempotencyTestHooks : IIdempotencyTestHooks
{
    public Task AfterClaimAsync(Guid userId, string key, Guid attemptToken, CancellationToken cancellationToken) =>
        Task.CompletedTask;

    public Task BeforeCommitAsync(Guid userId, string key, Guid attemptToken, CancellationToken cancellationToken) =>
        Task.CompletedTask;

    public Task BeforeRejectionAsync(Guid userId, string key, Guid attemptToken, CancellationToken cancellationToken) =>
        Task.CompletedTask;
}
