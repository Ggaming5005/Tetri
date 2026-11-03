using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Tetri.Core.Entities;

namespace Tetri.Infrastructure.Persistence.Configurations;

internal sealed class FxRateConfiguration : IEntityTypeConfiguration<FxRate>
{
    public void Configure(EntityTypeBuilder<FxRate> builder)
    {
        builder.ToTable("fx_rates", table =>
        {
            table.HasCheckConstraint("ck_fx_rates_currency", "currency IN ('GEL', 'USD', 'EUR')");
            table.HasCheckConstraint("ck_fx_rates_rate", "rate_to_gel > 0");
        });
        builder.HasKey(x => new { x.Currency, x.RateDate }).HasName("pk_fx_rates");
        builder.Property(x => x.Currency).HasColumnName("currency").IsRequired();
        builder.Property(x => x.RateToGel).HasColumnName("rate_to_gel").HasColumnType("numeric");
        builder.Property(x => x.RateDate).HasColumnName("rate_date").HasColumnType("date");
        builder.Property(x => x.FetchedAt).HasColumnName("fetched_at")
            .HasColumnType("timestamp with time zone").HasDefaultValueSql("now()");
    }
}
