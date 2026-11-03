# Tetri: sandbox digital bank

Spec and working rules for the coding agent. Read this whole file before writing any code. When this file and your own instincts disagree, this file wins. If something here is unclear or impossible, stop and ask instead of guessing.

## 1. What we are building

Tetri is a portfolio project: a small multi-currency digital bank with a Flutter mobile app and an ASP.NET Core backend. It uses fake money only. Users sign up, get GEL, USD and EUR accounts with a starter balance, send money to other users, convert between currencies at real official rates, and see a clean history of everything.

The point of the project is to show bank-grade engineering in a small, finished product:

- A real double-entry ledger, not a balance column someone can edit.
- Transfers that are idempotent: a retried request never moves money twice.
- No double-spending under heavy concurrency, proven by a test.
- A calm, minimal, premium-feeling app.

Quality beats feature count. A small app that is correct, tested and beautiful is the goal. A big app that is half-working is a failure.

### Out of scope (do not build)

KYC, cards, push notifications, chat or support, real payment rails, crypto, admin panel, web frontend, multiple languages (English only, but keep strings in one place so Georgian can be added later).

### Branding

The product name is **Tetri** (the Georgian word for the smallest unit of the lari). It has its own simple wordmark. The look is inspired by modern minimal digital banks, but it must not use the name, logo, colors, copy or assets of any real bank. It must never look like it is pretending to be a real bank.

## 2. Rules for the agent

1. Work in the phases in section 12, in order. Do not start a phase until the previous phase's "done when" checks all pass.
2. After every meaningful change, build and run the tests. Never mark work done with a failing build or failing test.
3. Never delete, skip or weaken a test to make it pass. If a test is wrong, explain why before changing it.
4. Money is always an integer number of minor units (`long`, e.g. 1050 = 10.50 GEL). Never use `float`, `double` or `decimal` for stored balances or amounts. Use `decimal` only for exchange rates and convert with explicit rounding rules (section 5.4).
5. No secrets in the repo. Use `.env` files that are gitignored, plus a committed `.env.example`.
6. Only add the dependencies listed in section 3 (main stack plus the supporting packages list). Ask before adding anything else.
7. Keep it simple. No microservices, no message queues, no CQRS framework, no MediatR. Plain services and clear code.
8. Write code a reviewer can follow: small methods, real names, comments only where the "why" is not obvious.
9. At the end of each phase, update `README.md` and write a short summary of what changed and how to verify it.

## 3. Tech stack

### Backend

- .NET 10 (current LTS), ASP.NET Core minimal APIs
- PostgreSQL 17
- EF Core with Npgsql for schema, migrations and simple reads. Use raw SQL (via `Database.SqlQuery` or Npgsql directly) for the transfer path, where row locks matter.
- xUnit, FluentAssertions, Testcontainers for PostgreSQL (integration tests run against a real Postgres, never an in-memory fake)
- Serilog for structured logging
- Built-in ASP.NET Core rate limiting
- Password hashing with ASP.NET Core Identity's `PasswordHasher<T>` (do not use the full Identity framework)
- Docker Compose for local Postgres and the API

### Mobile

- Flutter (latest stable), Dart null safety, Material 3 as the base but heavily customized (section 9)
- State: Riverpod (with code generation is fine)
- Routing: go_router
- HTTP: dio
- Secure storage: flutter_secure_storage
- Biometrics: local_auth
- Fonts: google_fonts (Inter)
- Icons: one outline icon set only (phosphor_flutter or lucide_icons, pick one and never mix)
- Tests: flutter_test, mocktail

### Supporting packages (allowed without asking)

- Backend: Npgsql, Npgsql.EntityFrameworkCore.PostgreSQL, Microsoft.EntityFrameworkCore.Design, Microsoft.AspNetCore.Authentication.JwtBearer, Microsoft.AspNetCore.OpenApi, Serilog.AspNetCore, Testcontainers.PostgreSql, Microsoft.AspNetCore.Mvc.Testing, coverlet.collector
- Mobile: riverpod_annotation, riverpod_generator, build_runner, freezed, freezed_annotation, json_serializable, json_annotation, intl, uuid, flutter_lints

### CI

GitHub Actions on every push. Phase 1 adds the backend job (build plus all backend tests, with Testcontainers). Phase 4 adds the Flutter job (`flutter analyze` plus `flutter test`). From then on both jobs must stay green.

## 4. Repo layout

```
tetri/
  AGENTS.md
  README.md
  docker-compose.yml
  .env.example
  .github/workflows/ci.yml
  backend/
    Tetri.sln
    src/
      Tetri.Api/            # endpoints, auth, middleware, DI setup
      Tetri.Core/           # domain types, ledger rules, services, interfaces
      Tetri.Infrastructure/ # EF Core DbContext, migrations, repositories, NBG client
    tests/
      Tetri.UnitTests/
      Tetri.IntegrationTests/
  mobile/
    lib/
      main.dart
      app/                  # app root, router, theme
      design/               # design system: tokens, typography, components
      core/                 # api client, auth storage, formatting, errors
      features/
        auth/
        home/
        accounts/
        transfer/
        convert/
        activity/
        settings/
    test/
  docs/
    ledger.md               # how the ledger works, with one worked example
    screenshots/
```

## 5. Ledger design (the most important section)

### 5.1 Core idea

Balances are never edited directly. Every movement of money is a **journal transaction** made of two or more **entries**. Each entry adds or removes an amount from one account. For every transaction, the entries in each currency must sum to exactly zero. Money is never created or destroyed, only moved.

An account's balance is the sum of its entries. For speed, each account also stores a cached `balance` column, updated in the same database transaction as the entries. A background check (and a test) proves the cached balance always equals the sum of entries.

### 5.2 Account types

- **User accounts**: one per user per currency (GEL, USD, EUR). Balance may never go below zero.
- **System accounts**, one per currency:
  - `funding`: source of the sandbox starter balance. May go negative (it represents money "issued" in the sandbox).
  - `fx_pool`: the bank's side of currency conversions. May go negative.
  - `fees`: collects the FX spread.

### 5.3 Transaction kinds

| Kind | Entries |
| --- | --- |
| `starter_grant` | funding(-X), user(+X), same currency |
| `transfer` | sender(-X), recipient(+X), same currency |
| `conversion` | user_from(-A), fx_pool_from(+A), fx_pool_to(-G), user_to(+N), fees_to(+F), see 5.4 |

Transfers only happen between accounts of the same currency. Sending USD to someone means USD account to USD account.

### 5.4 Amounts, rounding and conversion fees

- Store amounts as `long` minor units. All three currencies use 2 decimals.
- All conversion math lives in one pure function with unit tests. It is computed in `decimal` and every rounding step rounds down to the minor unit, so rounding always favors the bank, never the user.
- For a conversion of A (minor units, source currency) at mid rate R (target units per source unit):
  - Gross output: `G = floor(A * R)`
  - Net output to the user: `N = floor(A * R * (1 - spread))`
  - Fee, in the **target currency**: `F = G - N`
- Spread: 0.5%, as a config value.
- Exact entries (all five in one journal transaction):
  - source currency: user_from(-A), fx_pool_from(+A). Sum = 0.
  - target currency: fx_pool_to(-G), user_to(+N), fees_to(+F). Sum = -G + N + F = 0.
  - If F is 0, the fees entry is omitted (entries are never zero).
- If N rounds to 0 or less, reject with 422 `amount_too_small`. Nothing is written.

### 5.4.1 Quotes

- `POST /fx/quote` stores a quote in `fx_quotes` with A, R, G, N, F, the NBG rate date, and `expires_at` = now + 60 seconds, and returns its id.
- `POST /conversions` takes only a `quoteId`. The server executes exactly the quoted numbers, never recalculates.
- Reject if the quote belongs to another user (404), is expired (409 `quote_expired`), or was already used (409 `quote_used`). The app reacts to `quote_expired` by fetching a fresh quote and showing the review again, so the user always confirms the exact terms that execute.
- Marking the quote used happens in the same database transaction as the conversion.

### 5.5 Database schema

Use snake_case table and column names. All ids are UUIDv7 (time-sortable). All timestamps are `timestamptz` in UTC.

- `users`: id, email (unique, lowercased), display_name, handle (unique, like `@giorgi`), password_hash, created_at
- `accounts`: id, owner_user_id (null for system accounts), kind (`user`, `funding`, `fx_pool`, `fees`), currency (`GEL`, `USD`, `EUR`), balance (bigint), version (bigint), created_at. Constraints:
  - Check: `(kind = 'user') = (owner_user_id IS NOT NULL)`. User accounts always have an owner, system accounts never do.
  - Check: `kind <> 'user' OR balance >= 0`.
  - Unique partial index on (owner_user_id, currency) where `kind = 'user'`.
  - Unique partial index on (kind, currency) where `kind <> 'user'`, so there is exactly one funding, fx_pool and fees account per currency. A migration seeds all nine system accounts.
  - Unique on (id, currency), so entries can reference it (below).
- `journal_transactions`: id, kind, status (`posted`), initiated_by_user_id, description, fx_rate (numeric, null unless conversion), quote_id (null unless conversion), created_at
- `entries`: id, transaction_id, account_id, amount (bigint, non-zero, signed), currency, created_at. Composite foreign key (account_id, currency) references accounts (id, currency), so an entry's currency can never disagree with its account's currency. Entries are insert-only: no updates, no deletes. Enforce this with a Postgres trigger that rejects UPDATE and DELETE on `entries`.
- `idempotency_keys`: key (text), user_id, endpoint, request_hash, status (`in_progress`, `completed`), attempt_token (uuid), response_status, response_body (jsonb), locked_until (timestamptz), created_at. Primary key (user_id, key).
- `fx_quotes`: id, user_id, from_currency, to_currency, amount_in, gross_out, net_out, fee, rate (numeric), rate_date, expires_at, used_at, created_at
- `refresh_token_families`: id, user_id, revoked_at, revoked_reason, created_at. One row per sign-in session. Exists so every refresh operation on a session can lock the same row (section 7).
- `refresh_tokens`: id, user_id, token_hash (unique), family_id (references refresh_token_families), parent_id, expires_at, revoked_at, revoked_reason (`rotated`, `retry_superseded`, `reuse_detected`, `logout`), replaced_by_id, created_at
- `fx_rates`: currency, rate_to_gel (numeric, already divided by quantity, see section 6), rate_date (the feed's validFromDate), fetched_at. Unique (currency, rate_date).
- `audit_log`: id, user_id, action, target_type, target_id, ip, user_agent, details (jsonb), created_at. Insert-only, same trigger as entries.

### 5.6 How a transfer is posted (exact algorithm)

Everything below runs inside one database transaction at READ COMMITTED.

1. Validate input: amount > 0, currency supported, recipient exists, recipient is not the sender.
2. Lock both accounts with `SELECT ... FOR UPDATE`, always in ascending account id order. Locking in a fixed order prevents deadlocks when two users send to each other at the same time.
3. Check the sender's locked balance is at least the amount. If not, roll back and return `insufficient_funds`.
4. Insert the journal transaction and its entries.
5. Update both cached balances and bump `version`.
6. Insert the audit log row.
7. Commit.

The `balance >= 0` check constraint is the last line of defense. If application code is ever wrong, the database still refuses the overdraft.

Conversions follow the same algorithm: lock the quote row and all involved accounts (user_from, user_to, both fx_pool accounts, fees_to) in ascending id order, check the quote is unused and unexpired, check the user's balance covers A, write the entries from 5.4, and set the quote's `used_at`.

### 5.7 Idempotency

`POST /transfers` and `POST /conversions` require an `Idempotency-Key` header (a UUID generated by the client). Missing or malformed header returns 400.

The flow uses two separate database transactions on purpose.

**Transaction 1, the claim (short, committed immediately):**

1. Hash the request body: SHA-256 of the canonical JSON (keys sorted, no whitespace).
2. Generate a fresh random `attempt_token` (UUID). This worker keeps it in memory for the rest of the request.
3. `INSERT ... ON CONFLICT (user_id, key) DO NOTHING` with status `in_progress`, the `attempt_token`, and `locked_until` = now + 30 seconds. Commit right away, so a competing request sees the claim instead of blocking on it.
4. If the insert did nothing, read the existing row and decide:
   - Different endpoint or different hash: 422 `idempotency_key_reused`.
   - `completed`: return the stored status code and body exactly.
   - `in_progress` and `locked_until` is in the future: 409 `request_in_progress`. The client retries later with the same key.
   - `in_progress` and `locked_until` has passed: take the claim over with `UPDATE ... SET attempt_token = $new_token, locked_until = now + 30s WHERE user_id = $1 AND key = $2 AND status = 'in_progress' AND locked_until < now()`, run with `SET LOCAL lock_timeout = '2s'`. If it updates one row, this worker now owns the key with its new token: continue to transaction 2. If it updates zero rows or hits the lock timeout, someone else owns it: re-read the row and return the stored response if `completed`, otherwise 409 `request_in_progress`.

**Why the attempt token matters:** an expired `locked_until` does not prove the previous worker is dead. It might just be paused (a GC pause, a slow network, a debugger). After a takeover, the old worker can wake up. Every write after the claim is therefore guarded by the worker's own `attempt_token`, so only the current owner can move money or store a result. A worker whose token was replaced does nothing.

**Transaction 2, the money (section 5.6):**

5. The very first statement locks the key row with the worker's own token: `SELECT ... FROM idempotency_keys WHERE user_id = $1 AND key = $2 AND status = 'in_progress' AND attempt_token = $my_token FOR UPDATE`. If no row comes back, this worker lost ownership: roll back immediately, touch no accounts, then re-read the row and return the stored response if `completed`, otherwise 409 `request_in_progress`.
6. Holding that row lock also blocks any takeover for as long as this transaction runs. A takeover's UPDATE waits, and once this transaction commits, Postgres re-checks the takeover's `WHERE status = 'in_progress'` against the committed row, finds `completed`, and updates nothing.
7. Post the transfer or conversion, then complete the key: `UPDATE idempotency_keys SET status = 'completed', response_status = ..., response_body = ... WHERE user_id = $1 AND key = $2 AND status = 'in_progress' AND attempt_token = $my_token`. If it affects zero rows, roll back the entire transaction, money included. One commit covers both, so money never moves without its stored response, and a response is never stored without the money.

**Which outcomes are cached:**

8. Business outcomes are final and cached: success (201), and domain rejections such as `insufficient_funds`, `quote_expired`, `quote_used`, `amount_too_small`, recipient not found. For a rejection, transaction 2 rolls back. Then a third short transaction stores the rejection with the same guard: `... WHERE status = 'in_progress' AND attempt_token = $my_token`. If that affects zero rows, another worker owns the key, so its result stands: re-read and return whatever is stored now (or 409 if still in progress). A stale worker's rejection can never overwrite a newer worker's success. Retrying the same key returns the same stored result. The user starts a new attempt, with a new key, to try again.
9. Validation errors (400) are returned before the claim, so they are never stored.
10. Unexpected errors (500, lost database connection) are not cached. The claim stays `in_progress` and becomes takeable after `locked_until` passes, so the client's retry with the same key works.

**Test hooks:** the idempotency service calls an `IIdempotencyTestHooks` interface at three points: after the claim commits, inside transaction 2 just before commit, and before storing a rejection. Production registers a no-op implementation. Integration tests register one that can pause a worker at any of those points (with a `TaskCompletionSource`), so the takeover races in section 11 can be tested deterministically.

**Cleanup:** a background job deletes keys older than 24 hours.

### 5.8 Documentation

Write `docs/ledger.md`: a one-page explanation of the ledger, the lock ordering, and idempotency, with one worked example (Giorgi sends 25.00 GEL to Nino) showing the exact rows written. This is the file an interviewer will read, so make it clear.

## 6. Exchange rates

- Source: National Bank of Georgia official rates feed, `https://nbg.gov.ge/gw/api/ct/monetarypolicy/currencies/en/json/` (verified to include USD and EUR). Use only this undated base feed. Do not rely on a `?date=` query.
- Normalization: each currency entry has a `rate` and a `quantity` (the rate is GEL per `quantity` units). Store `rate_to_gel = rate / quantity`, in `decimal`. Write a unit test with a sample payload, including one currency where quantity is not 1.
- Effective date: store the entry's `validFromDate` as `rate_date`. Upserts are keyed on (currency, rate_date), so refetching the same day's feed changes nothing. The "current" rate is the row with the latest `rate_date` that is not in the future.
- Keep a small saved copy of a real feed response in the test project and parse it in tests. Tests never call the live feed.
- Fetch on startup and every 6 hours. Store in `fx_rates`.
- If the fetch fails, keep using the last stored rate and log a warning. If there is no stored rate at all, conversions return 503 `rates_unavailable`.
- Cross rates (USD to EUR) go through GEL.
- Every conversion stores the exact rate it used on the journal transaction.

## 7. Auth and security

- Register: email, display name, handle, password (minimum 10 characters). On success, create three user accounts and a `starter_grant` of 1,000.00 GEL, 300.00 USD and 300.00 EUR, all in one database transaction.
- Login creates a new `refresh_token_families` row (one per sign-in session) and returns an access token (JWT, 15 minutes) and a refresh token (opaque random 32 bytes, 30 days) in that family. Store only the SHA-256 hash of refresh tokens.
- Refresh token rotation: every refresh issues a new token and revokes the old one. If a revoked token is ever reused, revoke the whole token family (it was likely stolen).
- **Every refresh operation is serialized per session.** Rotation, grace retries, reuse detection and logout all run inside one database transaction that starts the same way:
  1. Look up the presented token by `token_hash` (a plain read) to find its `family_id`. Unknown token: 401 `refresh_invalid`.
  2. Lock the session: `SELECT ... FROM refresh_token_families WHERE id = $family_id FOR UPDATE`. Every other refresh or logout for the same session now waits until this transaction commits.
  3. Re-read the presented token and its replacement chain under the lock, and only then decide what to do. Decisions are never made on rows read before the lock.
  4. If the family is revoked: 401 `refresh_invalid`.

  Because all four operations take the same lock, two overlapping retries cannot both act on the same state, and logout cannot miss a replacement token that was being created at the same moment.
- **Normal rotation:** the presented token is live and unexpired. Revoke it (`revoked_at = now()`, reason `rotated`), insert the replacement with `parent_id` set, and set the presented token's `replaced_by_id` to the replacement. Commit.
- **Retry grace window (60 seconds):** a refresh response can be lost (timeout, dropped connection) after the server already rotated the token. The client then retries with the old token, which looks like reuse. To avoid logging that user out, if the presented token:
  - was revoked with reason `rotated` less than 60 seconds ago (measured from its original `revoked_at`), and
  - the token its `replaced_by_id` points to is still live (never used, not revoked),

  then treat it as a retry, not theft: revoke that unused replacement (reason `retry_superseded`), issue a new token as a child of the presented token, and **update the presented token's `replaced_by_id` to the new token**. Leave the presented token's `revoked_at` unchanged, so repeated retries can never stretch the window past 60 seconds from the original rotation. Updating the pointer is what makes a second lost response survivable: the next retry follows the pointer to the token that is actually live.
- **Reuse detection:** any other presentation of a revoked token (outside the window, after its live replacement was used, or after logout) is reuse. Revoke the family row and every live token in it with reason `reuse_detected`, and return 401 `refresh_invalid`.
- **Logout:** lock the family the same way, then revoke the family row and every live token in it with reason `logout`.
- An expired token also returns 401 `refresh_invalid`. That code is the only response that tells the client its session is truly over.
- At any moment a family has at most one live refresh token. Preventing parallel refreshes on the client is still the app's job (section 10), the grace window only covers lost responses.
- Handle availability: `GET /auth/handle-available?handle=` is anonymous and returns only `{ "available": true | false }`, nothing about the user. Rate limit 20 per minute per IP. Registration still enforces uniqueness itself, so a race between check and submit returns 409 `handle_taken`.
- Rate limits: login and register at 5 per minute per IP. Handle check at 20 per minute per IP. Transfers and conversions at 30 per minute per user.
- All rate limits come from configuration (`RateLimits` section of appsettings), not constants, so integration tests can raise them (section 11).
- All endpoints except register, login, refresh, handle-available and health require auth.
- Users can only read their own accounts and transactions. Write a test for this.
- Errors use RFC 7807 problem details with a stable `code` field (for example `insufficient_funds`). Never leak stack traces.
- CORS off (mobile only). HTTPS assumed in production.
- Log every login, failed login, transfer, conversion and token revocation to `audit_log`.

## 8. API

Base path `/api/v1`. JSON, camelCase. Amounts in JSON are objects: `{ "minor": 2500, "currency": "GEL" }`. Never send money as a float.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | /auth/handle-available?handle=@nino | anonymous, returns only `{ available }` |
| POST | /auth/register | create user, accounts and starter grant |
| POST | /auth/login | returns access and refresh tokens |
| POST | /auth/refresh | rotate refresh token |
| POST | /auth/logout | revoke current refresh token family |
| GET | /me | profile |
| GET | /accounts | user's three accounts with balances |
| GET | /accounts/{id}/transactions | paged history for one account (cursor paging, newest first) |
| GET | /transactions | paged history across all accounts |
| GET | /transactions/{id} | detail, with entries the user is allowed to see |
| GET | /users/lookup?handle=@nino | find a recipient (returns display name and handle only) |
| POST | /transfers | send money (Idempotency-Key required) |
| GET | /fx/rates | current rates, with rate date |
| POST | /fx/quote | create a 60-second quote: quoteId, amount in, net out, fee, rate, rate date, expiresAt |
| POST | /conversions | execute a quote, body `{ quoteId }` (Idempotency-Key required) |
| GET | /health | liveness and database check |

Also expose OpenAPI at `/openapi` in development.

## 9. Design system (the second most important section)

### 9.1 Principles

1. **Calm.** Lots of white space. One thing per screen. Nothing shouts.
2. **Numbers first.** Balances and amounts are the heroes of every screen. Everything else is quiet.
3. **One accent color**, used only for the primary action and key highlights. Everything else is neutral.
4. **Flat.** No drop shadows, no gradients, no glassmorphism. Separate things with space first, hairline borders second.
5. **Consistent.** Every value below is a token. No magic numbers in widgets. If a design need is not covered by a token, add a token, do not hardcode.
6. **Trust.** Every money action has a clear review step, clear confirmation and a clear result. No surprises.

### 9.2 Color tokens

Define these in `design/tokens.dart` as a `ThemeExtension`, with light and dark values. The app follows the system theme.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| bg | #FFFFFF | #0B0B0C | screen background |
| surface | #F5F5F4 | #161618 | cards, input fields |
| surfaceRaised | #FFFFFF | #1E1E21 | bottom sheets |
| border | #E7E5E4 | #2A2A2E | hairline dividers, 1px |
| textPrimary | #0C0A09 | #FAFAF9 | main text, amounts |
| textSecondary | #57534E | #A8A29E | labels, captions |
| placeholder | #6E6A66 | #9A9AA0 | input placeholders and hint text |
| textDisabled | #A8A29E | #6B6B70 | disabled controls only |
| accent | #3B4BF5 | #5360F5 | fills: primary buttons, active toggles |
| accentText | #3B4BF5 | #8C96FF | accent used as text, links, icons |
| onAccent | #FFFFFF | #FFFFFF | text on accent fills |
| positive | #15803D | #4ADE80 | incoming money, success |
| negative | #B91C1C | #F87171 | errors only |
| warningBg | #FEF3C7 | #3A2E0A | warning banners |

Rules:

- Outgoing amounts are shown in `textPrimary` with a minus sign, not in red. Red means "error", never "you spent money".
- Incoming amounts are shown in `positive` with a plus sign.
- Text must meet WCAG AA contrast (4.5:1) against the surface it sits on. Placeholders count as text, so they use `placeholder`, never `textDisabled`. Only genuinely disabled controls use `textDisabled` (WCAG exempts inactive components).
- Accent as a fill uses `accent`, accent as text or an icon uses `accentText`. In light mode they are the same value, in dark mode they are not: white text on the dark `accentText` value would fail contrast.
- Write a unit test that computes contrast for every text-on-surface pair the app uses and fails below 4.5:1. At minimum: textPrimary, textSecondary, placeholder, accentText, positive and negative on bg, surface and surfaceRaised; onAccent on accent. All pairs in this table pass in both modes (checked when this spec was written).

### 9.3 Typography

Font: Inter, via google_fonts. Amounts always use tabular figures (`FontFeature.tabularFigures()`) so digits don't jump when values change.

| Token | Size / line height | Weight | Use |
| --- | --- | --- | --- |
| displayAmount | 44 / 52 | 600 | total balance on home |
| titleAmount | 32 / 40 | 600 | account balance, transfer amount |
| headline | 24 / 32 | 600 | screen titles |
| title | 17 / 24 | 600 | section titles, list primary |
| body | 15 / 22 | 400 | normal text |
| label | 13 / 18 | 500 | captions, list secondary, chips |
| micro | 11 / 14 | 500 | rare metadata, uppercase with 0.5 letter spacing |

The decimal part of large amounts (the ".56" in "1,234.56") is shown in the same size but in `textSecondary`. This small touch makes balances feel premium.

### 9.4 Spacing, radius, sizing

- Spacing scale (4pt grid): 4, 8, 12, 16, 24, 32, 48, 64. Screen side padding is 24.
- Radius: 8 (chips), 12 (inputs, small cards), 16 (cards), 24 (bottom sheets), full (avatars, round buttons).
- Minimum tap target: 48 by 48.
- Primary button height: 56. Full width, radius 16.
- List row height: 64 minimum.

### 9.5 Motion

- Durations: 150 ms (small state changes), 250 ms (screen-level transitions). Curve: `Curves.easeOutCubic`. No bounce, no spring overshoot.
- Balance changes animate with a short count-up (300 ms).
- Respect the system "reduce motion" setting: when it is on, no animations except fades.
- Haptics: light impact on keypad presses, success notification haptic when a transfer completes.

### 9.6 Components

Build these in `design/components/`, each with a widget test. Screens are assembled only from design-system components. The list below is the minimum: if a screen needs something new, add it as a reusable component in `design/components/` (with tokens and a widget test), never as one-off styling inside a screen.

- **TetriScaffold**: safe area, side padding 24, optional large title that collapses on scroll.
- **AmountText**: formats money from minor units. Currency symbol, thousand separators, two decimals, tabular figures, dimmed decimal part, optional sign and color rules from 9.2. This is the only way an amount is ever shown.
- **PrimaryButton / SecondaryButton / TextButton**: loading state (spinner replaces label, width stays fixed), disabled state.
- **AccountCard**: currency flag circle, currency name, balance. Used in a horizontal pager on home.
- **TransactionRow**: avatar or icon (left), title and subtitle (middle), AmountText (right). Grouped under date headers ("Today", "Yesterday", "12 Oct").
- **AmountKeypad**: custom number pad (1 to 9, decimal point, 0, backspace). Large keys, no borders. Prevents more than 2 decimals and leading zeros.
- **ReviewSheet**: bottom sheet with a summary table (to, amount, fee, rate, total) and a confirm button.
- **StatusView**: full-screen success or failure state with a single icon, a headline, the amount and one action.
- **EmptyState**: icon, one line, optional action.
- **Skeleton**: shimmer-free loading placeholders (soft pulsing surface blocks), never spinners on full screens.
- **InlineBanner**: info and warning messages.
- **Avatar**: initials on a neutral surface circle, with a color derived deterministically from the user id from a short palette of muted tones.
- **TextInput**: label above, `surface` fill, radius 12, no border at rest, 1px `accent` border on focus, `placeholder` hint text, error text in `negative` below. Variants: plain, password (show/hide), search (leading icon).
- **CurrencyPicker**: a row showing the selected account (flag circle, currency, balance) that opens a bottom sheet list of accounts.
- **Switch**: custom styled toggle using `accent` when on.
- **SegmentedControl**: for filters and the theme setting.
- **FilterChip**: for the activity filter row.

### 9.7 Formatting

- GEL shows as `₾1,234.56`, USD as `$1,234.56`, EUR as `€1,234.56`.
- Dates in lists: "Today", "Yesterday", then "12 Oct", and "12 Oct 2025" for previous years. Times as 24-hour "14:05".
- Handles are always shown with `@`.

### 9.8 Copy tone

Short, plain, human. "Sent", not "Transaction successfully completed". "Not enough money in your GEL account", not "Error: insufficient funds". No exclamation marks. Every error message tells the user what to do next.

## 10. Screens

Every screen must handle four states: loading (skeleton), empty, error (with retry), and content.

1. **Welcome**: wordmark, one line ("Simple money, done right." or similar), Create account and Sign in buttons. A small "Sandbox, no real money" label.
2. **Sign up**: one field per step (email, name, handle, password), with a progress indicator. Handle availability is checked as you type against `GET /auth/handle-available` (debounced 400 ms). If registration still returns `handle_taken`, go back to the handle step with that message.
3. **Sign in**: email and password. After the first sign in, offer to enable biometric unlock.
4. **Lock screen**: on app open with biometrics enabled, unlock with Face ID or fingerprint. The refresh token lives in secure storage and is only read after biometric success.
5. **Home**: greeting with first name, total balance in GEL equivalent (displayAmount), an account card pager (GEL, USD, EUR), two quick actions (Send, Convert) as round icon buttons with labels, and recent activity (last 5 rows) with "See all".
6. **Account detail**: balance (titleAmount), account actions, and full history for that account with infinite scroll.
7. **Send money**, a four-step flow:
   1. Recipient: search by handle, recent recipients at the top.
   2. Amount: big amount display, AmountKeypad, account picker (which currency), available balance shown below in label style. The Continue button is disabled when the amount is zero or above the balance.
   3. Review: ReviewSheet. The idempotency key is generated here, when the review opens, and reused on every retry of this same confirmation.
   4. Result: StatusView. On network timeout, retry automatically with the same key, then show the real result.
8. **Convert**: from and to account pickers, amount keypad, live preview (rate, fee, you get) refreshed when the amount changes (debounced 300 ms). Continue creates a fresh quote and opens the review with exactly the quoted numbers and the NBG rate date. Confirm sends that `quoteId`. On `quote_expired`, fetch a new quote and show the review again with a short note that the rate was refreshed; never execute terms the user did not see.
9. **Activity**: all transactions grouped by date, with a filter chip row (All, Sent, Received, Conversions).
10. **Transaction detail**: big amount, status, counterparty, date and time, reference id (copyable), and for conversions the rate and fee.
11. **Settings**: profile, biometric toggle, theme (system, light, dark), about (version, link to the GitHub repo), sign out.

**Token refresh in the app:** the dio interceptor refreshes on 401 through a single shared operation. If several requests get a 401 at the same time, only the first starts a refresh. The rest wait for that same result, then retry with the new access token. A refresh is never run twice in parallel.

Refresh outcomes are handled by type, and only one of them signs the user out:

- **Success:** save the new tokens to secure storage before using them, then retry the waiting requests.
- **401 `refresh_invalid`:** the session is truly over. Clear tokens and go to sign in. This is the only case that signs the user out.
- **Timeout or dropped connection:** the server may already have rotated the token. Keep the old token and retry the refresh with it (the server's 60-second grace window accepts this). Retry up to 3 times with backoff (1, 2, 4 seconds), all inside the same single-flight operation.
- **No network, 5xx, 429:** keep the tokens. The waiting requests fail with a retryable "Can't reach Tetri" error, screens show their error state with a Retry button, and an InlineBanner shows the offline state. The next request that gets a 401 starts a fresh refresh attempt.

Known edge case, documented in the README: if a refresh response is lost and the device stays offline for more than 60 seconds, the next refresh is treated as reuse and the user has to sign in again. That trade-off favors security over convenience, which is right for a bank.

## 11. Testing requirements

### Backend unit tests

- Conversion math and rounding: G, N and F for normal, tiny and large amounts; F = G - N always; N = 0 is rejected.
- Money formatting and parsing.
- Request hashing for idempotency is stable for the same body regardless of key order.
- NBG feed parsing from the saved sample, including quantity normalization.

### Backend integration tests (real Postgres via Testcontainers)

Rate limiting: the shared test host raises every rate limit through configuration (section 7), so ledger, concurrency and idempotency tests are never throttled. Rate limiting gets its own tests with the real configured limits.

- Starter grant: posting it for a new user creates three funded accounts, and the funding accounts go negative by exactly the granted amounts. In Phase 2 this is tested by calling the ledger service directly. From Phase 3 it is also tested through `POST /auth/register`.
- Transfer moves money and writes exactly two entries that sum to zero.
- Transfer with insufficient funds fails and writes nothing.
- **Concurrency test:** an account with 100.00 GEL receives 50 parallel transfer requests of 10.00 GEL each, all with different idempotency keys. Exactly 10 succeed, 40 fail with `insufficient_funds`, and the final balance is exactly 0. Run it 20 times in a loop in the test to catch flakiness.
- **Deadlock test:** A sends to B and B sends to A at the same time, many times in parallel. No deadlock errors, and balances are correct.
- **Idempotency tests:**
  - Same key and body twice returns the identical response and moves money once.
  - Same key with a different body returns 422. Same key on a different endpoint returns 422.
  - Two parallel requests with the same key: money moves once, and the loser gets either the stored response or 409 `request_in_progress`.
  - A rejection (`insufficient_funds`) is cached: retrying the same key returns the same rejection even after the account is topped up.
  - A stale claim (`in_progress` with `locked_until` in the past, simulated by inserting the row directly) is taken over and the request completes normally.
- **Takeover race tests** (use the test hooks from 5.7; each asserts exactly one debit, the stored response, and the invariant check):
  - *Paused after claim:* worker A claims and pauses. Expire A's `locked_until` directly in the database. Worker B, same key and body, takes over and succeeds. Resume A. A's transaction 2 finds its token replaced and writes nothing. Exactly one debit, and the stored response is B's.
  - *Paused inside transaction 2:* worker A claims and pauses at the after-claim hook. Backdate A's `locked_until` directly in the database (nobody holds the row lock yet, so this does not block). Resume A until it pauses at the before-commit hook inside transaction 2, now holding the key row lock. Send B with the same key. B's takeover waits on the lock. Resume A, which commits. B then sees `completed` and returns A's stored response (or 409 if its 2-second lock timeout hit first). Exactly one debit.
  - *Stale rejection:* the sender's account is empty. Worker A gets `insufficient_funds` and pauses before storing the rejection. Expire `locked_until`, top up the account, and B takes over and succeeds. Resume A. A's rejection write affects zero rows. The stored response is still B's success, and exactly one debit exists.
- **Conversion tests:** a conversion writes five entries matching the quote exactly, each currency's entries in the transaction sum to zero, and the fees account grows by F. Expired quote returns 409 `quote_expired`, reused quote returns 409 `quote_used`, another user's quote returns 404.
- **Constraint tests:** entries cannot be updated or deleted; a second funding account for the same currency is rejected; a user-kind account without an owner is rejected; an entry whose currency differs from its account's is rejected.
- A user cannot read another user's accounts or transactions (403 or 404).
- Handle availability returns only `available`, and is rate limited.
- **Refresh tests:**
  - Normal rotation: the old token is revoked as `rotated` and the new one works.
  - Retry within the grace window (old token presented again while its replacement is unused): succeeds, the unused replacement is revoked as `retry_superseded`, the old token's `replaced_by_id` now points to the new token, its `revoked_at` is unchanged, and the family stays alive with exactly one live token.
  - Two consecutive lost responses: rotate T1 (response dropped), retry T1 (response dropped again), retry T1 a third time within 60 seconds. The third retry succeeds, the family has exactly one live token, and it is not revoked.
  - Grace window does not stretch: after several retries, a retry more than 60 seconds after T1's original rotation is treated as reuse.
  - Overlapping grace retries: two retries with the same old token at the same time. Both complete without revoking the family, and the family ends with exactly one live token.
  - Logout racing a refresh: logout and a rotation for the same session at the same time. Afterwards no live token remains in the family, whichever ran first.
  - Old token presented after 60 seconds (simulate by backdating `revoked_at`): the whole family is revoked as `reuse_detected`, 401 `refresh_invalid`.
  - Old token presented after its replacement was already used: the whole family is revoked, 401 `refresh_invalid`.
  - Two concurrent refreshes with the same token: the family is never left with two live tokens, and it is not revoked.
  - Unknown, expired and logged-out tokens all return 401 `refresh_invalid`.
- **Rate limit tests:** with the real limits, the 6th login in a minute from one IP returns 429, and the 31st transfer in a minute from one user returns 429.
- **Ledger invariant check**, run at the end of every integration test class:
  - For every (transaction_id, currency) pair, the entries sum to exactly zero. Checking only a global sum is not enough, because two wrong transactions could cancel each other out.
  - Every account's cached balance equals the sum of its entries.
  - Every entry's currency equals its account's currency.
  - No user account has a negative balance.

### Mobile tests

- AmountText formatting for all three currencies, negative and positive, large values.
- AmountKeypad input rules.
- Send flow: idempotency key is the same across retries of one confirmation and different for a new transfer.
- Convert flow: on `quote_expired`, the app fetches a new quote and returns to the review instead of executing.
- Token refresh: when three requests get 401 at once, the refresh endpoint is called exactly once and all three requests are retried with the new token.
- Refresh failure handling: 401 `refresh_invalid` clears tokens and routes to sign in; a timeout retries with the same old token; no network, 5xx and 429 keep the tokens and show the retryable error state. Only the first case signs the user out.
- Widget tests for each design component.
- Golden tests for Home and the Send review sheet, in light and dark mode.

## 12. Build phases

### Phase 1: backend foundation
Solution structure, Docker Compose with Postgres, EF Core schema and migrations (all constraints and partial indexes from 5.5, the seeded system accounts), the entries and audit insert-only triggers, health endpoint, backend CI job.
**Done when:** `docker compose up` starts Postgres and the API, `/api/v1/health` returns OK, the constraint tests from section 11 pass, the backend CI job is green.

### Phase 2: ledger and transfers
Ledger service, transfer endpoint, idempotency exactly as in 5.7, starter grant (called directly from tests, since registration comes in Phase 3), and these section 11 tests: starter grant via the service, transfers, concurrency, deadlock, all idempotency tests including the three takeover race tests, constraint tests, invariant check. `docs/ledger.md` written. Until auth exists, tests authenticate with a test-only user header that the test host enables and production never registers.
**Done when:** all of the tests above pass, run 3 times in a row with no flakes.

### Phase 3: auth and the rest of the API
Register (now also covered by the registration test), handle availability, login, refresh rotation, logout, rate limiting, ownership checks, history endpoints with cursor paging, user lookup, NBG rates, quotes and conversions, audit logging, problem details errors. Remove the test-only user header and switch tests to real tokens.
**Done when:** every endpoint in section 8 works, every **backend** test in section 11 passes, OpenAPI is browsable in dev.

### Phase 4: design system
Flutter project, theme tokens (light and dark), typography, all components from 9.6 with widget tests, plus a hidden "component gallery" screen (dev builds only) that shows every component in every state. Add the Flutter CI job.
**Done when:** the gallery shows all components in light and dark mode, the contrast test passes, `flutter analyze` has zero warnings, both CI jobs are green.

### Phase 5: app screens
All screens from section 10 wired to the real API, biometric lock, secure token storage, single-flight token refresh, all four states per screen.
**Done when:** a new user can sign up, see the starter balances, send money to a second user, convert USD to GEL, and see everything in activity, on a real Android device. Every mobile test in section 11 passes, including golden tests.

### Phase 6: polish and ship
Count-up balance animation, haptics, reduce-motion support, app icon and splash, deploy the API (a container host such as Fly.io or Render, with a managed Postgres such as Neon), build a release APK attached to a GitHub release, screenshots in `docs/screenshots/`, final README.
**Done when:** someone with only the README can install the APK and use the deployed app.

## 13. README requirements

The README is written for a hiring engineer with two minutes. In this order:

1. One line on what Tetri is, plus a "sandbox, no real money" note.
2. Three to four screenshots side by side (light and dark).
3. "Try it": APK download link and demo account credentials.
4. "How the money works": three short paragraphs on the double-entry ledger, lock ordering, and idempotency, linking to `docs/ledger.md`.
5. "Proof": the concurrency test explained in two sentences, with its CI badge.
6. Tech stack list.
7. Run locally: `docker compose up`, then `flutter run`, with the exact commands.
8. Project structure.

## 14. Definition of done for the whole project

- Every phase's checks pass.
- CI is green on main.
- No TODOs, commented-out code or debug prints left in.
- The ledger invariant holds after every test run.
- The app looks consistent in light and dark mode on a small phone (360 dp wide) and a large one.
- The README and `docs/ledger.md` are complete and accurate.