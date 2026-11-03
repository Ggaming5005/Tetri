# Verification record

This record separates automated checks, observed Android behavior and work still needed before release. It preserves the phase history previously kept in the README. Counts below describe the suite at each recorded gate, not separate tests to add together.

## Current status

As recorded on **3 November 2026**, [CI run 41689180899](https://github.com/Ggaming5005/Tetri/actions/runs/41689180899) passed both jobs:

- **185 backend tests**: 56 unit and 129 real PostgreSQL integration tests, with the full suite run three consecutive times.
- **289 Flutter tests**, including light/dark Home and Send-review goldens, with analysis reporting zero issues.
- Docker Compose builds and starts the API and PostgreSQL, then passes the HTTP health check.

Phases 1–4 have passed their gates. Phase 5 screens are implemented and most Android acceptance checks have passed. **The real-device conversion check remains open.** Phase 6 deployment and release work has not started; the README previews were added at the user's request and do not signify a release gate passing.

## Android evidence and remaining checks

| Environment | Observed result |
| --- | --- |
| Android API 36 emulator, 360 dp wide | Light/dark component gallery and transfer review visually checked; debug APK runs |
| Android emulator, banking app | New user received all three starter balances and sent 25.00 GEL to a second user; activity displayed the transfer; API reads confirmed GEL balances of 975.00 and 1,025.00 |
| Physical Android phone | New user registered and received all three starter balances; enabled and authenticated biometric unlock; sent 12.50 USD using the native keyboard; activity displayed the transfer; API read confirmed the remaining USD balance of 287.50 |
| Physical Android phone after upgrading/reopening | Biometric unlock was required and the saved session was restored |
| Live FX conversion | Pending: the undated NBG feed supplied rates effective **4 November 2026**, which the fresh local database refused to use before that UTC date; it returned `rates_unavailable` |

Conversion controller tests and real PostgreSQL conversion API tests pass with controlled rate fixtures. They do not replace the remaining physical-device conversion check against effective live rates. A published release APK, hosted API and final install-from-README acceptance are also pending.

### What the README images show

The four README images are **360 × 800 UI previews rendered from the actual Flutter widgets with deterministic demo fixtures**. Home and transfer review use the strict golden-test scenes; Convert and Sent use dedicated preview scenes. They demonstrate layout and styling, not live account data or proof that the live FX check passed. [Image provenance](screenshots/previews.md) records the sources and illustrative values.

| Preview | File |
| --- | --- |
| Home, light | [home-light.png](screenshots/home-light.png) |
| Convert, dark | [convert-dark.png](screenshots/convert-dark.png) |
| Transfer review, light | [transfer-review-light.png](screenshots/transfer-review-light.png) |
| Sent, dark | [sent-dark.png](screenshots/sent-dark.png) |

The separate [native-keyboard capture](screenshots/native-keyboard.png) comes from an Android emulator connected to the local API. It shows entering 12.50 USD before review; that capture does not show a confirmed payment.

The [design review](design-review.md) records the official banking-app references and resulting layout decisions. Send and Convert use the native decimal keyboard. Home, Payments and Activity have compact headers with profile access; Settings is a secondary page. Tests cover account indicators, centered results, keyboard-aware actions and long amounts across small phones, landscape, tablets and enlarged text.

## Run the checks

Start Docker Desktop's Linux container engine. From the repository root in PowerShell:

```powershell
dotnet tool restore
dotnet restore backend/Tetri.sln --locked-mode
dotnet build backend/Tetri.sln --configuration Release --no-restore
dotnet test backend/Tetri.sln --configuration Release --no-build
```

Integration tests create isolated PostgreSQL containers; they never use the Compose database. CI runs that final test command three consecutive times. It also builds the API container, starts Compose and checks `/api/v1/health`. The .NET SDK is pinned in `global.json`, NuGet lock files are committed, and both Compose and tests use PostgreSQL `17.11-alpine`.

Run the mobile checks with Flutter **3.47.9**:

```powershell
cd mobile
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
```

Golden references use **Windows and Flutter 3.47.9**, matching the Flutter CI job. They compare exact pixels. Font rasterization can differ across operating systems, as described in [Flutter's golden-test documentation](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html). Regenerate references on the matching platform and visually review every change.

### What the automated checks cover

- Integer money formatting/parsing, canonical request hashing, FX rounding and a saved real NBG response.
- Schema constraints, repeatable migrations, immutable entries/audit records, seeded system accounts and database health failures.
- Exactly two balanced transfer entries; failed transfers write no money; simultaneous spending, opposite-direction transfers and deterministic idempotency takeover races.
- Per-journal/per-currency balancing, cached balances matching entry sums, entry/account currency agreement and nonnegative user balances. Each integration test class checks invariants before disposing its database.
- Real JWT authentication, ownership isolation, refresh rotation and reuse handling, production-default rate limits in dedicated tests, history, stored quotes and conversions.
- Simultaneous mobile token refresh, transport failures, retained payment retry keys, expired quote review, calendar-only rate dates, biometric/background lock state and component behavior.
- Light/dark Home and Send-review goldens, contrast checks, responsive layouts, native amount input and navigation.

All protected API endpoints use real JWT access tokens, including HTTP integration tests; the API has no test authentication scheme. Most HTTP tests raise rate limits to isolate their subject, while dedicated limit tests use production defaults. EF reads and raw SQL share one connection pool, capped by `Database:MaxPoolSize` (64 by default).

## Phase history

### Phase 1 — backend foundation

- Release build passed with zero warnings/errors.
- Local PostgreSQL tests passed with Docker Desktop and WSL 2.
- All **27 tests** passed on the CI Docker host, with zero skipped tests.
- Compose startup and HTTP health passed locally and in CI.
- Evidence: [Phase 1 CI, 41667540405](https://github.com/Ggaming5005/Tetri/actions/runs/41667540405).

### Phase 2 — ledger and transfers

- **41 unit tests and 63 integration tests** passed, with zero skipped tests.
- Coverage included concurrency, takeover races and malformed JSON regressions.
- The full suite passed three consecutive runs locally and in CI against real PostgreSQL.
- Evidence: [Phase 2 CI, 41670862692](https://github.com/Ggaming5005/Tetri/actions/runs/41670862692).

### Phase 3 — authentication and complete API

- Registration, login, refresh/logout, handle availability, account/history reads, lookup, rates, quotes and conversions were implemented.
- **56 unit tests and 129 integration tests** passed locally with zero skipped tests. Release build and formatting checks passed with zero warnings/errors.
- CI passed three consecutive full-suite runs and the Compose check. Development OpenAPI listed all **16 routes**.
- Evidence: [Phase 3 CI, 41673814461](https://github.com/Ggaming5005/Tetri/actions/runs/41673814461).

Refresh retries never extend the original **60-second grace window**. If a refresh response is lost and the device remains offline longer than that, the next retry ends that session and requires sign-in. Network errors, 429 and 5xx alone do not discard the saved session. The [API guide](api.md) describes the exact protocol.

### Phase 4 — design foundation

- All required components, theme tokens and typography were implemented; analysis reported zero issues.
- **113 Flutter tests** covered components, **38 required contrast pairs**, additional state/avatar contrast, minor-unit formatting, keypad boundaries, reduced motion and the small-phone gallery in both themes.
- The debug APK built and ran on an Android API 36 emulator at 360 dp width; light/dark gallery screens and transfer reviews were visually checked.
- Both CI jobs passed: 113 Flutter tests, analysis, three consecutive runs of all 185 backend tests and the Compose check.
- Evidence: [Phase 4 CI, 41677108152](https://github.com/Ggaming5005/Tetri/actions/runs/41677108152).

### Phase 5 — app screens, acceptance in progress

- Welcome, stepped signup, sign-in, biometric lock, Home, account history, Send, Convert, Payments, Activity, transaction detail and Settings are wired into the app. Data screens use the real API.
- The latest local suite passes **289 Flutter tests**, analysis reports zero issues and the debug APK builds.
- Emulator and physical-device results are recorded above. The physical-device conversion gate remains open.
- Evidence: [initial Phase 5 CI, 41684578673](https://github.com/Ggaming5005/Tetri/actions/runs/41684578673); [navigation/layout update CI, 41689180899](https://github.com/Ggaming5005/Tetri/actions/runs/41689180899). Both jobs passed in each run; the latest run contains 289 Flutter tests and three full runs of the 185 backend tests.

## Design assets and compatibility

Inter and the Phosphor icon font are bundled. Currency flag circles are drawn locally, so rendering needs no font or image download. The debug-only component gallery at `/__gallery` offers system/light/dark selection and loading, disabled, empty, success and failure previews; launch it with `flutter run --dart-define=TETRI_GALLERY=true` or long-press the Welcome wordmark.

The icon dependency is `phosphor_glyphs`: it preserves the chosen Phosphor outline set while supporting this Flutter SDK's final `IconData` class. The older `phosphor_flutter` and `lucide_icons` packages named in the original specification did not compile with this SDK. [Artwork explorations and prompts](design-assets.md) are retained; shaded bitmap candidates are not included in the app.
