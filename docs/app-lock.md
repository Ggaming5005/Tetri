# App PIN and biometric unlock

Tetri supports a **four-digit app PIN** alongside optional fingerprint or Face ID unlock. The PIN belongs to this installation, is separate from the account password and the phone's device passcode, and is never sent to the API. This is a local unlock gate backed by OS secure storage and retry limits; four digits have only 10,000 combinations, so it is not protection against a fully compromised device.

## Setup and session access

PIN setup requires an authenticated session. The user enters and confirms four ASCII digits; leading zeros are valid. Changing an existing PIN also requires the current PIN. A new account sign-in removes the previous session's local PIN before setup, so another account cannot inherit it.

On startup, the app reads the lock settings and PIN record separately from the saved session. If either PIN or biometrics is enabled, it enters `locked` **without reading the stored access or refresh tokens**. Only successful PIN verification or biometric authentication permits session restoration. Malformed PIN records and secure-storage failures fail closed and offer retry or full sign-in recovery.

The app locks when backgrounded. A warm lock hides the existing route, dismisses the keyboard and removes focus from the hidden screen. It preserves an unresolved payment's review and idempotency key. Session generation and authorization checks prevent a late unlock or refresh from reopening the app after another lock/reset; a rotated token pair arriving after lock may still be saved without unlocking.

## Storage and native derivation

[`AppPinController`](../mobile/lib/core/app_pin.dart) stores one versioned record under `tetri.appPin` using `flutter_secure_storage`, separately from `tetri.session`. The encrypted secure-storage record contains the algorithm ID, a fresh 16-byte salt from `Random.secure()`, the 32-byte derived verifier, failure count and UTC attempt/cooldown timestamps. It contains no plaintext PIN. Verification compares all 32 bytes without an early-exit comparison.

The `dev.tetri/pin` method channel uses platform cryptography, with no additional dependency:

| Method | Contract |
| --- | --- |
| `defaultAlgorithm` | Returns `pbkdf2-sha256` on Android API 26+ and iOS; `pbkdf2-sha1` on Android API 24–25 |
| `derive` | Takes exactly `{ pin: String, salt: Uint8List, algorithm: String }`; requires four ASCII digits and exactly 16 salt bytes; returns 32 bytes |

| Stored algorithm | Native construction | Fixed iterations |
| --- | --- | ---: |
| `pbkdf2-sha256` | PBKDF2-HMAC-SHA-256 | 600,000 |
| `pbkdf2-sha1` | PBKDF2-HMAC-SHA-1, legacy compatibility only | 1,400,000 |

Android uses `SecretKeyFactory`/`PBEKeySpec`; iOS uses CommonCrypto's `CCKeyDerivationPBKDF`. Derivation runs off the UI thread, with at most one native request active. Input and failure responses contain no PIN or verifier details. Both adapters accept existing SHA-1 records; Android 24–25 rejects an explicitly requested SHA-256 record rather than silently downgrading it.

Android's [supported `SecretKeyFactory` algorithms](https://developer.android.com/reference/javax/crypto/SecretKeyFactory) explain the API 26 boundary. [Apple's CommonCrypto implementation](https://github.com/apple-oss-distributions/CommonCrypto/blob/main/lib/CommonKeyDerivation.c) supports both selected PBKDF2 functions. The fixed work factors follow [OWASP's PBKDF2 guidance](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html#pbkdf2), which identifies SHA-1 as legacy only; new PINs use SHA-256 wherever the native provider supports it.

## Retry limits and recovery

PIN operations are serialized. Before deriving or comparing a candidate, the app persists the consumed attempt. A process interruption or native failure therefore cannot turn that attempt into a free guess. If a storage write fails, access is not granted, even when the candidate PIN is correct.

| Consecutive unsuccessful attempts | Next PIN attempt |
| --- | --- |
| 1–4 | Allowed immediately |
| 5 | After 30 seconds |
| 6–9 | After 60, 120, 240 and 480 seconds respectively |
| 10 | PIN unlock stays paused until successful biometrics or full sign-in recovery |

The counter and cooldown survive process restarts. A backwards clock change blocks attempts until the recorded time is reached; advancing the clock cannot bypass the hard limit of ten attempts. Successful PIN verification resets the counter. Successful biometric authentication also resets it, so fingerprint/Face ID remains a recovery option during a PIN cooldown or pause.

**Forgot PIN / Sign in instead** asks for confirmation, then deletes this device's saved tokens, PIN and biometric preference without first reading the locked tokens. It requires the account email and password to sign in and set a new PIN. This local reset does not contact the API or revoke the previous server session. Account balances and history remain on the server.

Unlike a warm lock, an explicit local reset discards the local route and unresolved confirmation state. After signing in, check Activity before starting another payment whose previous result was uncertain.

## Reproducible vectors and verification status

These are **public test values only**, never a default PIN. For PIN `1234` (ASCII), salt bytes `00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f`, and 32 output bytes:

| Algorithm / iterations | Expected verifier, hexadecimal |
| --- | --- |
| SHA-256 / 600,000 | `9f39d9c71c22c4c459bc2cbacc6d74e2184185d671d91f0a34a6834413a0849d` |
| SHA-1 / 1,400,000 | `f156a834d84afa2d04ec120f6bdda0a3a15a576f1e652c55142c6996acd1700b` |

The outputs were independently reproduced with .NET `Rfc2898DeriveBytes` and Node.js `crypto.pbkdf2Sync` (OpenSSL). For example, with Node.js installed:

```javascript
const { pbkdf2Sync } = require('node:crypto');
const salt = Buffer.from('000102030405060708090a0b0c0d0e0f', 'hex');
console.log(pbkdf2Sync('1234', salt, 600000, 32, 'sha256').toString('hex'));
console.log(pbkdf2Sync('1234', salt, 1400000, 32, 'sha1').toString('hex'));
```

The **Android API 36 emulator probe passed through the real Dart method channel**: default-algorithm selection, SHA-256 vectors for `1234` and leading-zero `0007`, the SHA-1/1,400,000 vector for `1234`, and malformed PIN rejection. The [probe harness](../mobile/tool/pin_probe.dart) can be run manually from `mobile/`:

```powershell
flutter run -t tool/pin_probe.dart -d <emulator-id>
```

Use an emulator for this probe: it replaces Tetri's app entry point until the normal app is run or reinstalled. Restore the normal entry point with:

```powershell
flutter run -t lib/main.dart -d <emulator-id>
```

On the connected Android 13 phone, the user privately created a PIN, unlocked with it after a full app restart, and separately authenticated with fingerprint; both methods returned to Home. The [verification record](verification.md) tracks device acceptance separately from the native derivation probe.

Android API 24–25 runtime behavior has **not** been tested. The iOS adapter has not been compiled or device-tested from this Windows environment.
