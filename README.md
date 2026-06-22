# scout_logger_plus

Flutter SDK for the [scout-logger](https://github.com/alrashidi-approc/scout-logger) platform — errors, logs, sessions, screen trails, and network events in your dashboard.

**Latest release: [`v1.0.0`](https://github.com/alrashidi-approc/scout_logger_plus/releases/tag/v1.0.0)** — first stable, dashboard-compatible SDK.

Pin the tag in `pubspec.yaml` for reproducible builds. Requires [scout-logger](https://github.com/alrashidi-approc/scout-logger) platform `main` (or newer) for `scout_models` with `navigation.dart` and `sdk_config.dart`.

---

## Install (v1.0.0)

```yaml
dependencies:
  scout_logger_plus:
    git:
      url: https://github.com/alrashidi-approc/scout_logger_plus.git
      ref: v1.0.0
  dio: ^5.9.0   # required for network logging on your API client

flutter:
  assets:
    - .env
```

`scout_models` is pulled transitively from the [platform repo](https://github.com/alrashidi-approc/scout-logger) (`packages/scout_models`). That repo is private — use SSH git access or a local override:

```yaml
dependency_overrides:
  scout_models:
    git:
      url: git@github.com:alrashidi-approc/scout-logger.git
      path: packages/scout_models
      ref: main
```

**Local SDK development** (both repos cloned side by side):

```yaml
dependency_overrides:
  scout_models:
    path: ../scout-logger/packages/scout_models
```

---

## Upgrade to v1.0.0

If you integrated an older SDK or legacy `scout_logger`:

| Step | Action |
|------|--------|
| 1 | Bump `ref:` to `v1.0.0` and run `flutter pub get` |
| 2 | Ensure platform server/dashboard is current (remote Settings, Timeline badges) |
| 3 | Keep `useRemoteConfig: true` (default) — dashboard **Settings** now controls log levels, network scope, ignore codes |
| 4 | Wire navigation once: `ScoutApp` + observers **or** `attachScoutGoRouter` — not both |
| 5 | Verify **Timeline → User journey** shows PUSH/POP badges after a navigation + error test |

No breaking API changes from pre-1.0 betas — defaults match prior behaviour (`networkLogScope: all`, remote config on).

---

## What's in v1.0.0

### Dashboard compatibility

| Feature | Dashboard use |
|---------|----------------|
| **`navigationType` on screen trail** | Timeline → User journey **PUSH** / **POP** / **GO** badges |
| **Remote SDK config** | Project **Settings** tunes SDK without app release |
| **Session heartbeats** | Analytics → Sessions timeline |
| **Rich payload envelope** | user, device, screen, release, breadcrumbs, custom context |
| **`batteryLevel`** | Device tab (`"0.82"` string), refreshed on resume |

### Network telemetry

| Feature | Use |
|---------|-----|
| **`attachScout()`** | Auto-capture on your app Dio (not ingest client) |
| **`ScoutNetworkLogScope`** | `all` / `errorsOnly` / `slowOnly` — local or remote |
| **`networkIgnoreStatusCodes`** | Skip 401, 403, etc. — local or remote |
| **`apiBaseUrl`** | Resolve path-only URLs (`/inbox` → full URL) |
| **`hasResponseOverride`** | Custom bridges when status exists without body map |
| **Public capture API** | `captureRequest`, `captureResponse`, `buildCurl`, `buildNetworkReadable` |
| **`recordResilientLog`** | Official [dio_resilient](https://pub.dev/packages/dio_resilient) bridge |

### Remote config (dashboard Settings)

Fetched on init, app resume, and when ingest returns a newer `configVersion`:

| Field | Effect |
|-------|--------|
| `enabledLevels` | Drop logs below unchecked levels |
| `enableFlutterHooks` | `FlutterError` + platform crash handlers |
| `trackNavigation` | Screen trail + nav observer |
| `networkCaptureBodies` | Request/response bodies in network events |
| `networkSlowThresholdMs` | Slow-request flag (500–60000 ms) |
| `networkIgnoreStatusCodes` | Skip matching HTTP statuses |
| `networkLogScope` | `all` / `errorsOnly` / `slowOnly` |

Always local: `environment`, `release`, redaction lists, `flushInterval`, DSN.

---

## Implementation checklist

1. **Platform** — deploy [scout-logger](https://github.com/alrashidi-approc/scout-logger), create a project, copy **DSN** from dashboard.
2. **Dependency** — pin `ref: v1.0.0` (+ `dio` for API logging).
3. **`.env`** — copy [`.env.example`](.env.example) → `.env`, register as Flutter asset.
4. **`main()`** — `WidgetsFlutterBinding.ensureInitialized()` → `await Scout.initFromEnv()` → attach Dio → `runApp(ScoutApp(...))`.
5. **Navigation** — `ScoutApp` + `navigatorObservers` **or** `attachScoutGoRouter` — pick one.
6. **Login** — `Scout.instance.setUser(...)` after auth.
7. **Verify** — navigate → test error → check **Timeline**, **Issues**, **Analytics → Sessions**.

---

## Quick start

```env
# .env — full DSN from dashboard (include :PORT)
SCOUT_DSN=http://sk_live_YOUR_KEY@your-host:PORT/your-project-id
SCOUT_ENVIRONMENT=development
```

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:scout_logger_plus/scout_logger_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Scout.initFromEnv(
    options: const ScoutOptions(
      apiBaseUrl: 'https://api.yourapp.com',
      useRemoteConfig: true,
      networkIgnoreStatusCodes: {401},
    ),
  );

  if (Scout.isInitialized) {
    Dio(BaseOptions(baseUrl: 'https://api.yourapp.com')).attachScout();
  }

  runApp(ScoutApp(
    builder: (observers) => MaterialApp(
      navigatorObservers: observers,
      home: const HomeScreen(),
    ),
  ));
}
```

Run the [example app](example/): `cp example/.env.example example/.env` → paste DSN → `flutter run`.

---

## Configure `.env`

| Variable | Required | Purpose |
|----------|----------|---------|
| `SCOUT_DSN` | yes | Full DSN from dashboard |
| `SCOUT_ENVIRONMENT` | no | Overrides `ScoutOptions.environment` (default `production`) |

**DSN format** — copy exactly (host, port, project id):

```
http://sk_live_<key>@<host>:<port>/<project_id>
```

```env
# ✅ full DSN
SCOUT_DSN=http://sk_live_...@your-host:8080/project-id

# ❌ missing port — ingest will time out
SCOUT_DSN=http://sk_live_...@your-host/project-id
```

**Without `.env`** (CI, `--dart-define`):

```dart
const dsn = String.fromEnvironment('SCOUT_DSN');
if (dsn.isNotEmpty) await Scout.init(dsn);
```

---

## Initialize in `main()`

Always init **before** `runApp`. Missing DSN is safe — scout stays off.

```dart
await Scout.initFromEnv(
  options: const ScoutOptions(
    debug: true,
    useRemoteConfig: true,
    enabledLevels: {ScoutLevel.error, ScoutLevel.warning, ScoutLevel.info},
    networkLogScope: ScoutNetworkLogScope.all, // remote Settings can override
    networkIgnoreStatusCodes: {401},
    apiBaseUrl: 'https://api.yourapp.com',
  ),
);

if (Scout.isInitialized) {
  apiDio = Dio(BaseOptions(baseUrl: 'https://api.yourapp.com'))..attachScout();
}
```

```dart
if (!Scout.isInitialized) return;
Scout.instance.logInfo('Ready');
```

---

## Navigation (pick one)

Scout sends `payload.screenTrail` with **`navigationType`** on each step. Dashboard Timeline shows **PUSH** / **POP** badges.

### A — `MaterialApp` (default)

```dart
runApp(ScoutApp(
  builder: (observers) => MaterialApp(
    navigatorObservers: observers,
    routes: {'/': (_) => const HomeScreen()},
    initialRoute: '/',
  ),
));
```

Manual screens:

```dart
import 'package:scout_models/scout_models.dart';

Scout.instance.trackScreen('/settings', navigationType: NavTransition.push);
```

### B — GoRouter

```dart
import 'package:scout_logger_plus/scout_go_router.dart';

await Scout.initFromEnv();
if (Scout.isInitialized) attachScoutGoRouter(router);

runApp(MaterialApp.router(routerConfig: router));
```

- Records routes as **`go`** (declarative).
- **Do not** combine with `ScoutApp` / `navigatorObservers`.

---

## User identity & context

```dart
Scout.instance.setUser(id: user.id, email: user.email, name: user.name);
Scout.instance.setContext({'tenantId': tenant.id}); // sensitive keys redacted
Scout.instance.clearUser(); // on logout
```

---

## Logs, errors, actions

```dart
Scout.instance.logInfo('Profile loaded');
Scout.instance.logWarning('Cache miss');
Scout.instance.captureException(error, stack, category: ScoutCategory.network);
Scout.instance.captureMessage('Invalid state', category: ScoutCategory.logic);
Scout.instance.trackAction('checkout_started', data: {'items': 3});
await Scout.instance.flush();
```

| `ScoutCategory` | Use for |
|-----------------|---------|
| `network` | API / HTTP failures |
| `system` | General errors (default) |
| `crashing` | Fatal / uncaught |
| `logic` | Business rules |
| `ui` | Widget / layout |

Uncaught Flutter and platform errors are captured when `enableFlutterHooks: true`.

---

## Network logging

Use a **dedicated Dio** for your backend. Never `attachScout()` on scout's ingest client.

```dart
await Scout.initFromEnv(options: const ScoutOptions(
  apiBaseUrl: 'https://api.yourapp.com',
  networkLogScope: ScoutNetworkLogScope.all, // or errorsOnly / slowOnly
  networkIgnoreStatusCodes: {401, 403},
));

apiDio.attachScout(); // insert first on interceptor stack
```

| `networkLogScope` | Logs |
|-------------------|------|
| `all` (default) | Every request |
| `errorsOnly` | 4xx/5xx + Dio failures |
| `slowOnly` | Requests ≥ `networkSlowThresholdMs` |

Override from dashboard: **Settings → Network log scope**.

**Custom interceptors** — public helpers (no `src/` imports):

```dart
Scout.instance.recordNetwork(
  method: 'GET',
  url: options.uri.toString(),
  statusCode: 404,
  hasResponseOverride: true,
  response: captureResponse(error.response!),
);
```

### dio_resilient

Split logging to avoid duplicates:

1. `attachScout()` — HTTP errors with response body.
2. `onRequestLog` — success/cache/queue via `recordResilientLog` only.
3. Skip duplicate success logging.

```dart
onRequestLog: (log) {
  Scout.instance.recordResilientLog(ScoutResilientLog.fromMap(log.toJson()));
},
```

`recordResilientLog` **skips** `outcome: error` — Dio already logged it.

---

## Remote config

| When | What |
|------|------|
| Init | `GET /v1/client/config` merged into options |
| App resume | Re-fetch if `configVersion` increased |
| Ingest `202` | May include `configVersion` → refresh |

```dart
ScoutOptions(useRemoteConfig: false) // opt out — code-only options
```

**Verify:** Dashboard → **Settings** → change log levels / network scope → Save → relaunch or background → foreground → check `Scout.instance.options`.

Contract: [SDK-DASHBOARD-COMPAT.md](docs/SDK-DASHBOARD-COMPAT.md) · [platform doc](https://github.com/alrashidi-approc/scout-logger/blob/main/docs/SDK-DASHBOARD-COMPAT.md)

---

## Options reference

```dart
const ScoutOptions(
  environment: 'production',
  useRemoteConfig: true,
  enabledLevels: {ScoutLevel.error, ScoutLevel.warning, ScoutLevel.info, ScoutLevel.success},
  trackNavigation: true,
  enableFlutterHooks: true,
  autoCollectRelease: true,
  apiBaseUrl: 'https://api.yourapp.com',
  networkLogScope: ScoutNetworkLogScope.all,
  networkSlowThresholdMs: 3000,       // null = disable slow flag
  networkIgnoreStatusCodes: {},
  networkCaptureBodies: true,
  networkMaxBodyLength: 8192,
  flushInterval: Duration(seconds: 15),
  maxBatchSize: 20,
  recoverOrphanSessions: true,
  sessionBackgroundTimeout: Duration(minutes: 30),
  autoTrackConnectivity: true,
  debug: false,
);
```

---

## Auto-collected

| Data | How |
|------|-----|
| Device model, OS, locale, battery | At init; battery on resume |
| Anonymous user id | When `setUser()` not called |
| App version / build | `package_info_plus` |
| Session start / heartbeat / end | Lifecycle + 2 min heartbeats |
| Screen trail + `navigationType` | Navigation or GoRouter |
| Breadcrumbs | Nav, logs, errors, network, actions |
| Network (redacted) | `attachScout()` on app Dio |
| Online / offline | `connectivity_plus` |

---

## Verify in dashboard

1. Paste DSN into `.env`, run app.
2. Navigate Home → checkout → back.
3. Send test error + `flush()`.
4. Confirm:
   - **Issues** — test error
   - **Events** → **Timeline** → **User journey** — PUSH/POP badges
   - **Analytics → Sessions** — visit + trail
   - **Events** — network rows (unless ignored status / scope)

```dart
Scout.instance.captureException(StateError('Scout test'), StackTrace.current);
await Scout.instance.flush();
```

---

## Example app

```bash
cd example && cp .env.example .env && flutter pub get && flutter run
```

See [example/README.md](example/README.md).

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `flutter pub get` fails on `scout_models` | Add `dependency_overrides` for `scout_models` (see **Install**) — platform repo is private |
| Scout not initialized | `SCOUT_DSN` in `.env` + `flutter: assets: [.env]` |
| Ingest timeout | DSN missing `:PORT` |
| Timeline “NO NAV” warning | Use v1.0.0+, enable `trackNavigation`, wire navigation |
| Duplicate screens | GoRouter: `attachScoutGoRouter` only |
| No network events | `attachScout()` on app Dio after init |
| 401 still logged | Check dashboard **Settings** ignore codes (remote wins) |
| Remote settings stale | Background → foreground or relaunch |

---

## Changelog

### v1.0.0 (2026-06)

First stable release — full dashboard compatibility.

- Screen trail `navigationType` (Timeline badges)
- Remote SDK config (7 dashboard-controlled fields)
- Session heartbeats + summary
- Network scope, ignore codes, slow threshold (local + remote)
- Public network capture API + dio_resilient bridge
- Battery level in device payload
- EPA redaction defaults (`securpass`, `epamobkey`, …)

### Pre-1.0 history

Internal `0.2.x` tags preceded v1.0.0 during dashboard compat work. New integrations should use **`v1.0.0`** only.

---

Platform setup: [scout-logger README](https://github.com/alrashidi-approc/scout-logger/blob/main/README.md) · EPA feedback: [docs/scout_logger_plus_enhancement_suggestions.md](docs/scout_logger_plus_enhancement_suggestions.md)
