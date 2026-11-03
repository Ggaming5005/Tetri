# Tetri API

Base path: `/api/v1`. This is a sandbox; all money is fictional. Send JSON with camelCase fields. Money is always `{ "minor": 2500, "currency": "GEL" }`, meaning 25.00 GEL. Supported currencies are GEL, USD and EUR. Unexpected fields, differently cased fields and fractional or string money values are rejected.

The development OpenAPI document is at `/openapi`. All routes except registration, login, refresh, handle availability and health require `Authorization: Bearer <accessToken>`.

## Sessions

Register with `POST /auth/register`:

```json
{
  "email": "giorgi@example.test",
  "displayName": "Giorgi",
  "handle": "@giorgi",
  "password": "a-long-unique-passphrase"
}
```

Registration returns 201 and creates three accounts, grants 1,000.00 GEL, 300.00 USD and 300.00 EUR, and signs the user in atomically. Login takes `{ "email": "…", "password": "…" }` at `POST /auth/login` and returns 200. Both return:

```json
{
  "accessToken": "…",
  "refreshToken": "…",
  "expiresAt": "2026-11-03T17:00:00Z",
  "user": { "id": "…", "email": "…", "displayName": "Giorgi", "handle": "@giorgi" }
}
```

Email and handles are trimmed and lowercased. Handles start with `@` followed by 3–24 ASCII letters, digits or underscores. Display names contain 1–80 characters after trimming; passwords contain 10–128 characters. `GET /auth/handle-available?handle=@giorgi` returns only `{ "available": true }` or false.

Access tokens last 15 minutes. Refresh tokens last 30 days and are stored only as hashes on the server. `POST /auth/refresh` takes `{ "refreshToken": "…" }` and returns the same session shape. Save both new tokens before retrying waiting requests. A lost response can be retried with the old token within 60 seconds while its replacement remains unused. This window never extends; a device that stays offline beyond it after a lost response must sign in again.

`POST /auth/logout` takes the refresh token and requires the access token for that same session. It revokes the entire session and returns 204. Only a refresh response of 401 with `code: "refresh_invalid"` tells the client to discard its stored session. Network failures, 429 and 5xx leave the tokens intact.

## Reading accounts and history

- `GET /me` returns the signed-in user's profile.
- `GET /accounts` returns an array of `{ id, currency, balance: { minor, currency }, version }`.
- `GET /users/lookup?handle=@nino` returns only `{ displayName, handle }`.
- `GET /transactions` and `GET /accounts/{id}/transactions` return `{ items, nextCursor }`. Send `pageSize` (1–100; default 20), optional `filter` (`all`, `sent`, `received`, `conversions`) and the opaque `cursor` from the preceding page. Ordering is newest first with a stable UUID tie-breaker. A null cursor means the end.
- `GET /transactions/{id}` returns one transaction. Its `entries` contain only the caller's account IDs and signed money amounts, never another user's or a system account's entries. Details include `counterparty` (display name and handle), `rate` and `fee` when applicable. Other users' account history and unrelated transactions return 404.

## Sending money

`POST /transfers` requires one UUID `Idempotency-Key` header:

```json
{ "recipientHandle": "@nino", "amount": { "minor": 2500, "currency": "GEL" } }
```

An optional `description` is accepted. Success returns 201 with `{ id, amount, recipientHandle, recipientDisplayName, createdAt }`. Generate the key when the user opens the review step and keep it across retries of that confirmation. A new confirmation needs a new key. Duplicate money fields are rejected before claiming a key.

The same key and body replay the same stored status and body, including business rejections. A changed body or endpoint returns 422 `idempotency_key_reused`; a concurrent owner can return 409 `request_in_progress`. Retry temporary transport failures and in-progress results with the same key. Keys are retained for 24 hours; do not silently re-submit an unresolved operation after that window.

## Converting currency

`GET /fx/rates` returns `{ rates: [{ currency, rateToGel, rateDate }], spread }`. Rates are normalized to GEL per one currency unit; GEL is 1. The spread defaults to 0.005 (0.5%). The official NBG feed is fetched at startup and every six hours. Stored rates remain usable when a fetch fails. Future-dated rates are stored but are not used early; a fresh installation with only a future feed returns 503 `rates_unavailable` until a valid rate is available.

Create a quote with `POST /fx/quote`:

```json
{ "amount": { "minor": 10000, "currency": "USD" }, "toCurrency": "GEL" }
```

The 201 response is `{ quoteId, amountIn, netOut, fee, rate, rateDate, expiresAt }`. Amounts and fees are money objects, with the fee in the target currency. Review those exact numbers, then send `{ "quoteId": "…" }` to `POST /conversions` with an idempotency key. Success returns 201 with `{ transactionId, quoteId, amountIn, netOut, fee, rate, rateDate, createdAt }`.

Quotes last 60 seconds and are used once. A used quote returns 409 `quote_used`, an expired one returns 409 `quote_expired`, and another user's quote returns 404. On expiry, fetch a new quote and ask the user to review it again. Retrying a completed conversion with its original key replays the completed result even after the quote expires.

## Errors and limits

Errors use `application/problem+json` with a stable `code`, HTTP `status`, and a human-readable `detail`. Codes include `invalid_request`, `invalid_credentials`, `handle_taken`, `insufficient_funds`, `amount_too_small`, `rates_unavailable`, `quote_expired` and `refresh_invalid`.

The default one-minute limits are five login/registration requests per IP, twenty handle checks per IP, and thirty transfers/conversions per user. A 429 `rate_limited` includes `Retry-After`. All limits are configurable under `RateLimits`; integration tests raise them except in the dedicated limit tests.
