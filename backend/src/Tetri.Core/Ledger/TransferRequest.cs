namespace Tetri.Core.Ledger;

public sealed record TransferRequest(string RecipientHandle, MoneyAmount Amount, string? Description = null);
