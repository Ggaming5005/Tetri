using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Xunit;

namespace Tetri.IntegrationTests;

public sealed class DatabaseSchemaTests(PostgresFixture database) : IClassFixture<PostgresFixture>
{
    [Fact]
    public async Task Migrations_can_be_applied_again_without_changing_the_schema_or_seeds()
    {
        await using var context = database.CreateContext();
        var appliedBefore = (await context.Database.GetAppliedMigrationsAsync()).ToArray();

        await context.Database.MigrateAsync();

        appliedBefore.Should().NotBeEmpty();
        (await context.Database.GetAppliedMigrationsAsync()).Should().Equal(appliedBefore);
        (await context.Database.GetPendingMigrationsAsync()).Should().BeEmpty();
        context.Database.HasPendingModelChanges().Should().BeFalse();

        await using var connection = await database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(
            "SELECT kind, currency, owner_user_id, id FROM accounts WHERE kind <> 'user' ORDER BY kind, currency;",
            connection);
        await using var reader = await command.ExecuteReaderAsync();
        var accounts = new List<string>();
        while (await reader.ReadAsync())
        {
            accounts.Add($"{reader.GetString(0)}:{reader.GetString(1)}");
            reader.IsDBNull(2).Should().BeTrue();
            reader.GetGuid(3).Version.Should().Be(7);
        }

        accounts.Should().BeEquivalentTo(new[]
        {
            "fees:EUR", "fees:GEL", "fees:USD",
            "funding:EUR", "funding:GEL", "funding:USD",
            "fx_pool:EUR", "fx_pool:GEL", "fx_pool:USD"
        });
    }

    [Fact]
    public async Task Timestamps_are_stored_with_time_zone_and_money_as_bigint()
    {
        await using var connection = await database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(
            """
            SELECT table_name, column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND (column_name LIKE '%\_at' ESCAPE '\' OR column_name = 'locked_until'
                   OR (table_name = 'accounts' AND column_name = 'balance')
                   OR (table_name = 'entries' AND column_name = 'amount')
                   OR (table_name = 'fx_quotes'
                       AND column_name IN ('amount_in', 'gross_out', 'net_out', 'fee')));
            """, connection);
        await using var reader = await command.ExecuteReaderAsync();
        var columnCount = 0;
        while (await reader.ReadAsync())
        {
            var column = reader.GetString(1);
            var expectedType = column.EndsWith("_at", StringComparison.Ordinal) || column == "locked_until"
                ? "timestamp with time zone"
                : "bigint";
            reader.GetString(2).Should().Be(expectedType, $"{reader.GetString(0)}.{column} has a fixed storage contract");
            columnCount++;
        }

        columnCount.Should().BeGreaterThan(6);
    }

    [Fact]
    public async Task User_account_requires_an_owner()
    {
        await AssertSqlRejectedAsync(
            "INSERT INTO accounts (id, kind, currency, balance, version) VALUES (@id, 'user', 'GEL', 0, 0);",
            "23514", "ck_accounts_owner", ("id", Guid.CreateVersion7()));
    }

    [Fact]
    public async Task System_account_cannot_have_an_owner()
    {
        await using var connection = await database.OpenConnectionAsync();
        var userId = await InsertUserAsync(connection);
        await AssertSqlRejectedAsync(
            "INSERT INTO accounts (id, owner_user_id, kind, currency, balance, version) VALUES (@id, @owner, 'funding', 'GEL', 0, 0);",
            "23514", "ck_accounts_owner", ("id", Guid.CreateVersion7()), ("owner", userId));
    }

    [Fact]
    public async Task User_balance_cannot_be_negative()
    {
        await using var connection = await database.OpenConnectionAsync();
        var userId = await InsertUserAsync(connection);
        var accountId = await InsertAccountAsync(connection, userId);

        await AssertSqlRejectedAsync(
            "UPDATE accounts SET balance = -1 WHERE id = @id;",
            "23514", "ck_accounts_balance", ("id", accountId));
    }

    [Fact]
    public async Task User_cannot_have_two_accounts_in_the_same_currency()
    {
        await using var connection = await database.OpenConnectionAsync();
        var userId = await InsertUserAsync(connection);
        await InsertAccountAsync(connection, userId);

        await AssertSqlRejectedAsync(
            "INSERT INTO accounts (id, owner_user_id, kind, currency, balance, version) VALUES (@id, @owner, 'user', 'GEL', 0, 0);",
            "23505", "ux_accounts_user_currency", ("id", Guid.CreateVersion7()), ("owner", userId));
    }

    [Theory]
    [InlineData("funding", "GEL")]
    [InlineData("funding", "USD")]
    [InlineData("funding", "EUR")]
    [InlineData("fx_pool", "GEL")]
    [InlineData("fx_pool", "USD")]
    [InlineData("fx_pool", "EUR")]
    [InlineData("fees", "GEL")]
    [InlineData("fees", "USD")]
    [InlineData("fees", "EUR")]
    public async Task System_account_is_unique_per_kind_and_currency(string kind, string currency)
    {
        await AssertSqlRejectedAsync(
            "INSERT INTO accounts (id, kind, currency, balance, version) VALUES (@id, @kind, @currency, 0, 0);",
            "23505", "ux_accounts_system_kind_currency",
            ("id", Guid.CreateVersion7()), ("kind", kind), ("currency", currency));
    }

    [Theory]
    [InlineData("funding")]
    [InlineData("fx_pool")]
    public async Task Funding_and_fx_pool_can_hold_negative_balances(string kind)
    {
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        await using var command = new NpgsqlCommand(
            "UPDATE accounts SET balance = -1 WHERE kind = @kind AND currency = 'EUR';",
            connection, transaction);
        command.Parameters.AddWithValue("kind", kind);

        (await command.ExecuteNonQueryAsync()).Should().Be(1);

        await transaction.RollbackAsync();
    }

    [Fact]
    public async Task Entry_currency_must_match_its_account()
    {
        var journal = await InsertBalancedJournalAsync();
        await AssertSqlRejectedAsync(
            "INSERT INTO entries (id, transaction_id, account_id, amount, currency) VALUES (@id, @journal, @account, 1, 'USD');",
            "23503", "fk_entries_accounts_account_id_currency",
            ("id", Guid.CreateVersion7()), ("journal", journal.TransactionId), ("account", journal.AccountId));
    }

    [Fact]
    public async Task Entry_amount_cannot_be_zero()
    {
        var journal = await InsertBalancedJournalAsync();
        await AssertSqlRejectedAsync(
            "INSERT INTO entries (id, transaction_id, account_id, amount, currency) VALUES (@id, @journal, @account, 0, 'GEL');",
            "23514", "ck_entries_amount",
            ("id", Guid.CreateVersion7()), ("journal", journal.TransactionId), ("account", journal.AccountId));
    }

    [Theory]
    [InlineData("UPDATE entries SET amount = amount + 1 WHERE id = @id;")]
    [InlineData("DELETE FROM entries WHERE id = @id;")]
    [InlineData("TRUNCATE TABLE entries;")]
    public async Task Entries_are_insert_only(string sql)
    {
        var journal = await InsertBalancedJournalAsync();
        await AssertSqlRejectedAsync(sql, "55000", null, ("id", journal.EntryId));
    }

    [Theory]
    [InlineData("UPDATE audit_log SET action = 'changed' WHERE id = @id;")]
    [InlineData("DELETE FROM audit_log WHERE id = @id;")]
    [InlineData("TRUNCATE TABLE audit_log;")]
    public async Task Audit_log_is_insert_only(string sql)
    {
        await using var connection = await database.OpenConnectionAsync();
        var userId = await InsertUserAsync(connection);
        var auditId = Guid.CreateVersion7();
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO audit_log (id, user_id, action, target_type, target_id, ip, user_agent, details)
            VALUES (@id, @user, 'schema_test', 'user', @user, '127.0.0.1', 'Tetri.IntegrationTests', '{}'::jsonb);
            """, connection);
        command.Parameters.AddWithValue("id", auditId);
        command.Parameters.AddWithValue("user", userId);
        await command.ExecuteNonQueryAsync();

        await AssertSqlRejectedAsync(sql, "55000", null, ("id", auditId));
    }

    private async Task AssertSqlRejectedAsync(
        string sql, string expectedState, string? constraint, params (string Name, object Value)[] parameters)
    {
        await using var connection = await database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        foreach (var (name, value) in parameters)
        {
            command.Parameters.AddWithValue(name, value);
        }

        var exception = await Assert.ThrowsAsync<PostgresException>(() => command.ExecuteNonQueryAsync());
        exception.SqlState.Should().Be(expectedState);
        if (constraint is not null)
        {
            exception.ConstraintName.Should().Be(constraint);
        }
    }

    private static async Task<Guid> InsertUserAsync(NpgsqlConnection connection, NpgsqlTransaction? transaction = null)
    {
        var id = Guid.CreateVersion7();
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO users (id, email, display_name, handle, password_hash)
            VALUES (@id, @email, 'Schema Test', @handle, 'fixture-password-hash');
            """, connection, transaction);
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("email", $"{id:N}@example.test");
        command.Parameters.AddWithValue("handle", "@u" + id.ToString("N")[16..]);
        await command.ExecuteNonQueryAsync();
        return id;
    }

    private static async Task<Guid> InsertAccountAsync(
        NpgsqlConnection connection, Guid owner, NpgsqlTransaction? transaction = null)
    {
        var id = Guid.CreateVersion7();
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO accounts (id, owner_user_id, kind, currency, balance, version)
            VALUES (@id, @owner, 'user', 'GEL', 0, 0);
            """, connection, transaction);
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("owner", owner);
        await command.ExecuteNonQueryAsync();
        return id;
    }

    private async Task<(Guid TransactionId, Guid AccountId, Guid EntryId)> InsertBalancedJournalAsync()
    {
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        var userId = await InsertUserAsync(connection, transaction);
        var accountId = await InsertAccountAsync(connection, userId, transaction);
        var journalId = Guid.CreateVersion7();
        var entryId = Guid.CreateVersion7();
        await using var command = new NpgsqlCommand(
            """
            INSERT INTO journal_transactions (id, kind, status, initiated_by_user_id, description)
            VALUES (@journal, 'starter_grant', 'posted', @user, 'Balanced schema test fixture');
            INSERT INTO entries (id, transaction_id, account_id, amount, currency)
            VALUES (@entry, @journal, @account, 100, 'GEL');
            INSERT INTO entries (id, transaction_id, account_id, amount, currency)
            SELECT @funding_entry, @journal, id, -100, 'GEL'
            FROM accounts WHERE kind = 'funding' AND currency = 'GEL';
            UPDATE accounts SET balance = balance + 100, version = version + 1 WHERE id = @account;
            UPDATE accounts SET balance = balance - 100, version = version + 1
            WHERE kind = 'funding' AND currency = 'GEL';
            """, connection, transaction);
        command.Parameters.AddWithValue("journal", journalId);
        command.Parameters.AddWithValue("user", userId);
        command.Parameters.AddWithValue("entry", entryId);
        command.Parameters.AddWithValue("account", accountId);
        command.Parameters.AddWithValue("funding_entry", Guid.CreateVersion7());
        await command.ExecuteNonQueryAsync();
        await transaction.CommitAsync();
        return (journalId, accountId, entryId);
    }
}
