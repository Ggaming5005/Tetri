using Tetri.Infrastructure.Idempotency;

namespace Tetri.IntegrationTests;

internal enum IdempotencyPausePoint { AfterClaim, BeforeCommit, BeforeRejection }

internal sealed class PausingIdempotencyHooks(params IdempotencyPausePoint[] points) : IIdempotencyTestHooks
{
    private readonly Dictionary<IdempotencyPausePoint, Pause> _pauses = points.ToDictionary(point => point, _ => new Pause());

    public Task AfterClaimAsync(Guid userId, string key, Guid attemptToken, CancellationToken cancellationToken) =>
        PauseAsync(IdempotencyPausePoint.AfterClaim, cancellationToken);

    public Task BeforeCommitAsync(Guid userId, string key, Guid attemptToken, CancellationToken cancellationToken) =>
        PauseAsync(IdempotencyPausePoint.BeforeCommit, cancellationToken);

    public Task BeforeRejectionAsync(Guid userId, string key, Guid attemptToken, CancellationToken cancellationToken) =>
        PauseAsync(IdempotencyPausePoint.BeforeRejection, cancellationToken);

    public Task WaitUntilPausedAsync(IdempotencyPausePoint point) =>
        _pauses[point].Reached.Task.WaitAsync(TimeSpan.FromSeconds(15));

    public void Release(IdempotencyPausePoint point) => _pauses[point].Resume.TrySetResult();

    public void ReleaseAll()
    {
        foreach (var pause in _pauses.Values)
        {
            pause.Resume.TrySetResult();
        }
    }

    private async Task PauseAsync(IdempotencyPausePoint point, CancellationToken cancellationToken)
    {
        if (_pauses.TryGetValue(point, out var pause))
        {
            pause.Reached.TrySetResult();
            await pause.Resume.Task.WaitAsync(cancellationToken);
        }
    }

    private sealed class Pause
    {
        public TaskCompletionSource Reached { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource Resume { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
    }
}
