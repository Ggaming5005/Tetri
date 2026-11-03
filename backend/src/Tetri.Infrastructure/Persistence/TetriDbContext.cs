using Microsoft.EntityFrameworkCore;
using Tetri.Core.Entities;

namespace Tetri.Infrastructure.Persistence;

public sealed class TetriDbContext(DbContextOptions<TetriDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Account> Accounts => Set<Account>();
    public DbSet<JournalTransaction> JournalTransactions => Set<JournalTransaction>();
    public DbSet<Entry> Entries => Set<Entry>();
    public DbSet<IdempotencyKey> IdempotencyKeys => Set<IdempotencyKey>();
    public DbSet<FxQuote> FxQuotes => Set<FxQuote>();
    public DbSet<RefreshTokenFamily> RefreshTokenFamilies => Set<RefreshTokenFamily>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<FxRate> FxRates => Set<FxRate>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(TetriDbContext).Assembly);
    }
}
