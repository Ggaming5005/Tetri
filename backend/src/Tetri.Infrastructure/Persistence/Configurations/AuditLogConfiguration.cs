using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Tetri.Core.Entities;

namespace Tetri.Infrastructure.Persistence.Configurations;

internal sealed class AuditLogConfiguration : IEntityTypeConfiguration<AuditLog>
{
    public void Configure(EntityTypeBuilder<AuditLog> builder)
    {
        builder.ToTable("audit_log");
        builder.HasKey(x => x.Id).HasName("pk_audit_log");
        builder.Property(x => x.Id).HasColumnName("id").ValueGeneratedNever();
        builder.Property(x => x.UserId).HasColumnName("user_id");
        builder.Property(x => x.Action).HasColumnName("action").IsRequired();
        builder.Property(x => x.TargetType).HasColumnName("target_type");
        builder.Property(x => x.TargetId).HasColumnName("target_id");
        builder.Property(x => x.Ip).HasColumnName("ip");
        builder.Property(x => x.UserAgent).HasColumnName("user_agent");
        builder.Property(x => x.Details).HasColumnName("details").HasColumnType("jsonb").IsRequired();
        builder.Property(x => x.CreatedAt).HasColumnName("created_at")
            .HasColumnType("timestamp with time zone").HasDefaultValueSql("now()");
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict).HasConstraintName("fk_audit_log_users_user_id");
        builder.HasIndex(x => new { x.UserId, x.CreatedAt }).IsDescending(false, true)
            .HasDatabaseName("ix_audit_log_user_id_created_at");
    }
}
