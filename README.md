# Tetri

Tetri is a small multi-currency digital bank built with Flutter and ASP.NET Core. **Sandbox only: no real money.**

Phase 1, the backend foundation, is verified. Phase 2 adds ledger posting and transfers. Mobile screens and screenshots arrive in Phases 4–5.

## Try it

The local API is available through the commands below. An APK, hosted demo and demo accounts will be available after the later build phases; this revision does not expose registration or money movement.

## How the money works

The database models a double-entry ledger. Every journal must balance separately in each currency. Amounts and cached account balances use integer minor units, and ledger entries are insert-only. The Phase 1 migration creates this schema and protects entries and audit rows from updates, deletes and truncation.

Phase 2 will implement posting with ordered account row locks inside one PostgreSQL transaction. User balances have a database constraint preventing negative values. Tests will compare each cached balance with its ledger entries.

Transfers and conversions will require idempotency keys. A claim ownership token and locked key row will prevent retries and stale workers from moving money twice. The worked ledger example and detailed posting documentation belong to Phase 2.

## Proof

[![CI](https://github.com/Ggaming5005/Tetri/actions/workflows/ci.yml/badge.svg)](https://github.com/Ggaming5005/Tetri/actions/workflows/ci.yml)

Phase 1 tests use PostgreSQL 17 through Testcontainers to verify schema constraints, migration repeatability, immutable ledger/audit tables, seeded system accounts, and healthy/unavailable database responses. Each integration test class also checks ledger invariants before disposing its database.

The Phase 2 concurrency test will send 50 competing requests against a 100.00 GEL balance, requiring exactly ten 10.00 GEL transfers to succeed. It will repeat that scenario twenty times and run alongside deadlock and idempotency takeover tests.

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

Development OpenAPI is available at [localhost:5080/openapi](http://localhost:5080/openapi). It exposes the health endpoint in this phase.

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

Tests create isolated PostgreSQL containers; they never use the Compose database. The unit-test project is reserved for Phase 2 domain behavior; Phase 1 checks are integration tests. CI also builds the API container, starts Compose and checks the HTTP health endpoint.

The mobile project will be introduced in Phase 4. Flutter run instructions will be added when that project exists.

## Project structure

```text
backend/
  Tetri.sln
  src/
    Tetri.Api/              Health endpoint, logging and startup
    Tetri.Core/             Domain entity types
    Tetri.Infrastructure/   EF mappings, migrations and database factory
  tests/
    Tetri.UnitTests/        Domain tests from Phase 2
    Tetri.IntegrationTests/ PostgreSQL constraint and API tests
.github/workflows/ci.yml    Backend build, tests and Compose smoke check
docker-compose.yml         Local PostgreSQL and API
AGENTS.MD                  Product specification and phase gates
```

## Phase 1 verification status

- Release build: passes with zero warnings and zero errors.
- Local PostgreSQL tests: blocked because the Docker engine requires WSL installation. Docker Desktop is installed; Windows administrator approval is still needed for `wsl --install --no-distribution`.
- PostgreSQL tests on the CI Docker host: all 27 pass, with zero skipped tests.
- Docker Compose startup and HTTP health: pass on the CI Docker host.
- GitHub CI: [Phase 1 verification passed](https://github.com/Ggaming5005/Tetri/actions/runs/41667540405).
- Phase 2 begins after these checks; no ledger posting endpoint is included in this foundation revision.
