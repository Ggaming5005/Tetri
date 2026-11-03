using FluentAssertions;
using Tetri.Core.Ledger;
using Xunit;

namespace Tetri.IntegrationTests;

public sealed class LedgerTests(PostgresFixture database) : IClassFixture<PostgresFixture>
{
    [Fact]
    public async Task Starter_grant_creates_three_accounts_and_balanced_journals_atomically()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var user = await bank.CreateIdentityAsync();
        var expected = new Dictionary<string, long> { ["GEL"] = 100_000, ["USD"] = 30_000, ["EUR"] = 30_000 };
        var fundingBefore = new Dictionary<string, long>();
        foreach (var currency in expected.Keys)
        {
            fundingBefore[currency] = await bank.ScalarAsync<long>(
                "SELECT balance FROM accounts WHERE kind = 'funding' AND currency = @currency;", ("currency", currency));
        }

        await bank.Ledger.GrantStarterBalancesAsync(user.Id, CancellationToken.None);

        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM accounts WHERE owner_user_id = @user;", ("user", user.Id)))
            .Should().Be(3);
        foreach (var (currency, amount) in expected)
        {
            (await bank.BalanceAsync(user.Id, currency)).Should().Be(amount);
            (await bank.ScalarAsync<long>(
                "SELECT balance FROM accounts WHERE kind = 'funding' AND currency = @currency;", ("currency", currency)))
                .Should().Be(fundingBefore[currency] - amount);
        }

        (await bank.ScalarAsync<long>(
            "SELECT COUNT(*) FROM journal_transactions WHERE initiated_by_user_id = @user AND kind = 'starter_grant';",
            ("user", user.Id))).Should().Be(3);
        (await bank.ScalarAsync<long>(
            "SELECT COUNT(*) FROM entries WHERE transaction_id IN (SELECT id FROM journal_transactions WHERE initiated_by_user_id = @user);",
            ("user", user.Id))).Should().Be(6);
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Transfer_writes_two_balanced_entries_updates_both_accounts_and_audits()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(10_000);
        var recipient = await bank.CreateUserAsync(0);

        var receipt = await bank.TransferAsync(sender.Id,
            new TransferRequest(recipient.Handle, new MoneyAmount(2_500, "GEL"), "Lunch"));

        receipt.Amount.Should().Be(new MoneyAmount(2_500, "GEL"));
        receipt.RecipientHandle.Should().Be(recipient.Handle);
        receipt.RecipientDisplayName.Should().Be(recipient.DisplayName);
        receipt.Id.Version.Should().Be(7);
        receipt.CreatedAt.Kind.Should().Be(DateTimeKind.Utc);
        (await bank.BalanceAsync(sender.Id)).Should().Be(7_500);
        (await bank.BalanceAsync(recipient.Id)).Should().Be(2_500);
        (await bank.TransferEntryCountAsync(sender.Id)).Should().Be(2);
        (await bank.ScalarAsync<long>("SELECT SUM(amount)::bigint FROM entries WHERE transaction_id = @id;", ("id", receipt.Id)))
            .Should().Be(0);
        (await bank.ScalarAsync<long>(
            "SELECT COUNT(*) FROM audit_log WHERE user_id = @user AND target_id = @id AND action = 'transfer';",
            ("user", sender.Id), ("id", receipt.Id))).Should().Be(1);
        (await bank.ScalarAsync<string>("SELECT description FROM journal_transactions WHERE id = @id;", ("id", receipt.Id)))
            .Should().Be("Lunch");
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Insufficient_funds_rolls_back_all_money_and_audit_writes()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync(100);
        var recipient = await bank.CreateUserAsync(0);
        var entryCount = await bank.ScalarAsync<long>("SELECT COUNT(*) FROM entries;");
        var journalCount = await bank.ScalarAsync<long>("SELECT COUNT(*) FROM journal_transactions;");
        var auditCount = await bank.ScalarAsync<long>("SELECT COUNT(*) FROM audit_log;");

        var exception = await Assert.ThrowsAsync<DomainException>(() => bank.TransferAsync(
            sender.Id, new TransferRequest(recipient.Handle, new MoneyAmount(101, "GEL"))));

        exception.Code.Should().Be("insufficient_funds");
        (await bank.BalanceAsync(sender.Id)).Should().Be(100);
        (await bank.BalanceAsync(recipient.Id)).Should().Be(0);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM entries;")).Should().Be(entryCount);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM journal_transactions;")).Should().Be(journalCount);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM audit_log;")).Should().Be(auditCount);
    }

    [Fact]
    public async Task Starter_grant_participates_in_the_callers_transaction()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var user = await bank.CreateIdentityAsync();
        await using var connection = await bank.DataSource.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        await bank.Ledger.GrantStarterBalancesAsync(connection, transaction, user.Id, CancellationToken.None);
        await transaction.RollbackAsync();

        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM accounts WHERE owner_user_id = @user;", ("user", user.Id)))
            .Should().Be(0);
        (await bank.ScalarAsync<long>("SELECT COUNT(*) FROM journal_transactions WHERE initiated_by_user_id = @user;", ("user", user.Id)))
            .Should().Be(0);
        await database.AssertLedgerInvariantsAsync();
    }

    [Fact]
    public async Task Reconciliation_confirms_the_ledger_after_money_movements()
    {
        await using var bank = new LedgerTestBank(database.ConnectionString);
        var sender = await bank.CreateUserAsync();
        var recipient = await bank.CreateUserAsync(0);
        await bank.TransferAsync(sender.Id, new TransferRequest(recipient.Handle, new MoneyAmount(123, "GEL")));

        (await bank.Ledger.ReconcileAsync(CancellationToken.None)).Should().BeEmpty();
    }
}
