using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Tetri.Core.Entities;

namespace Tetri.Infrastructure.Persistence.Configurations;

internal sealed class JournalTransactionConfiguration : IEntityTypeConfiguration<JournalTransaction>
{
    public void Configure(EntityTypeBuilder<JournalTransaction> builder)
    {
        builder.ToTable("journal_transactions", table =>
        {
            table.HasCheckConstraint("ck_journal_transactions_kind", "kind IN ('starter_grant', 'transfer', 'conversion')");
            table.HasCheckConstraint("ck_journal_transactions_status", "status = 'posted'");
            table.HasCheckConstraint("ck_journal_transactions_fx", "(kind = 'conversion' AND fx_rate IS NOT NULL AND fx_rate > 0 AND quote_id IS NOT NULL) OR (kind <> 'conversion' AND fx_rate IS NULL AND quote_id IS NULL)");
        });
        builder.HasKey(x => x.Id).HasName("pk_journal_transactions");
        builder.Property(x => x.Id).HasColumnName("id").ValueGeneratedNever();
        builder.Property(x => x.Kind).HasColumnName("kind").IsRequired();
        builder.Property(x => x.Status).HasColumnName("status").HasDefaultValue("posted").IsRequired();
        builder.Property(x => x.InitiatedByUserId).HasColumnName("initiated_by_user_id");
        builder.Property(x => x.Description).HasColumnName("description").IsRequired();
        builder.Property(x => x.FxRate).HasColumnName("fx_rate").HasColumnType("numeric");
        builder.Property(x => x.QuoteId).HasColumnName("quote_id");
        builder.Property(x => x.CreatedAt).HasColumnName("created_at")
            .HasColumnType("timestamp with time zone").HasDefaultValueSql("now()");
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.InitiatedByUserId)
            .OnDelete(DeleteBehavior.Restrict).HasConstraintName("fk_journal_transactions_users_initiated_by_user_id");
        builder.HasOne<FxQuote>().WithMany().HasForeignKey(x => x.QuoteId)
            .OnDelete(DeleteBehavior.Restrict).HasConstraintName("fk_journal_transactions_fx_quotes_quote_id");
        builder.HasIndex(x => x.QuoteId).IsUnique().HasDatabaseName("ux_journal_transactions_quote_id");
        builder.HasIndex(x => x.InitiatedByUserId).HasDatabaseName("ix_journal_transactions_initiated_by_user_id");
        builder.HasIndex(x => new { x.CreatedAt, x.Id }).IsDescending()
            .HasDatabaseName("ix_journal_transactions_created_at_id");
    }
}
