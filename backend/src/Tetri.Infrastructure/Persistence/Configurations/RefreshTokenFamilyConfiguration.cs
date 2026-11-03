using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Tetri.Core.Entities;

namespace Tetri.Infrastructure.Persistence.Configurations;

internal sealed class RefreshTokenFamilyConfiguration : IEntityTypeConfiguration<RefreshTokenFamily>
{
    public void Configure(EntityTypeBuilder<RefreshTokenFamily> builder)
    {
        builder.ToTable("refresh_token_families", table =>
        {
            table.HasCheckConstraint("ck_refresh_token_families_revocation", "(revoked_at IS NULL) = (revoked_reason IS NULL)");
            table.HasCheckConstraint("ck_refresh_token_families_reason", "revoked_reason IS NULL OR revoked_reason IN ('reuse_detected', 'logout')");
        });
        builder.HasKey(x => x.Id).HasName("pk_refresh_token_families");
        builder.HasAlternateKey(x => new { x.Id, x.UserId }).HasName("ak_refresh_token_families_id_user_id");
        builder.Property(x => x.Id).HasColumnName("id").ValueGeneratedNever();
        builder.Property(x => x.UserId).HasColumnName("user_id");
        builder.Property(x => x.RevokedAt).HasColumnName("revoked_at").HasColumnType("timestamp with time zone");
        builder.Property(x => x.RevokedReason).HasColumnName("revoked_reason");
        builder.Property(x => x.CreatedAt).HasColumnName("created_at")
            .HasColumnType("timestamp with time zone").HasDefaultValueSql("now()");
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict).HasConstraintName("fk_refresh_token_families_users_user_id");
        builder.HasIndex(x => x.UserId).HasDatabaseName("ix_refresh_token_families_user_id");
    }
}
