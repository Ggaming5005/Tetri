using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Tetri.Core.Entities;

namespace Tetri.Infrastructure.Persistence.Configurations;

internal sealed class EntryConfiguration : IEntityTypeConfiguration<Entry>
{
    public void Configure(EntityTypeBuilder<Entry> builder)
    {
        builder.ToTable("entries", table => table.HasCheckConstraint("ck_entries_amount", "amount <> 0"));
        builder.HasKey(x => x.Id).HasName("pk_entries");
        builder.Property(x => x.Id).HasColumnName("id").ValueGeneratedNever();
        builder.Property(x => x.TransactionId).HasColumnName("transaction_id");
        builder.Property(x => x.AccountId).HasColumnName("account_id");
        builder.Property(x => x.Amount).HasColumnName("amount");
        builder.Property(x => x.Currency).HasColumnName("currency").IsRequired();
        builder.Property(x => x.CreatedAt).HasColumnName("created_at")
            .HasColumnType("timestamp with time zone").HasDefaultValueSql("now()");
        builder.HasOne<JournalTransaction>().WithMany().HasForeignKey(x => x.TransactionId)
            .OnDelete(DeleteBehavior.Restrict).HasConstraintName("fk_entries_journal_transactions_transaction_id");
        builder.HasOne<Account>().WithMany().HasForeignKey(x => new { x.AccountId, x.Currency })
            .HasPrincipalKey(x => new { x.Id, x.Currency }).OnDelete(DeleteBehavior.Restrict)
            .HasConstraintName("fk_entries_accounts_account_id_currency");
        builder.HasIndex(x => x.TransactionId).HasDatabaseName("ix_entries_transaction_id");
        builder.HasIndex(x => new { x.AccountId, x.Currency }).HasDatabaseName("ix_entries_account_id_currency");
        builder.HasIndex(x => new { x.AccountId, x.CreatedAt, x.Id }).IsDescending(false, true, true)
            .HasDatabaseName("ix_entries_account_id_created_at_id");
    }
}
