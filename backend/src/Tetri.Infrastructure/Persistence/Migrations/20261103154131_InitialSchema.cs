using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Tetri.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class InitialSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "fx_rates",
                columns: table => new
                {
                    currency = table.Column<string>(type: "text", nullable: false),
                    rate_date = table.Column<DateOnly>(type: "date", nullable: false),
                    rate_to_gel = table.Column<decimal>(type: "numeric", nullable: false),
                    fetched_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_fx_rates", x => new { x.currency, x.rate_date });
                    table.CheckConstraint("ck_fx_rates_currency", "currency IN ('GEL', 'USD', 'EUR')");
                    table.CheckConstraint("ck_fx_rates_rate", "rate_to_gel > 0");
                });

            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    email = table.Column<string>(type: "text", nullable: false),
                    display_name = table.Column<string>(type: "text", nullable: false),
                    handle = table.Column<string>(type: "text", nullable: false),
                    password_hash = table.Column<string>(type: "text", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_users", x => x.id);
                    table.CheckConstraint("ck_users_email_lowercase", "email = lower(email)");
                });

            migrationBuilder.CreateTable(
                name: "accounts",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    owner_user_id = table.Column<Guid>(type: "uuid", nullable: true),
                    kind = table.Column<string>(type: "text", nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    balance = table.Column<long>(type: "bigint", nullable: false, defaultValue: 0L),
                    version = table.Column<long>(type: "bigint", nullable: false, defaultValue: 0L),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_accounts", x => x.id);
                    table.UniqueConstraint("ak_accounts_id_currency", x => new { x.id, x.currency });
                    table.CheckConstraint("ck_accounts_balance", "kind <> 'user' OR balance >= 0");
                    table.CheckConstraint("ck_accounts_currency", "currency IN ('GEL', 'USD', 'EUR')");
                    table.CheckConstraint("ck_accounts_kind", "kind IN ('user', 'funding', 'fx_pool', 'fees')");
                    table.CheckConstraint("ck_accounts_owner", "(kind = 'user') = (owner_user_id IS NOT NULL)");
                    table.ForeignKey(
                        name: "fk_accounts_users_owner_user_id",
                        column: x => x.owner_user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "audit_log",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: true),
                    action = table.Column<string>(type: "text", nullable: false),
                    target_type = table.Column<string>(type: "text", nullable: true),
                    target_id = table.Column<Guid>(type: "uuid", nullable: true),
                    ip = table.Column<string>(type: "text", nullable: true),
                    user_agent = table.Column<string>(type: "text", nullable: true),
                    details = table.Column<string>(type: "jsonb", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_audit_log", x => x.id);
                    table.ForeignKey(
                        name: "fk_audit_log_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "fx_quotes",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    from_currency = table.Column<string>(type: "text", nullable: false),
                    to_currency = table.Column<string>(type: "text", nullable: false),
                    amount_in = table.Column<long>(type: "bigint", nullable: false),
                    gross_out = table.Column<long>(type: "bigint", nullable: false),
                    net_out = table.Column<long>(type: "bigint", nullable: false),
                    fee = table.Column<long>(type: "bigint", nullable: false),
                    rate = table.Column<decimal>(type: "numeric", nullable: false),
                    rate_date = table.Column<DateOnly>(type: "date", nullable: false),
                    expires_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    used_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_fx_quotes", x => x.id);
                    table.CheckConstraint("ck_fx_quotes_amounts", "amount_in > 0 AND gross_out > 0 AND net_out > 0 AND fee >= 0");
                    table.CheckConstraint("ck_fx_quotes_currencies", "from_currency IN ('GEL', 'USD', 'EUR') AND to_currency IN ('GEL', 'USD', 'EUR') AND from_currency <> to_currency");
                    table.CheckConstraint("ck_fx_quotes_fee", "gross_out::numeric = net_out::numeric + fee::numeric");
                    table.CheckConstraint("ck_fx_quotes_rate", "rate > 0");
                    table.ForeignKey(
                        name: "fk_fx_quotes_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "idempotency_keys",
                columns: table => new
                {
                    key = table.Column<string>(type: "text", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    endpoint = table.Column<string>(type: "text", nullable: false),
                    request_hash = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    attempt_token = table.Column<Guid>(type: "uuid", nullable: false),
                    response_status = table.Column<int>(type: "integer", nullable: true),
                    response_body = table.Column<string>(type: "jsonb", nullable: true),
                    locked_until = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_idempotency_keys", x => new { x.user_id, x.key });
                    table.CheckConstraint("ck_idempotency_keys_response", "status <> 'completed' OR (response_status IS NOT NULL AND response_body IS NOT NULL)");
                    table.CheckConstraint("ck_idempotency_keys_status", "status IN ('in_progress', 'completed')");
                    table.ForeignKey(
                        name: "fk_idempotency_keys_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "refresh_token_families",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    revoked_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    revoked_reason = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_refresh_token_families", x => x.id);
                    table.UniqueConstraint("ak_refresh_token_families_id_user_id", x => new { x.id, x.user_id });
                    table.CheckConstraint("ck_refresh_token_families_reason", "revoked_reason IS NULL OR revoked_reason IN ('reuse_detected', 'logout')");
                    table.CheckConstraint("ck_refresh_token_families_revocation", "(revoked_at IS NULL) = (revoked_reason IS NULL)");
                    table.ForeignKey(
                        name: "fk_refresh_token_families_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "journal_transactions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    kind = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "posted"),
                    initiated_by_user_id = table.Column<Guid>(type: "uuid", nullable: true),
                    description = table.Column<string>(type: "text", nullable: false),
                    fx_rate = table.Column<decimal>(type: "numeric", nullable: true),
                    quote_id = table.Column<Guid>(type: "uuid", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_journal_transactions", x => x.id);
                    table.CheckConstraint("ck_journal_transactions_fx", "(kind = 'conversion' AND fx_rate IS NOT NULL AND fx_rate > 0 AND quote_id IS NOT NULL) OR (kind <> 'conversion' AND fx_rate IS NULL AND quote_id IS NULL)");
                    table.CheckConstraint("ck_journal_transactions_kind", "kind IN ('starter_grant', 'transfer', 'conversion')");
                    table.CheckConstraint("ck_journal_transactions_status", "status = 'posted'");
                    table.ForeignKey(
                        name: "fk_journal_transactions_fx_quotes_quote_id",
                        column: x => x.quote_id,
                        principalTable: "fx_quotes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_journal_transactions_users_initiated_by_user_id",
                        column: x => x.initiated_by_user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "refresh_tokens",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    token_hash = table.Column<string>(type: "text", nullable: false),
                    family_id = table.Column<Guid>(type: "uuid", nullable: false),
                    parent_id = table.Column<Guid>(type: "uuid", nullable: true),
                    expires_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    revoked_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    revoked_reason = table.Column<string>(type: "text", nullable: true),
                    replaced_by_id = table.Column<Guid>(type: "uuid", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_refresh_tokens", x => x.id);
                    table.CheckConstraint("ck_refresh_tokens_reason", "revoked_reason IS NULL OR revoked_reason IN ('rotated', 'retry_superseded', 'reuse_detected', 'logout')");
                    table.CheckConstraint("ck_refresh_tokens_revocation", "(revoked_at IS NULL) = (revoked_reason IS NULL)");
                    table.ForeignKey(
                        name: "fk_refresh_tokens_families_family_id_user_id",
                        columns: x => new { x.family_id, x.user_id },
                        principalTable: "refresh_token_families",
                        principalColumns: new[] { "id", "user_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_refresh_tokens_parent_id",
                        column: x => x.parent_id,
                        principalTable: "refresh_tokens",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_refresh_tokens_replaced_by_id",
                        column: x => x.replaced_by_id,
                        principalTable: "refresh_tokens",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "entries",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    transaction_id = table.Column<Guid>(type: "uuid", nullable: false),
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    amount = table.Column<long>(type: "bigint", nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_entries", x => x.id);
                    table.CheckConstraint("ck_entries_amount", "amount <> 0");
                    table.ForeignKey(
                        name: "fk_entries_accounts_account_id_currency",
                        columns: x => new { x.account_id, x.currency },
                        principalTable: "accounts",
                        principalColumns: new[] { "id", "currency" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_entries_journal_transactions_transaction_id",
                        column: x => x.transaction_id,
                        principalTable: "journal_transactions",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "accounts",
                columns: new[] { "id", "created_at", "currency", "kind", "owner_user_id" },
                values: new object[,]
                {
                    { new Guid("01a19eb4-a000-7000-8000-000000000001"), new DateTime(2026, 11, 3, 0, 0, 0, 0, DateTimeKind.Utc), "GEL", "funding", null },
                    { new Guid("01a19eb4-a000-7000-8000-000000000002"), new DateTime(2026, 11, 3, 0, 0, 0, 0, DateTimeKind.Utc), "USD", "funding", null },
                    { new Guid("01a19eb4-a000-7000-8000-000000000003"), new DateTime(2026, 11, 3, 0, 0, 0, 0, DateTimeKind.Utc), "EUR", "funding", null },
                    { new Guid("01a19eb4-a000-7000-8000-000000000004"), new DateTime(2026, 11, 3, 0, 0, 0, 0, DateTimeKind.Utc), "GEL", "fx_pool", null },
                    { new Guid("01a19eb4-a000-7000-8000-000000000005"), new DateTime(2026, 11, 3, 0, 0, 0, 0, DateTimeKind.Utc), "USD", "fx_pool", null },
                    { new Guid("01a19eb4-a000-7000-8000-000000000006"), new DateTime(2026, 11, 3, 0, 0, 0, 0, DateTimeKind.Utc), "EUR", "fx_pool", null },
                    { new Guid("01a19eb4-a000-7000-8000-000000000007"), new DateTime(2026, 11, 3, 0, 0, 0, 0, DateTimeKind.Utc), "GEL", "fees", null },
                    { new Guid("01a19eb4-a000-7000-8000-000000000008"), new DateTime(2026, 11, 3, 0, 0, 0, 0, DateTimeKind.Utc), "USD", "fees", null },
                    { new Guid("01a19eb4-a000-7000-8000-000000000009"), new DateTime(2026, 11, 3, 0, 0, 0, 0, DateTimeKind.Utc), "EUR", "fees", null }
                });

            migrationBuilder.CreateIndex(
                name: "ux_accounts_system_kind_currency",
                table: "accounts",
                columns: new[] { "kind", "currency" },
                unique: true,
                filter: "kind <> 'user'");

            migrationBuilder.CreateIndex(
                name: "ux_accounts_user_currency",
                table: "accounts",
                columns: new[] { "owner_user_id", "currency" },
                unique: true,
                filter: "kind = 'user'");

            migrationBuilder.CreateIndex(
                name: "ix_audit_log_user_id_created_at",
                table: "audit_log",
                columns: new[] { "user_id", "created_at" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "ix_entries_account_id_created_at_id",
                table: "entries",
                columns: new[] { "account_id", "created_at", "id" },
                descending: new[] { false, true, true });

            migrationBuilder.CreateIndex(
                name: "ix_entries_account_id_currency",
                table: "entries",
                columns: new[] { "account_id", "currency" });

            migrationBuilder.CreateIndex(
                name: "ix_entries_transaction_id",
                table: "entries",
                column: "transaction_id");

            migrationBuilder.CreateIndex(
                name: "ix_fx_quotes_expires_at",
                table: "fx_quotes",
                column: "expires_at");

            migrationBuilder.CreateIndex(
                name: "ix_fx_quotes_user_id",
                table: "fx_quotes",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "ix_idempotency_keys_created_at",
                table: "idempotency_keys",
                column: "created_at");

            migrationBuilder.CreateIndex(
                name: "ix_journal_transactions_created_at_id",
                table: "journal_transactions",
                columns: new[] { "created_at", "id" },
                descending: new bool[0]);

            migrationBuilder.CreateIndex(
                name: "ix_journal_transactions_initiated_by_user_id",
                table: "journal_transactions",
                column: "initiated_by_user_id");

            migrationBuilder.CreateIndex(
                name: "ux_journal_transactions_quote_id",
                table: "journal_transactions",
                column: "quote_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_refresh_token_families_user_id",
                table: "refresh_token_families",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "ix_refresh_tokens_family_id_user_id",
                table: "refresh_tokens",
                columns: new[] { "family_id", "user_id" });

            migrationBuilder.CreateIndex(
                name: "ix_refresh_tokens_parent_id",
                table: "refresh_tokens",
                column: "parent_id");

            migrationBuilder.CreateIndex(
                name: "ix_refresh_tokens_replaced_by_id",
                table: "refresh_tokens",
                column: "replaced_by_id");

            migrationBuilder.CreateIndex(
                name: "ux_refresh_tokens_live_family",
                table: "refresh_tokens",
                column: "family_id",
                unique: true,
                filter: "revoked_at IS NULL");

            migrationBuilder.CreateIndex(
                name: "ux_refresh_tokens_token_hash",
                table: "refresh_tokens",
                column: "token_hash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ux_users_email",
                table: "users",
                column: "email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ux_users_handle",
                table: "users",
                column: "handle",
                unique: true);

            migrationBuilder.Sql("""
                CREATE FUNCTION reject_insert_only_mutation() RETURNS trigger
                LANGUAGE plpgsql AS $$
                BEGIN
                    RAISE EXCEPTION '% is insert-only', TG_TABLE_NAME
                        USING ERRCODE = '55000';
                END;
                $$;

                CREATE TRIGGER entries_insert_only
                    BEFORE UPDATE OR DELETE OR TRUNCATE ON entries
                    FOR EACH STATEMENT EXECUTE FUNCTION reject_insert_only_mutation();

                CREATE TRIGGER audit_log_insert_only
                    BEFORE UPDATE OR DELETE OR TRUNCATE ON audit_log
                    FOR EACH STATEMENT EXECUTE FUNCTION reject_insert_only_mutation();
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "audit_log");

            migrationBuilder.DropTable(
                name: "entries");

            migrationBuilder.DropTable(
                name: "fx_rates");

            migrationBuilder.DropTable(
                name: "idempotency_keys");

            migrationBuilder.DropTable(
                name: "refresh_tokens");

            migrationBuilder.DropTable(
                name: "accounts");

            migrationBuilder.DropTable(
                name: "journal_transactions");

            migrationBuilder.DropTable(
                name: "refresh_token_families");

            migrationBuilder.DropTable(
                name: "fx_quotes");

            migrationBuilder.DropTable(
                name: "users");

            migrationBuilder.Sql("DROP FUNCTION reject_insert_only_mutation();");
        }
    }
}
