using System.Globalization;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Tetri.Core.Entities;
using Tetri.Core.Ledger;
using Tetri.Core.Queries;
using Tetri.Infrastructure.Persistence;

namespace Tetri.Infrastructure.Queries;

public sealed class BankQueryService(TetriDbContext database)
{
    public async Task<ProfileView> ProfileAsync(Guid userId, CancellationToken cancellationToken) =>
        await database.Users.AsNoTracking().Where(user => user.Id == userId)
            .Select(user => new ProfileView(user.Id, user.Email, user.DisplayName, user.Handle))
            .SingleOrDefaultAsync(cancellationToken)
        ?? throw NotFound();

    public async Task<IReadOnlyList<AccountView>> AccountsAsync(Guid userId, CancellationToken cancellationToken) =>
        await database.Accounts.AsNoTracking().Where(account => account.OwnerUserId == userId)
            .OrderBy(account => account.Currency == "GEL" ? 0 : account.Currency == "USD" ? 1 : 2)
            .Select(account => new AccountView(account.Id, account.Currency,
                new MoneyAmount(account.Balance, account.Currency), account.Version))
            .ToListAsync(cancellationToken);

    public async Task<RecipientView> LookupAsync(string? handle, CancellationToken cancellationToken)
    {
        var normalized = handle?.Trim().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(normalized) || normalized.Length > 25)
        {
            throw new DomainException("invalid_handle", "Enter a recipient's handle.", 400);
        }

        return await database.Users.AsNoTracking().Where(user => user.Handle == normalized)
            .Select(user => new RecipientView(user.DisplayName, user.Handle))
            .SingleOrDefaultAsync(cancellationToken) ?? throw NotFound();
    }

    public async Task<TransactionPage> HistoryAsync(
        Guid userId, Guid? accountId, string? cursor, int pageSize, string? filter,
        CancellationToken cancellationToken)
    {
        if (pageSize is < 1 or > 100)
        {
            throw new DomainException("invalid_page_size", "Choose a page size from 1 to 100.", 400);
        }

        filter = string.IsNullOrEmpty(filter) ? "all" : filter;
        if (filter is not ("all" or "sent" or "received" or "conversions"))
        {
            throw new DomainException("invalid_filter", "Choose All, Sent, Received or Conversions.", 400);
        }

        if (accountId.HasValue && !await database.Accounts.AnyAsync(
            account => account.Id == accountId && account.OwnerUserId == userId, cancellationToken))
        {
            throw NotFound();
        }

        var ownEntries = from entry in database.Entries
                         join account in database.Accounts on entry.AccountId equals account.Id
                         where account.OwnerUserId == userId && (!accountId.HasValue || account.Id == accountId)
                         select entry;
        var query = database.JournalTransactions.AsNoTracking()
            .Where(journal => ownEntries.Any(entry => entry.TransactionId == journal.Id));
        query = filter switch
        {
            "sent" => query.Where(journal => journal.Kind == "transfer" && ownEntries.Any(
                entry => entry.TransactionId == journal.Id && entry.Amount < 0)),
            "received" => query.Where(journal => ownEntries.Any(
                entry => entry.TransactionId == journal.Id && entry.Amount > 0) && journal.Kind != "conversion"),
            "conversions" => query.Where(journal => journal.Kind == "conversion"),
            _ => query
        };

        if (cursor is not null)
        {
            var boundary = DecodeCursor(cursor);
            query = query.Where(journal => journal.CreatedAt < boundary.CreatedAt ||
                journal.CreatedAt == boundary.CreatedAt && journal.Id.CompareTo(boundary.Id) < 0);
        }

        var journals = await query.OrderByDescending(journal => journal.CreatedAt)
            .ThenByDescending(journal => journal.Id).Take(pageSize + 1).ToListAsync(cancellationToken);
        var hasMore = journals.Count > pageSize;
        if (hasMore)
        {
            journals.RemoveAt(pageSize);
        }

        var items = await DescribeAsync(userId, journals, cancellationToken);
        return new TransactionPage(items, hasMore ? EncodeCursor(journals[^1]) : null);
    }

    public async Task<TransactionView> TransactionAsync(Guid userId, Guid id, CancellationToken cancellationToken)
    {
        var journal = await database.JournalTransactions.AsNoTracking().Where(journal => journal.Id == id &&
            database.Entries.Any(entry => entry.TransactionId == journal.Id &&
                database.Accounts.Any(account => account.Id == entry.AccountId && account.OwnerUserId == userId)))
            .SingleOrDefaultAsync(cancellationToken) ?? throw NotFound();
        return (await DescribeAsync(userId, [journal], cancellationToken))[0];
    }

    private async Task<IReadOnlyList<TransactionView>> DescribeAsync(
        Guid userId, IReadOnlyList<JournalTransaction> journals, CancellationToken cancellationToken)
    {
        if (journals.Count == 0)
        {
            return [];
        }

        var ids = journals.Select(journal => journal.Id).ToArray();
        var entries = await (from entry in database.Entries.AsNoTracking()
                             join account in database.Accounts on entry.AccountId equals account.Id
                             where ids.Contains(entry.TransactionId) && account.OwnerUserId == userId
                             orderby entry.Currency, entry.Id
                             select new { entry.TransactionId, View = new EntryView(entry.AccountId, new MoneyAmount(entry.Amount, entry.Currency)) })
            .ToListAsync(cancellationToken);
        var transferIds = journals.Where(journal => journal.Kind == "transfer").Select(journal => journal.Id).ToArray();
        var counterparties = await (from entry in database.Entries.AsNoTracking()
                                    join account in database.Accounts on entry.AccountId equals account.Id
                                    join user in database.Users on account.OwnerUserId equals user.Id
                                    where transferIds.Contains(entry.TransactionId) && user.Id != userId
                                    select new { entry.TransactionId, View = new RecipientView(user.DisplayName, user.Handle) })
            .ToListAsync(cancellationToken);
        var quoteIds = journals.Where(journal => journal.QuoteId.HasValue).Select(journal => journal.QuoteId!.Value).ToArray();
        var fees = await database.FxQuotes.AsNoTracking().Where(quote => quoteIds.Contains(quote.Id) && quote.UserId == userId)
            .Select(quote => new { quote.Id, View = new MoneyAmount(quote.Fee, quote.ToCurrency) })
            .ToDictionaryAsync(quote => quote.Id, quote => quote.View, cancellationToken);
        var entryLookup = entries.ToLookup(entry => entry.TransactionId, entry => entry.View);
        var recipientLookup = counterparties.ToLookup(recipient => recipient.TransactionId, recipient => recipient.View);
        return journals.Select(journal => new TransactionView(
            journal.Id, journal.Kind, journal.Status, journal.Description, journal.CreatedAt,
            entryLookup[journal.Id].ToArray(), recipientLookup[journal.Id].FirstOrDefault(), journal.FxRate,
            journal.QuoteId.HasValue ? fees.GetValueOrDefault(journal.QuoteId.Value) : null)).ToArray();
    }

    private static string EncodeCursor(JournalTransaction journal)
    {
        var value = FormattableString.Invariant($"{journal.CreatedAt.Ticks}:{journal.Id:D}");
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(value)).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    }

    private static (DateTime CreatedAt, Guid Id) DecodeCursor(string cursor)
    {
        try
        {
            if (cursor.Length is 0 or > 160)
            {
                throw new FormatException();
            }

            var encoded = cursor.Replace('-', '+').Replace('_', '/');
            encoded = encoded.PadRight((encoded.Length + 3) / 4 * 4, '=');
            var parts = Encoding.UTF8.GetString(Convert.FromBase64String(encoded)).Split(':');
            if (parts.Length != 2 || !long.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out var ticks) ||
                !Guid.TryParseExact(parts[1], "D", out var id))
            {
                throw new FormatException();
            }

            return (new DateTime(ticks, DateTimeKind.Utc), id);
        }
        catch (Exception exception) when (exception is FormatException or ArgumentOutOfRangeException)
        {
            throw new DomainException("invalid_cursor", "Refresh the list and try again.", 400);
        }
    }

    private static DomainException NotFound() => new("not_found", "This item isn't available. Refresh and try again.", 404);
}
