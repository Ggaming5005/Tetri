namespace Tetri.Core.Ledger;

public sealed record TransferReceipt(
    Guid Id,
    MoneyAmount Amount,
    string RecipientHandle,
    string RecipientDisplayName,
    DateTime CreatedAt);
