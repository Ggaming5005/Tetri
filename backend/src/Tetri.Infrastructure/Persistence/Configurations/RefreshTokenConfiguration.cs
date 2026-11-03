using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Tetri.Core.Entities;

namespace Tetri.Infrastructure.Persistence.Configurations;

internal sealed class RefreshTokenConfiguration : IEntityTypeConfiguration<RefreshToken>
{
    public void Configure(EntityTypeBuilder<RefreshToken> builder)
    {
        builder.ToTable("refresh_tokens", table =>
        {
            table.HasCheckConstraint("ck_refresh_tokens_revocation", "(revoked_at IS NULL) = (revoked_reason IS NULL)");
            table.HasCheckConstraint("ck_refresh_tokens_reason", "revoked_reason IS NULL OR revoked_reason IN ('rotated', 'retry_superseded', 'reuse_detected', 'logout')");
        });
        builder.HasKey(x => x.Id).HasName("pk_refresh_tokens");
        builder.Property(x => x.Id).HasColumnName("id").ValueGeneratedNever();
        builder.Property(x => x.UserId).HasColumnName("user_id");
        builder.Property(x => x.TokenHash).HasColumnName("token_hash").IsRequired();
        builder.Property(x => x.FamilyId).HasColumnName("family_id");
        builder.Property(x => x.ParentId).HasColumnName("parent_id");
        builder.Property(x => x.ExpiresAt).HasColumnName("expires_at").HasColumnType("timestamp with time zone");
        builder.Property(x => x.RevokedAt).HasColumnName("revoked_at").HasColumnType("timestamp with time zone");
        builder.Property(x => x.RevokedReason).HasColumnName("revoked_reason");
        builder.Property(x => x.ReplacedById).HasColumnName("replaced_by_id");
        builder.Property(x => x.CreatedAt).HasColumnName("created_at")
            .HasColumnType("timestamp with time zone").HasDefaultValueSql("now()");
        builder.HasOne<RefreshTokenFamily>().WithMany().HasForeignKey(x => new { x.FamilyId, x.UserId })
            .HasPrincipalKey(x => new { x.Id, x.UserId }).OnDelete(DeleteBehavior.Restrict)
            .HasConstraintName("fk_refresh_tokens_families_family_id_user_id");
        builder.HasOne<RefreshToken>().WithMany().HasForeignKey(x => x.ParentId)
            .OnDelete(DeleteBehavior.Restrict).HasConstraintName("fk_refresh_tokens_parent_id");
        builder.HasOne<RefreshToken>().WithMany().HasForeignKey(x => x.ReplacedById)
            .OnDelete(DeleteBehavior.Restrict).HasConstraintName("fk_refresh_tokens_replaced_by_id");
        builder.HasIndex(x => x.TokenHash).IsUnique().HasDatabaseName("ux_refresh_tokens_token_hash");
        builder.HasIndex(x => x.FamilyId).IsUnique().HasFilter("revoked_at IS NULL")
            .HasDatabaseName("ux_refresh_tokens_live_family");
        builder.HasIndex(x => new { x.FamilyId, x.UserId }).HasDatabaseName("ix_refresh_tokens_family_id_user_id");
        builder.HasIndex(x => x.ParentId).HasDatabaseName("ix_refresh_tokens_parent_id");
        builder.HasIndex(x => x.ReplacedById).HasDatabaseName("ix_refresh_tokens_replaced_by_id");
    }
}
