# scout_logger_plus

Flutter SDK for the [scout-logger](https://github.com/YOUR_ORG/scout-logger) platform — errors, logs, sessions, screen trails, and network events in your dashboard.

This package lives in its **own GitHub repo** (separate from the server/dashboard). Add it to your Flutter app; point it at a scout project DSN.

**Current version: `0.2.0`** — dashboard-compatible payloads (navigation badges, remote settings, session heartbeats, HTTP ignore codes). Requires `scout_models` from the platform repo with `navigation.dart` and `sdk_config.dart` (included on platform `main`).

---

## What's new in 0.2.0

| Feature | Client impact |
|---------|----------------|
| **`navigationType` on screen trail** | Timeline → User journey shows **PUSH** / **POP** / **GO** badges (no more “NO NAV” warning) |
| **Remote SDK config** | Dashboard **Settings** can tune log levels, nav tracking, network options — fetched on init and app resume |
| **`networkIgnoreStatusCodes`** | Skip logging expected HTTP failures (e.g. `401` on token refresh) — local or remote |
| **Session heartbeats** | Powers **Analytics → Sessions** timelines between start/end |
| **Richer device payload** | OS `version`, connectivity, locale — better Device tab in event inspector |

If you upgrade from `0.1.x`, no API breaks — defaults match previous behaviour. Opt into remote config with `useRemoteConfig: true` (default).

---

## Implementation checklist

Use this order when wiring scout into a client app:

1. **Platform** — run [scout-logger](https://github.com/YOUR_ORG/scout-logger) (local or deployed), create a project, copy the **DSN** from the dashboard.
2. **Dependency** — add `scout_logger_plus` **v0.2.0+** (+ `dio` for API logging) in `pubspec.yaml`.
3. **`.env`** — copy [`.env.example`](.env.example) → `.env`, paste DSN, register `.env` as a Flutter asset.
4. **`.gitignore`** — never commit `.env` (contains `sk_live_…`).
5. **`main()`** — `WidgetsFlutterBinding.ensureInitialized()` → `await Scout.initFromEnv()` → attach Dio → `runApp(ScoutApp(...))`.
6. **Navigation** — `ScoutApp` + `navigatorObservers` **or** `attachScoutGoRouter` — pick one, not both (enables `navigationType` in screen trail).
7. **Login** — call `Scout.instance.setUser(...)` after the user signs in.
8. **Verify** — navigate Home → checkout → back, send a test error, check **Timeline → User journey** (PUSH/POP badges), **Issues**, and **Analytics → Sessions**.

---

## Quick start

```yaml
# pubspec.yaml
dependencies:
  scout_logger_plus:
    git:
      url: https://github.com/YOUR_ORG/scout_logger_plus.git
      ref: v0.2.0   # or main — pin a tag for reproducible builds
  dio: ^5.9.0

flutter:
  assets:
    - .env
```

```env
# .env — paste the full DSN from the scout dashboard
SCOUT_DSN=http://sk_live_YOUR_KEY@your-host:PORT/your-project-id
SCOUT_ENVIRONMENT=development
```

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:scout_logger_plus/scout_logger_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Scout.initFromEnv();

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

## 1. Add the dependency

```yaml
dependencies:
  scout_logger_plus:
    git:
      url: https://github.com/YOUR_ORG/scout_logger_plus.git
      ref: v0.2.0
  dio: ^5.9.0   # required only if you want network logging on your API client
```

- `flutter_dotenv` is bundled — your app does not need to add it unless you read other keys yourself.
- `scout_models` is pulled transitively from the [platform repo](https://github.com/YOUR_ORG/scout-logger) (`packages/scout_models`). **0.2.0 requires a platform ref that includes `navigation.dart` and `sdk_config.dart`.**

**SDK development** (clone next to platform repo):

```yaml
dependency_overrides:
  scout_models:
    path: ../scout-logger/packages/scout_models
```

---

## 2. Configure `.env`

| Variable | Required | Purpose |
|----------|----------|---------|
| `SCOUT_DSN` | yes | Full DSN copied from the dashboard |
| `SCOUT_ENVIRONMENT` | no | Overrides `ScoutOptions.environment` (default `production`) |

Copy [`.env.example`](.env.example) to your app root. Register in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - .env
```

Add to your app `.gitignore`:

```
.env
```

**DSN format** — copy exactly from the dashboard (host, port, project id):

```
http://sk_live_<key>@<host>:<port>/<project_id>
```

```env
# ✅ full DSN from dashboard
SCOUT_DSN=http://sk_live_...@your-host:PORT/project-id

# ❌ missing port — ingest will time out
SCOUT_DSN=http://sk_live_...@your-host/project-id
```

Read other keys from the same file (optional):

```dart
final apiBase = ScoutEnv.read('API_BASE_URL') ?? 'https://api.yourapp.com';
```

---

## 3. Initialize in `main()`

Always init **before** `runApp`. Scout is optional per flavor — missing DSN is safe.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Scout.initFromEnv(
    options: const ScoutOptions(
      debug: true, // console ingest errors (keys redacted)
      useRemoteConfig: true, // fetch dashboard Settings on init + resume (default)
      enabledLevels: {
        ScoutLevel.error,
        ScoutLevel.warning,
        ScoutLevel.info,
      },
      networkIgnoreStatusCodes: {401}, // skip 401 network events until remote loads
    ),
  );

  // App API Dio — separate from scout's internal ingest client
  if (Scout.isInitialized) {
    apiDio = Dio(BaseOptions(baseUrl: 'https://api.yourapp.com'))
      ..attachScout();
  }

  runApp(const MyApp());
}
```

**Without `.env`** (CI, `--dart-define`, secrets manager):

```dart
const dsn = String.fromEnvironment('SCOUT_DSN');
if (dsn.isNotEmpty) await Scout.init(dsn);
```

**Guard calls** when scout may be off:

```dart
if (!Scout.isInitialized) return;
Scout.instance.logInfo('Ready');
```

---

## 4. Navigation (pick one pattern)

Scout records a **screen trail** (`payload.screenTrail`) with **`navigationType`** on every step (`push`, `pop`, `replace`, `remove`, `go`). The dashboard Timeline tab uses these for **PUSH** / **POP** badges in User journey.

Choose **one** integration — duplicate observers double-count screens.

### A — `MaterialApp` / imperative routes (recommended default)

```dart
runApp(ScoutApp(
  builder: (scoutObservers) => MaterialApp(
    navigatorObservers: scoutObservers,
    routes: {
      '/': (_) => const HomeScreen(),
      '/settings': (_) => const SettingsScreen(),
    },
    initialRoute: '/',
  ),
));
```

`ScoutApp` passes an empty observer list when scout is not initialized, so your app still runs without a DSN.

Manual screen (tabs, `PageView`, custom routers):

```dart
Scout.instance.trackScreen(
  '/settings',
  screenName: 'Settings',
  navigationType: NavTransition.push, // optional — default is push
);
```

Import `NavTransition` from `package:scout_models/scout_models.dart` when setting types explicitly.

### B — GoRouter

Import the GoRouter helper separately:

```dart
import 'package:scout_logger_plus/scout_go_router.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
  ],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Scout.initFromEnv();

  if (Scout.isInitialized) attachScoutGoRouter(router);

  runApp(MaterialApp.router(routerConfig: router));
}
```

- Uses `matchedLocation` for clean paths (e.g. `/checkout`, not `MaterialPageRoute<dynamic>`).
- Records navigation as **`go`** (declarative routing — not a stack push).
- **Do not** pass `ScoutApp` / `navigatorObservers` when using `attachScoutGoRouter`.
- Call `attachScoutGoRouter` only **after** `Scout.init` / `initFromEnv`.

Alternative (shell routes with nested navigators only — prefer `attachScoutGoRouter` for top-level GoRouter):

```dart
GoRouter(
  observers: scoutRouterObservers(),
  routes: [...],
);
```

---

## 5. After login — identify the user

Call once when auth succeeds (logout: `clearUser()`):

```dart
Scout.instance.setUser(
  id: user.id,
  email: user.email,
  name: user.displayName,
  traits: {'plan': user.plan},
);
```

If you never call `setUser`, scout sends an anonymous install id (stable per device).

Attach business context (sensitive keys auto-redacted):

```dart
Scout.instance.setContext({'tenantId': tenant.id, 'role': user.role});
```

---

## 6. Logs, errors, and actions

```dart
if (!Scout.isInitialized) return;

// Structured logs
Scout.instance.logInfo('Profile loaded', context: {'userId': id});
Scout.instance.logWarning('Cache miss');
Scout.instance.logSuccess('Payment confirmed');

// Errors — grouped in dashboard Issues
Scout.instance.captureException(
  error,
  stackTrace,
  category: ScoutCategory.network,
  context: {'orderId': orderId},
);

// Message without a thrown object
Scout.instance.captureMessage('Invalid state', category: ScoutCategory.logic);

// User interactions — breadcrumb + span; counted in session summary
Scout.instance.trackAction('checkout_started', data: {'items': 3});

// Force send (e.g. before showing a snackbar in a demo, or after fatal error)
await Scout.instance.flush();
```

Uncaught Flutter and platform errors are captured automatically (`enableFlutterHooks: true`).

| `ScoutCategory` | Use for |
|-----------------|---------|
| `network` | API / HTTP failures |
| `system` | General app errors (default) |
| `crashing` | Fatal / uncaught (urgent) |
| `logic` | Business rule violations |
| `ui` | Widget / layout issues |

---

## 7. Network logging (your API Dio)

Use a **dedicated Dio** for your backend. Never call `attachScout()` on scout's private ingest client.

```dart
final apiDio = Dio(BaseOptions(
  baseUrl: 'https://api.yourapp.com',
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 15),
));

apiDio.attachScout(); // inserts interceptor first — times every request
```

Scout automatically skips its own ingest traffic. Requests slower than **3s** (default) are flagged `slow: true` in the dashboard.

**Ignore expected HTTP status codes** (no network event, no breadcrumb):

```dart
await Scout.init(dsn, options: const ScoutOptions(
  networkIgnoreStatusCodes: {401, 403}, // e.g. token refresh 401
));
```

Or configure remotely in the dashboard — **Project → Settings → Ignore HTTP status codes** (see § Remote config). When a status matches, `recordNetwork()` returns before enqueue.

Disable slow detection:

```dart
ScoutOptions(networkSlowThresholdMs: null)
```

---

## 8. Secrets and redaction

Sensitive values are **not** sent in event payloads or debug logs.

| What | Protection |
|------|------------|
| Ingest key (`sk_live_…`) | Auth header only — never in payloads |
| `setContext()` / `setContextKey()` | `password`, `token`, `api_key`, `dsn`, … → `[Redacted]` |
| Network headers | `Authorization`, `Cookie`, `X-Api-Key`, … → `[Redacted]` |
| Network URLs | URL credentials + query params (`token`, `secret`, …) redacted |
| Debug console | Ingest errors strip the key before `debugPrint` |

Extend via `ScoutOptions.networkRedactHeaders` and `networkRedactQueryParams`.

---

## 9. Remote config (dashboard Settings)

Ops can tune SDK behaviour per project from the dashboard without shipping a new app build. The SDK fetches settings with the same ingest key as the DSN.

| When | What happens |
|------|----------------|
| **Init** | `GET /v1/client/config` — merged into runtime options |
| **App resume** | Re-fetch if `configVersion` increased |
| **Ingest flush** | `202` responses may include `configVersion` — triggers refresh |

**Dashboard-controlled fields** (remote wins over local defaults):

- `enabledLevels`
- `enableFlutterHooks`
- `trackNavigation`
- `networkCaptureBodies`
- `networkSlowThresholdMs`
- `networkIgnoreStatusCodes`

**Always local** (never overwritten by remote): `environment`, `release`, redaction lists, `flushInterval`, DSN.

```dart
const ScoutOptions(
  useRemoteConfig: true,  // default — set false to use code-only options
  networkIgnoreStatusCodes: {401}, // used until remote loads; then remote wins
);
```

Opt out entirely:

```dart
ScoutOptions(useRemoteConfig: false)
```

**Verify:** Dashboard → **Settings** → uncheck **INFO**, add **401** to ignore codes → Save → relaunch app (or background → foreground). `Scout.instance.options.enabledLevels` should exclude `info`; API calls returning 401 should not appear under **Events**.

Platform contract: [scout-logger SDK-DASHBOARD-COMPAT.md](https://github.com/YOUR_ORG/scout-logger/blob/main/docs/SDK-DASHBOARD-COMPAT.md)

---

## 10. Options reference

```dart
const ScoutOptions(
  environment: 'production',       // or SCOUT_ENVIRONMENT in .env
  useRemoteConfig: true,           // fetch dashboard Settings on init / resume
  enabledLevels: {ScoutLevel.error, ScoutLevel.warning},
  trackNavigation: true,
  enableFlutterHooks: true,
  autoCollectRelease: true,        // version/build from package_info_plus
  networkSlowThresholdMs: 3000,    // null = disable slow flag
  networkIgnoreStatusCodes: {},    // e.g. {401, 403}
  networkCaptureBodies: true,
  networkMaxBodyLength: 8192,
  flushInterval: Duration(seconds: 15),
  maxBatchSize: 20,
  recoverOrphanSessions: true,     // end sessions killed by OS crash
  sessionBackgroundTimeout: Duration(minutes: 30),
  autoTrackConnectivity: true,
  debug: false,
);
```

---

## 11. Auto-collected (no extra code)

| Data | How |
|------|-----|
| Device model, OS, locale | At init |
| Anonymous user id | When `setUser()` not called |
| App version / build | `package_info_plus` |
| Session start / heartbeat / end | Lifecycle + 2‑min heartbeats + background timeout |
| Screen trail + `navigationType` + dwell | Navigation or GoRouter |
| Breadcrumbs | Nav, logs, errors, network, actions |
| Network (redacted) | `attachScout()` on app Dio |
| Online / offline | `connectivity_plus` |
| Country hint | Device locale → server geo enrichment |

---

## 12. Verify integration

1. Start scout, create a project, paste the dashboard DSN into `.env`.
2. Run the app, navigate **Home → checkout → back**, then send a test event:

```dart
Scout.instance.captureException(
  StateError('Scout connection test'),
  StackTrace.current,
);
await Scout.instance.flush();
```

3. In the dashboard:
   - **Issues** — the test error
   - **Events** → open event → **Timeline** → **User journey** — steps show **PUSH** / **POP** (no yellow “navigation type not recorded” warning)
   - **Analytics → Sessions** — your visit, screen trail, session summary
   - **Events** — network rows if you called your API Dio (unless status is in ignore list)

Health check (same host as in DSN):

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://your-host/health
# expect 200
```

---

## 13. Example app

```bash
cd example
cp .env.example .env   # paste DSN
flutter pub get
flutter run
```

The example demonstrates: `initFromEnv`, `ScoutApp` + routes, test error, screen trail, and `attachScout()` on a demo API. See [example/README.md](example/README.md).

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Scout not initialized | Add `SCOUT_DSN` to `.env` and register `- .env` under `flutter: assets:` |
| Receive timeout on ingest | DSN missing `:PORT` — copy the **full** DSN from the dashboard |
| No screen trail | Use `ScoutApp` + `navigatorObservers`, or `attachScoutGoRouter` — not both |
| Timeline shows “NO NAV” / yellow warning | Upgrade to **0.2.0+** and ensure navigation integration is active (`trackNavigation: true`) |
| Duplicate screen events | GoRouter: use `attachScoutGoRouter` only; remove `navigatorObservers` |
| No network events | Call `attachScout()` on your **app** Dio after init |
| 401/403 still logged after ignore | Remote config wins — check dashboard **Settings**, or set `useRemoteConfig: false` |
| Remote settings not applied | Relaunch app or background → foreground; check server `/v1/client/config` |
| Scout works locally, not on device | Device must reach the host in DSN (not `localhost` unless emulator) |
| Ingest key visible in dashboard | Upgrade SDK — keys must never appear in payloads |

Platform setup (server, dashboard, deploy): [scout-logger README](https://github.com/YOUR_ORG/scout-logger/blob/main/README.md)
