# Tetri

Tetri is a small multi-currency digital bank built with Flutter and ASP.NET Core. **Sandbox only: no real money.**

Phases 1–4 are verified: the ledger, authentication, account history, official exchange rates, quoted conversions and Flutter design system. App screens are next in Phase 5.

## Try it

The local API is available through the commands below. Register two users to try transfers and currency conversion; [the API guide](docs/api.md) describes the requests, session handling and response shapes. An APK, hosted demo and demo accounts will be available after the mobile phases.

## How the money works

The database models a double-entry ledger. Every journal must balance separately in each currency. Amounts and cached account balances use integer minor units, and ledger entries are insert-only. The Phase 1 migration creates this schema and protects entries and audit rows from updates, deletes and truncation.

Posting takes ordered account row locks inside one PostgreSQL transaction. User balances have a database constraint preventing negative values. Integration tests compare each cached balance with its ledger entries, and an hourly reconciliation checks the same invariants without modifying money.

Transfers and conversions require idempotency keys. A claim ownership token and locked key row prevent retries and stale workers from moving money twice. Successful responses commit with the money movement, and guarded rejection caching preserves final outcomes. Conversions execute the exact amounts in a stored 60-second quote. See [the worked ledger example](docs/ledger.md) for the rows written when Giorgi sends 25.00 GEL to Nino.

## Proof

[![CI](https://github.com/Ggaming5005/Tetri/actions/workflows/ci.yml/badge.svg)](https://github.com/Ggaming5005/Tetri/actions/workflows/ci.yml)

Phase 1 tests use PostgreSQL 17 through Testcontainers to verify schema constraints, migration repeatability, immutable ledger/audit tables, seeded system accounts, and healthy/unavailable database responses. Each integration test class also checks ledger invariants before disposing its database.

The concurrency test sends 50 competing HTTP requests against a 100.00 GEL balance, requiring exactly ten 10.00 GEL transfers to succeed. It repeats that scenario twenty times, alongside opposite-direction transfers and deterministic idempotency takeover races; CI runs the entire backend suite three consecutive times.

## Tech stack

- .NET 10, ASP.NET Core minimal APIs, EF Core and Npgsql
- PostgreSQL 17, Docker Compose
- xUnit, FluentAssertions and Testcontainers
- Serilog and GitHub Actions
- Flutter 3.47.9, Riverpod, go_router and dio
- Bundled Inter, Phosphor outline icons, light/dark semantic themes

The .NET SDK is pinned in `global.json`; NuGet lock files are committed. Docker Compose and tests use PostgreSQL `17.11-alpine`.

## Run locally

Install Docker Desktop with Linux containers and start its engine. The .NET 10 SDK is needed to build and run tests outside Docker.

From the repository root in PowerShell:

```powershell
Copy-Item .env.example .env
notepad .env
```

Set `POSTGRES_PASSWORD` to a long random local password and `JWT_SIGNING_KEY` to a separate random secret of at least 32 bytes, save, then run:

```powershell
docker compose up --build -d --wait
Invoke-RestMethod http://localhost:5080/api/v1/health
```

The health response is `{"status":"ok","database":"ok"}`. On first startup the API applies the committed migrations after PostgreSQL becomes healthy. Database data persists in the `postgres_data` volume. Ports bind to localhost; `.env` is ignored by Git.

Development OpenAPI is available at [localhost:5080/openapi](http://localhost:5080/openapi). All protected endpoints require real JWT access tokens, including during HTTP integration tests. There is no test authentication scheme in the API.

The NBG feed may publish tomorrow's rates. A fresh database with only future-dated rates returns `503 rates_unavailable` until those rates become effective; existing valid rates stay available during fetch failures. This never prevents registration, account history or same-currency transfers.

Stop the services without deleting database data:

```powershell
docker compose down
```

Build and run the tests with Docker running:

```powershell
dotnet tool restore
dotnet restore backend/Tetri.sln --locked-mode
dotnet build backend/Tetri.sln --configuration Release --no-restore
dotnet test backend/Tetri.sln --configuration Release --no-build
```

Tests create isolated PostgreSQL containers; they never use the Compose database. Unit tests cover integer money formatting/parsing, stable canonical request hashing, FX rounding and a saved real NBG response. CI also builds the API container, starts Compose and checks the HTTP health endpoint. EF reads and raw SQL share one connection pool, capped by `Database:MaxPoolSize` (64 by default).

Run the development component gallery on Android with the pinned Flutter version:

```powershell
cd mobile
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
flutter run --dart-define=TETRI_GALLERY=true
```

The gallery is available only in debug builds at `/__gallery`; long-press the Tetri wordmark to open it from the brand preview. Its theme selector switches between system, light and dark. Interactive previews include loading, disabled, empty, success and failure states. The actual banking screens are added in Phase 5.

Inter and the original welcome artwork are bundled, so rendering does not require a font or image download. [Artwork provenance and prompts](docs/design-assets.md) are recorded with the project. The icon dependency is `phosphor_glyphs`: it preserves the chosen Phosphor outline set while supporting the latest Flutter's final `IconData` class. The older `phosphor_flutter` and `lucide_icons` packages named in the original spec do not compile with this SDK.

## Project structure

```text
backend/
  Tetri.sln
  src/
    Tetri.Api/              Authenticated endpoints, limits and background jobs
    Tetri.Core/             Domain types, money, FX math and request hashing
    Tetri.Infrastructure/   Persistence, ledger, auth, queries and NBG rates
  tests/
    Tetri.UnitTests/        Money and request hashing tests
    Tetri.IntegrationTests/ PostgreSQL constraints, ledger races and API tests
.github/workflows/ci.yml    Backend build, tests and Compose smoke check
mobile/                    Flutter design system, component gallery and widget tests
docker-compose.yml         Local PostgreSQL and API
AGENTS.MD                  Product specification and phase gates
```

## Phase 1 verification status

- Release build: passes with zero warnings and zero errors.
- Local PostgreSQL tests: pass with Docker Desktop and WSL 2.
- PostgreSQL tests on the CI Docker host: all 27 pass, with zero skipped tests.
- Docker Compose startup and HTTP health: pass locally and on the CI Docker host.
- GitHub CI: [Phase 1 verification passed](https://github.com/Ggaming5005/Tetri/actions/runs/41667540405).

## Phase 2 verification status

- Local unit tests: 41 pass, with zero skipped tests.
- Integration suite: 63 pass, with zero skipped tests, including concurrency, takeover races and malformed JSON regressions.
- The entire suite passed three consecutive runs locally and in [the final Phase 2 CI run](https://github.com/Ggaming5005/Tetri/actions/runs/41670862692), against real PostgreSQL.
- Phase 3 adds authentication, read APIs, rates, quotes and conversions.

## Phase 3 verification status

- Registration, login, session rotation/logout, handle availability, account/history reads, lookup, rates, quotes and conversions are implemented.
- The full suite passes 56 unit tests and 129 PostgreSQL integration tests locally, with zero skipped tests. Release build and formatting checks pass with zero warnings/errors. [Phase 3 CI](https://github.com/Ggaming5005/Tetri/actions/runs/41673814461) passed three consecutive full-suite runs and the Docker Compose check.
- Docker Compose starts the complete API locally; the health check passes and the development OpenAPI document lists all 16 routes.
- HTTP tests use real access tokens; rate-limit tests use the production defaults.
- Refresh retries never extend the original 60-second grace window. If a refresh response is lost and the device remains offline longer than that, the next retry ends that session and requires sign-in.

## Phase 4 verification status

- All required components, theme tokens and typography are implemented. Local analysis reports zero issues.
- 113 tests cover components, 38 required contrast pairs, extra state/avatar contrast, minor-unit formatting, keypad boundaries, reduced motion and a small-phone gallery in both themes.
- The debug APK builds and runs on an Android API 36 emulator at 360 dp width. Light and dark gallery screens and transfer review sheets were visually checked; captures are in `docs/screenshots/`.
- Both jobs passed in [Phase 4 CI](https://github.com/Ggaming5005/Tetri/actions/runs/41677108152): all 113 Flutter tests, analysis with zero issues, and three consecutive runs of all 185 backend tests plus the Compose smoke check.
