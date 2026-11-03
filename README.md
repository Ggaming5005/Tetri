# Tetri

Tetri is a small multi-currency digital bank built with Flutter and ASP.NET Core. **Sandbox only: no real money.**

Phases 1 and 2 are verified: the backend foundation, ledger posting and idempotent transfers. Mobile screens and screenshots arrive in Phases 4–5.

## Try it

The local API is available through the commands below. An APK, hosted demo and demo accounts will be available after the later build phases. Registration and sign-in arrive in Phase 3; the transfer endpoint currently requires authentication supplied only by the integration-test host.

## How the money works

The database models a double-entry ledger. Every journal must balance separately in each currency. Amounts and cached account balances use integer minor units, and ledger entries are insert-only. The Phase 1 migration creates this schema and protects entries and audit rows from updates, deletes and truncation.

Posting takes ordered account row locks inside one PostgreSQL transaction. User balances have a database constraint preventing negative values. Integration tests compare each cached balance with its ledger entries, and an hourly reconciliation checks the same invariants without modifying money.

Transfers require idempotency keys. A claim ownership token and locked key row prevent retries and stale workers from moving money twice. Successful responses commit with the money movement, and guarded rejection caching preserves final outcomes. See [the worked ledger example](docs/ledger.md) for the rows written when Giorgi sends 25.00 GEL to Nino. Conversions will use the same machinery in Phase 3.

## Proof

[![CI](https://github.com/Ggaming5005/Tetri/actions/workflows/ci.yml/badge.svg)](https://github.com/Ggaming5005/Tetri/actions/workflows/ci.yml)

Phase 1 tests use PostgreSQL 17 through Testcontainers to verify schema constraints, migration repeatability, immutable ledger/audit tables, seeded system accounts, and healthy/unavailable database responses. Each integration test class also checks ledger invariants before disposing its database.

The concurrency test sends 50 competing HTTP requests against a 100.00 GEL balance, requiring exactly ten 10.00 GEL transfers to succeed. It repeats that scenario twenty times, alongside opposite-direction transfers and deterministic idempotency takeover races; CI runs the entire backend suite three consecutive times.

## Tech stack

- .NET 10, ASP.NET Core minimal APIs, EF Core and Npgsql
- PostgreSQL 17, Docker Compose
- xUnit, FluentAssertions and Testcontainers
- Serilog and GitHub Actions
- Planned mobile app: Flutter, Riverpod, go_router and dio

The .NET SDK is pinned in `global.json`; NuGet lock files are committed. Docker Compose and tests use PostgreSQL `17.11-alpine`.

## Run locally

Install Docker Desktop with Linux containers and start its engine. The .NET 10 SDK is needed to build and run tests outside Docker.

From the repository root in PowerShell:

```powershell
Copy-Item .env.example .env
notepad .env
```

Set `POSTGRES_PASSWORD` to a long random local password, save, then run:

```powershell
docker compose up --build -d --wait
Invoke-RestMethod http://localhost:5080/api/v1/health
```

The health response is `{"status":"ok","database":"ok"}`. On first startup the API applies the committed migrations after PostgreSQL becomes healthy. Database data persists in the `postgres_data` volume. Ports bind to localhost; `.env` is ignored by Git.

Development OpenAPI is available at [localhost:5080/openapi](http://localhost:5080/openapi). It documents health and transfers. Production never registers the test authentication header.

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

Tests create isolated PostgreSQL containers; they never use the Compose database. Unit tests cover integer money formatting/parsing and stable canonical request hashing. CI also builds the API container, starts Compose and checks the HTTP health endpoint. EF reads and raw SQL share one connection pool, capped by `Database:MaxPoolSize` (64 by default).

The mobile project will be introduced in Phase 4. Flutter run instructions will be added when that project exists.

## Project structure

```text
backend/
  Tetri.sln
  src/
    Tetri.Api/              Endpoints, logging and ledger maintenance
    Tetri.Core/             Domain types, integer money and request hashing
    Tetri.Infrastructure/   EF schema, raw SQL ledger and idempotency
  tests/
    Tetri.UnitTests/        Money and request hashing tests
    Tetri.IntegrationTests/ PostgreSQL constraints, ledger races and API tests
.github/workflows/ci.yml    Backend build, tests and Compose smoke check
docker-compose.yml         Local PostgreSQL and API
AGENTS.MD                  Product specification and phase gates
```

## Phase 1 verification status

- Release build: passes with zero warnings and zero errors.
- Local PostgreSQL tests: pass with Docker Desktop and WSL 2.
- PostgreSQL tests on the CI Docker host: all 27 pass, with zero skipped tests.
- Docker Compose startup and HTTP health: pass on the CI Docker host.
- GitHub CI: [Phase 1 verification passed](https://github.com/Ggaming5005/Tetri/actions/runs/41667540405).

## Phase 2 verification status

- Local unit tests: 41 pass, with zero skipped tests.
- Integration suite: 63 pass, with zero skipped tests, including concurrency, takeover races and malformed JSON regressions.
- The entire suite passed three consecutive runs locally against real PostgreSQL. The preceding CI revision also passed three consecutive runs; [the final regression run](https://github.com/Ggaming5005/Tetri/actions/runs/41670862692) records the final Phase 2 revision.
- Phase 3 adds authentication, read APIs, rates, quotes and conversions.
