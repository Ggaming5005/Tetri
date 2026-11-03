using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Tetri.Core.Entities;

namespace Tetri.Infrastructure.Persistence.Configurations;

internal sealed class IdempotencyKeyConfiguration : IEntityTypeConfiguration<IdempotencyKey>
{
    public void Configure(EntityTypeBuilder<IdempotencyKey> builder)
    {
        builder.ToTable("idempotency_keys", table =>
        {
            table.HasCheckConstraint("ck_idempotency_keys_status", "status IN ('in_progress', 'completed')");
            table.HasCheckConstraint("ck_idempotency_keys_response", "status <> 'completed' OR (response_status IS NOT NULL AND response_body IS NOT NULL)");
        });
        builder.HasKey(x => new { x.UserId, x.Key }).HasName("pk_idempotency_keys");
        builder.Property(x => x.Key).HasColumnName("key").IsRequired();
        builder.Property(x => x.UserId).HasColumnName("user_id");
        builder.Property(x => x.Endpoint).HasColumnName("endpoint").IsRequired();
        builder.Property(x => x.RequestHash).HasColumnName("request_hash").IsRequired();
        builder.Property(x => x.Status).HasColumnName("status").IsRequired();
        builder.Property(x => x.AttemptToken).HasColumnName("attempt_token");
        builder.Property(x => x.ResponseStatus).HasColumnName("response_status");
        builder.Property(x => x.ResponseBody).HasColumnName("response_body").HasColumnType("jsonb");
        builder.Property(x => x.LockedUntil).HasColumnName("locked_until").HasColumnType("timestamp with time zone");
        builder.Property(x => x.CreatedAt).HasColumnName("created_at")
            .HasColumnType("timestamp with time zone").HasDefaultValueSql("now()");
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict).HasConstraintName("fk_idempotency_keys_users_user_id");
        builder.HasIndex(x => x.CreatedAt).HasDatabaseName("ix_idempotency_keys_created_at");
    }
}
