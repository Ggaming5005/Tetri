namespace Tetri.Core.Entities;

public sealed class IdempotencyKey
{
    public required string Key { get; set; }
    public Guid UserId { get; set; }
    public required string Endpoint { get; set; }
    public required string RequestHash { get; set; }
    public string Status { get; set; } = "in_progress";
    public Guid AttemptToken { get; set; } = Guid.CreateVersion7();
    public int? ResponseStatus { get; set; }
    public string? ResponseBody { get; set; }
    public DateTime LockedUntil { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
