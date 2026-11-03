using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Tetri.Core.Entities;

namespace Tetri.Infrastructure.Persistence.Configurations;

internal sealed class AccountConfiguration : IEntityTypeConfiguration<Account>
{
    public void Configure(EntityTypeBuilder<Account> builder)
    {
        builder.ToTable("accounts", table =>
        {
            table.HasCheckConstraint("ck_accounts_kind", "kind IN ('user', 'funding', 'fx_pool', 'fees')");
            table.HasCheckConstraint("ck_accounts_currency", "currency IN ('GEL', 'USD', 'EUR')");
            table.HasCheckConstraint("ck_accounts_owner", "(kind = 'user') = (owner_user_id IS NOT NULL)");
            table.HasCheckConstraint("ck_accounts_balance", "kind <> 'user' OR balance >= 0");
        });
        builder.HasKey(x => x.Id).HasName("pk_accounts");
        builder.HasAlternateKey(x => new { x.Id, x.Currency }).HasName("ak_accounts_id_currency");
        builder.Property(x => x.Id).HasColumnName("id").ValueGeneratedNever();
        builder.Property(x => x.OwnerUserId).HasColumnName("owner_user_id");
        builder.Property(x => x.Kind).HasColumnName("kind").IsRequired();
        builder.Property(x => x.Currency).HasColumnName("currency").IsRequired();
        builder.Property(x => x.Balance).HasColumnName("balance").HasDefaultValue(0L);
        builder.Property(x => x.Version).HasColumnName("version").HasDefaultValue(0L);
        builder.Property(x => x.CreatedAt).HasColumnName("created_at")
            .HasColumnType("timestamp with time zone").HasDefaultValueSql("now()");
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.OwnerUserId)
            .OnDelete(DeleteBehavior.Restrict).HasConstraintName("fk_accounts_users_owner_user_id");
        builder.HasIndex(x => new { x.OwnerUserId, x.Currency }).IsUnique()
            .HasFilter("kind = 'user'").HasDatabaseName("ux_accounts_user_currency");
        builder.HasIndex(x => new { x.Kind, x.Currency }).IsUnique()
            .HasFilter("kind <> 'user'").HasDatabaseName("ux_accounts_system_kind_currency");
        builder.HasData(SystemAccountSeed.Accounts);
    }
}
