# scout_logger_plus — enhancement suggestions (EPA integration feedback)

**From:** EPA mobile app team  
**Context:** Integrating `scout_logger_plus` alongside legacy `scout_logger`, with `dio_resilient` v2.2.3 and remote-config-driven network telemetry.  
**SDK version tested:** `0.2.0` (main)  
**Date:** June 2026

This document lists improvements we recommend for the `scout_logger_plus` package and dashboard ingest model. Items are ordered by impact for production apps like EPA.

---

## 1. Distribution & dependencies (blocking for consumers)

### 1.1 Bundle `scout_models` in the same repo

**Problem:** `pubspec.yaml` pulls `scout_models` from a separate private repo via SSH:

```yaml
scout_models:
  git:
    url: git@github.com:alrashidi-approc/scout-logger.git
    path: packages/scout_models
```

Consumers without SSH access to `scout-logger` cannot run `flutter pub get`. HTTPS clone of that repo also fails (404 / private).

**Suggestion:**

- Move `packages/scout_models` into the `scout_logger_plus` monorepo and use:

  ```yaml
  scout_models:
    path: packages/scout_models
  ```

- Or publish `scout_models` to a registry / public git repo with HTTPS.

### 1.2 Relax / update version constraints

| Package | Current in plus | Typical consumer | Issue |
|---------|-----------------|------------------|-------|
| `package_info_plus` | `^8.3.0` | `^9.0.0` | Pub solver conflict |
| `device_info_plus` | `^11.5.0` | pinned `11.2.0` | Compile errors on older API surface |

**Suggestion:**

- Widen constraints: `package_info_plus: ^8.3.0 || ^9.0.0` (or `>=8.3.0 <11.0.0`).
- In `DeviceCollector`, guard optional fields (`physicalRamSize`, `freeDiskSize`, `AndroidDeviceInfo.name`, etc.) with fallbacks so older `device_info_plus` still compiles.

### 1.3 Git URLs and releases

- Prefer **HTTPS** git URLs in `pubspec.yaml` (CI-friendly).
- Tag releases (`v0.2.1`, etc.) so apps can pin `ref:` instead of `main`.

---

## 2. Network logging API (high impact)

### 2.1 “No response” when HTTP error body exists

**Problem:** `recordNetwork()` sets:

```dart
final hasResponse = statusCode != null || response != null;
```

If a host app calls `recordNetwork()` with only a **path** (no `statusCode`, no `response` map) — common when bridging from `dio_resilient` `onRequestLog` — the dashboard shows:

- `outcome: no_response`
- `hasResponse: false`
- Title: `"GET /path — no response"`

Even when Dio actually received **404 + body** (e.g. `"request not found"`) and the UI shows that message.

**Suggestions:**

1. **Document** that `recordNetwork` requires either:
   - full Dio `RequestOptions` + `Response` / `DioException.response`, or
   - explicit `statusCode` + optional `response` map with `body`.

2. **Improve inference in SDK:**

   ```dart
   // If statusCode is set, treat as hasResponse even without response map
   final hasResponse = statusCode != null || response != null;
   ```

   (Today this is partially true for statusCode, but `buildNetworkReadable` still shows weak summaries without body.)

3. Add optional parameter:

   ```dart
   void recordNetwork({ ..., bool? hasResponseOverride })
   ```

   for bridge layers that know a response arrived but cannot serialize the body.

### 2.2 Export public network capture helpers

**Problem:** Custom interceptors (remote-config gates, `dio_resilient` split logging) need the same capture logic as `ScoutDioInterceptor`. EPA currently imports:

```dart
import 'package:scout_logger_plus/src/network_capture.dart'; // implementation_imports lint
```

**Suggestion:** Export from the public library:

```dart
// scout_logger_plus.dart
export 'src/network_capture.dart'
    show captureRequest, captureResponse, buildCurl, buildNetworkReadable, dioErrorType;
```

Or add a documented `ScoutNetworkCapture` facade class.

### 2.3 Built-in `networkLogScope` (errors vs all)

Legacy `scout_logger` has `NetworkLoggingPolicy` (`errorsOnly` / `all`). `attachScout()` logs **every** request as a span/event.

**Suggestion:** Add to `ScoutOptions`:

```dart
enum ScoutNetworkLogScope { all, errorsOnly, slowOnly }

final ScoutNetworkLogScope networkLogScope;
final Set<int> networkIgnoredStatusCodes; // e.g. 401, 403, 404
```

Apps with remote telemetry (Firebase / dashboard JSON) need this without forking the interceptor.

### 2.4 Relative / path-only URLs

**Problem:** Passing `url: '/EPAMobileAppServices/resources/inbox?...'` (path only) produces malformed display URLs like `///EPAMobileAppServices/...` in `readable.title`.

**Suggestion:**

- Document: always pass absolute URL (`options.uri.toString()` or resolved base + path).
- Or accept `baseUrl` in `ScoutOptions` and resolve relative paths inside `recordNetwork` / `redactUrl`.

---

## 3. dio_resilient integration (official guide)

EPA uses a **split logging** model:

| Traffic | Source | What to log |
|---------|--------|-------------|
| Resilient GET/POST success, cache hit, offline queue | `dio_resilient` `onRequestLog` | Outcome, duration, path, `peakHourBucket` |
| HTTP errors (4xx/5xx with body) | Dio `onError` / `ScoutDioInterceptor` | Status, body, curl |

**Problem:** Using only `onRequestLog` for errors loses `statusCode` and response body (dio_resilient v2.2.3 does not populate them on `ResilientRequestOutcome.error`).

**Suggestion for scout_logger_plus README:**

```markdown
## With dio_resilient

1. `attachScout()` on the shared Dio — captures HTTP errors with response body.
2. `onRequestLog` — emit success / cache / queue metrics only; skip `outcome: error`
   (Dio layer already logged the failure).
3. Do not duplicate: skip resilient routes on `onResponse` success if `onRequestLog` handles them.
```

Optional SDK helper:

```dart
extension ScoutResilientBridge on Scout {
  void recordResilientLog(ResilientRequestLog log) { ... }
}
```

---

## 4. Security & redaction defaults

EPA URLs often include legacy query credentials (`securUser`, `securPass`) and mobile keys (`epamobkey` header).

**Suggestion:** Extend default `networkRedactQueryParams`:

```dart
'securpass', 'securuser', 'epamobkey', 'appapikey', 'civilid', ...
```

Extend default `networkRedactHeaders` similarly.

Document how redaction interacts with `readable.lines` (ensure redacted values never appear in dashboard copy).

---

## 5. Dashboard / ingest model

### 5.1 Outcome taxonomy

Current outcomes: `success`, `http_error`, `no_response`, `failed`.

**Suggestion:** Add explicit outcome when `statusCode` is present but body empty:

- `http_error_no_body` vs `http_error_with_body`

Helps distinguish real network drops from 404/401 with empty payloads.

### 5.2 Duplicate events

When both `attachScout()` and manual `recordNetwork()` run, dashboard may show two rows for one call.

**Suggestion:** Optional dedupe key: `method + normalizedUrl + timestamp bucket` or document single-integration pattern.

---

## 6. Companion suggestion for `dio_resilient` (optional)

Not scout_logger_plus code, but affects bridge quality:

On `ResilientRequestOutcome.error`, populate from `DioException` when available:

```dart
statusCode: e.response?.statusCode,
errorMessage: e.response?.data?.toString(),
```

Then `onRequestLog` bridges can forward meaningful errors even without a custom Dio interceptor.

---

## 7. Documentation gaps we hit

| Topic | Needed in README |
|-------|------------------|
| Init without `.env` (envied / `--dart-define`) | `Scout.init(dsn)` example |
| Running parallel with another logger during migration | “dual run” section, dedupe guidance |
| `validateStatus` / 404 as `DioException.badResponse` | Explain response still in `error.response` |
| Flavor-specific DSN (staging vs prod) | Pattern example |
| Minimum interceptor order | `attachScout` first on Dio |

---

## 8. Priority summary

| Priority | Item |
|----------|------|
| P0 | Bundle or publish `scout_models`; HTTPS git URL |
| P0 | Export `network_capture` publicly |
| P1 | `networkLogScope: errorsOnly` |
| P1 | Fix / document path-only URL handling |
| P1 | Official `dio_resilient` integration doc + optional bridge API |
| P2 | Widen `package_info_plus` / harden `DeviceCollector` for older `device_info_plus` |
| P2 | Expand default redaction lists |
| P2 | Tagged releases |

---

## 9. Reference: EPA workaround (current)

Until the above land in the SDK, EPA implements:

- `ScoutPlusNetworkHelper` — resolves absolute URL, uses `captureRequest` / `captureResponse`
- `ScoutPlusDioGate` — remote-config-aware Dio interceptor; logs **errors** on resilient routes, skips resilient **success** (handled by `onRequestLog`)
- `ResilientTelemetryBridge` — skips `outcome: error` (delegates to Dio gate)
- `NetworkTelemetryPolicy` — shared remote `network_telemetry` scope (`errors_only` / `all` / `users`)

Happy to share code snippets or test against a tagged release when available.
