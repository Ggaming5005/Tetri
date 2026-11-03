using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Testcontainers.PostgreSql;
using Tetri.Infrastructure.Persistence;
using Xunit;

namespace Tetri.IntegrationTests;

public sealed class PostgresFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder("postgres:17.11-alpine")
        .WithDatabase("tetri_tests")
        .Build();
    private bool _migrated;

    public string ConnectionString => _container.GetConnectionString();

    public TetriDbContext CreateContext() => new(
        new DbContextOptionsBuilder<TetriDbContext>()
            .UseNpgsql(ConnectionString)
            .Options);

    public async Task<NpgsqlConnection> OpenConnectionAsync()
    {
        var connection = new NpgsqlConnection(ConnectionString);
        await connection.OpenAsync();
        return connection;
    }

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        await using var context = CreateContext();
        await context.Database.MigrateAsync();
        _migrated = true;
    }

    public async Task DisposeAsync()
    {
        try
        {
            if (_migrated)
            {
                await AssertLedgerInvariantsAsync();
            }
        }
        finally
        {
            await _container.DisposeAsync();
        }
    }

    public async Task AssertLedgerInvariantsAsync()
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = new NpgsqlCommand(
            """
            SELECT 'unbalanced journal' AS violation, COUNT(*) AS total
            FROM (
                SELECT transaction_id, currency
                FROM entries
                GROUP BY transaction_id, currency
                HAVING SUM(amount) <> 0
            ) AS invalid_journals
            UNION ALL
            SELECT 'cached balance mismatch', COUNT(*)
            FROM accounts AS a
            LEFT JOIN (
                SELECT account_id, SUM(amount) AS balance
                FROM entries
                GROUP BY account_id
            ) AS e ON e.account_id = a.id
            WHERE a.balance <> COALESCE(e.balance, 0)
            UNION ALL
            SELECT 'entry currency mismatch', COUNT(*)
            FROM entries AS e
            JOIN accounts AS a ON a.id = e.account_id
            WHERE e.currency <> a.currency
            UNION ALL
            SELECT 'negative user balance', COUNT(*)
            FROM accounts
            WHERE kind = 'user' AND balance < 0;
            """, connection);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            reader.GetInt64(1).Should().Be(0, $"the ledger must have no {reader.GetString(0)}");
        }
    }
}
