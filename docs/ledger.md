# How Tetri moves sandbox money

Tetri stores money as signed `bigint` minor units: `2500` is 25.00 GEL. A journal transaction contains at least two immutable entries, and its entries sum to zero **within each currency**. Accounts cache the sum of their entries for fast reads. The journal, entries, cache updates, account versions, audit row and successful idempotency response commit together. PostgreSQL rejects negative user balances and mutations of existing entries or audit rows. Funding and FX pool accounts may be negative; their balances represent the sandbox's side of each movement.

## Giorgi sends 25.00 GEL to Nino

This example uses fixed UUIDv7 identifiers so the rows can be followed exactly. Let `G = 01a19eb4-a000-7000-8000-000000000101` be Giorgi's user ID, `N = 01a19eb4-a000-7000-8000-000000000102` Nino's, `GA = 01a19eb4-a000-7000-8000-000000000201` Giorgi's GEL account and `NA = 01a19eb4-a000-7000-8000-000000000202` Nino's. Both accounts begin with `balance = 100000` and `version = 1`, backed by earlier starter-grant entries. At `T = 2026-11-03T12:00:00Z`, Giorgi confirms a transfer with no custom description.

| Table | Row written |
| --- | --- |
| `journal_transactions` | `id = J = 01a19eb4-a000-7000-8000-000000000301`, `kind = transfer`, `status = posted`, `initiated_by_user_id = G`, `description = Transfer to @nino`, `fx_rate = null`, `quote_id = null`, `created_at = T` |
| `entries` | `id = 01a19eb4-a000-7000-8000-000000000401`, `transaction_id = J`, `account_id = GA`, `amount = -2500`, `currency = GEL`, `created_at = T` |
| `entries` | `id = 01a19eb4-a000-7000-8000-000000000402`, `transaction_id = J`, `account_id = NA`, `amount = 2500`, `currency = GEL`, `created_at = T` |
| `accounts` | Update `GA` to `balance = 97500`, `version = 2`; update `NA` to `balance = 102500`, `version = 2`. Other account fields stay unchanged. |
| `audit_log` | `id = 01a19eb4-a000-7000-8000-000000000501`, `user_id = G`, `action = transfer`, `target_type = journal_transaction`, `target_id = J`, `ip = 127.0.0.1`, `user_agent = Tetri`, `details = {"recipientUserId":"01a19eb4-a000-7000-8000-000000000102","minor":2500,"currency":"GEL"}`, `created_at = T` |

The new entries sum to `-2500 + 2500 = 0`. Giorgi has ₾975.00 and Nino ₾1,025.00. No balance changes without its corresponding entries.

## Locks prevent double spending

The money transaction uses **READ COMMITTED**. After validating the recipient, it selects both accounts with `ORDER BY id FOR UPDATE`. Every transfer uses PostgreSQL's UUID ordering, so opposite-direction transfers acquire shared accounts in the same order. The balance check uses the locked, current sender balance. A second transfer waits, then sees the first transfer's committed balance; it cannot spend the same balance twice. All arithmetic that updates cached balances and versions is checked for overflow. Starter grants create three zero-balance user accounts and post three balanced journals in one transaction, locking the funding and user accounts in the same order.

## Retries reuse one result

The primary key of `idempotency_keys` is `(user_id, key)`. A short first transaction claims it with the endpoint, SHA-256 hash of canonical JSON, `status = in_progress`, a fresh attempt token and a 30-second lease. A different endpoint or request body returns `422 idempotency_key_reused`; a live claim returns `409 request_in_progress`; a completed claim returns its stored status and JSON response.

An expired lease permits a new attempt token, but does not prove the old worker stopped. The money transaction first locks the key row and verifies its own token, then locks accounts. It can commit only while it still owns that token. A paused old worker cannot debit after takeover or overwrite a newer response. Business rejections roll back money changes and are cached in a separate transaction with the same ownership guard. Unexpected failures leave the claim retryable after its lease expires. Completed conversion retries replay the stored result before examining whether the quote is now used or expired. Keys are retained for 24 hours; clients must not automatically resubmit an unresolved old operation after that window.

In the example, the claimed key finishes with `status = completed`, `response_status = 201` and `response_body = {"id":"01a19eb4-a000-7000-8000-000000000301","amount":{"minor":2500,"currency":"GEL"},"recipientHandle":"@nino","recipientDisplayName":"Nino","createdAt":"2026-11-03T12:00:00Z"}` in the same commit as the money changes above. A retry returns that result without writing another journal.

The integration suite checks the sum for each `(transaction_id, currency)`, every cached balance against its entries, currency agreement and nonnegative user balances. The production reconciliation query performs those checks in one database snapshot and reports discrepancies without modifying money.
