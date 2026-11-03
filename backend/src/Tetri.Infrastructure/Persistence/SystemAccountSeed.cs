using Tetri.Core.Entities;

namespace Tetri.Infrastructure.Persistence;

internal static class SystemAccountSeed
{
    private static readonly DateTime CreatedAt = new(2026, 11, 3, 0, 0, 0, DateTimeKind.Utc);

    internal static readonly Account[] Accounts =
    [
        Create("01a19eb4-a000-7000-8000-000000000001", "funding", "GEL"),
        Create("01a19eb4-a000-7000-8000-000000000002", "funding", "USD"),
        Create("01a19eb4-a000-7000-8000-000000000003", "funding", "EUR"),
        Create("01a19eb4-a000-7000-8000-000000000004", "fx_pool", "GEL"),
        Create("01a19eb4-a000-7000-8000-000000000005", "fx_pool", "USD"),
        Create("01a19eb4-a000-7000-8000-000000000006", "fx_pool", "EUR"),
        Create("01a19eb4-a000-7000-8000-000000000007", "fees", "GEL"),
        Create("01a19eb4-a000-7000-8000-000000000008", "fees", "USD"),
        Create("01a19eb4-a000-7000-8000-000000000009", "fees", "EUR")
    ];

    private static Account Create(string id, string kind, string currency) => new()
    {
        Id = Guid.Parse(id),
        Kind = kind,
        Currency = currency,
        CreatedAt = CreatedAt
    };
}
