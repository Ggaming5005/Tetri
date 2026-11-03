using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Tetri.Core.Entities;

namespace Tetri.Infrastructure.Persistence.Configurations;

internal sealed class FxQuoteConfiguration : IEntityTypeConfiguration<FxQuote>
{
    public void Configure(EntityTypeBuilder<FxQuote> builder)
    {
        builder.ToTable("fx_quotes", table =>
        {
            table.HasCheckConstraint("ck_fx_quotes_currencies", "from_currency IN ('GEL', 'USD', 'EUR') AND to_currency IN ('GEL', 'USD', 'EUR') AND from_currency <> to_currency");
            table.HasCheckConstraint("ck_fx_quotes_amounts", "amount_in > 0 AND gross_out > 0 AND net_out > 0 AND fee >= 0");
            table.HasCheckConstraint("ck_fx_quotes_fee", "gross_out::numeric = net_out::numeric + fee::numeric");
            table.HasCheckConstraint("ck_fx_quotes_rate", "rate > 0");
        });
        builder.HasKey(x => x.Id).HasName("pk_fx_quotes");
        builder.Property(x => x.Id).HasColumnName("id").ValueGeneratedNever();
        builder.Property(x => x.UserId).HasColumnName("user_id");
        builder.Property(x => x.FromCurrency).HasColumnName("from_currency").IsRequired();
        builder.Property(x => x.ToCurrency).HasColumnName("to_currency").IsRequired();
        builder.Property(x => x.AmountIn).HasColumnName("amount_in");
        builder.Property(x => x.GrossOut).HasColumnName("gross_out");
        builder.Property(x => x.NetOut).HasColumnName("net_out");
        builder.Property(x => x.Fee).HasColumnName("fee");
        builder.Property(x => x.Rate).HasColumnName("rate").HasColumnType("numeric");
        builder.Property(x => x.RateDate).HasColumnName("rate_date").HasColumnType("date");
        builder.Property(x => x.ExpiresAt).HasColumnName("expires_at").HasColumnType("timestamp with time zone");
        builder.Property(x => x.UsedAt).HasColumnName("used_at").HasColumnType("timestamp with time zone");
        builder.Property(x => x.CreatedAt).HasColumnName("created_at")
            .HasColumnType("timestamp with time zone").HasDefaultValueSql("now()");
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict).HasConstraintName("fk_fx_quotes_users_user_id");
        builder.HasIndex(x => x.UserId).HasDatabaseName("ix_fx_quotes_user_id");
        builder.HasIndex(x => x.ExpiresAt).HasDatabaseName("ix_fx_quotes_expires_at");
    }
}
