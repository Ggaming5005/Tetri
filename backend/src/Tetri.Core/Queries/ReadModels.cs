using Tetri.Core.Ledger;

namespace Tetri.Core.Queries;

public sealed record ProfileView(Guid Id, string Email, string DisplayName, string Handle);
public sealed record RecipientView(string DisplayName, string Handle);
public sealed record AccountView(Guid Id, string Currency, MoneyAmount Balance, long Version);
public sealed record EntryView(Guid AccountId, MoneyAmount Amount);
public sealed record TransactionView(
    Guid Id, string Kind, string Status, string Description, DateTime CreatedAt,
    IReadOnlyList<EntryView> Entries, RecipientView? Counterparty, decimal? Rate, MoneyAmount? Fee);
public sealed record TransactionPage(IReadOnlyList<TransactionView> Items, string? NextCursor);
