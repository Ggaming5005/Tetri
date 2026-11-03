namespace Tetri.Infrastructure.Idempotency;

public sealed record StoredResponse(int StatusCode, string Body);
