# scout_logger_plus example

Minimal reference app — copy patterns from here into your client project.

Full integration guide: [../README.md](../README.md)

## Setup

```bash
cp .env.example .env
# paste SCOUT_DSN from the scout dashboard (full URL including :PORT)
flutter pub get
flutter run
```

## What this example shows

| Pattern | Where |
|---------|--------|
| `Scout.initFromEnv()` before `runApp` | `lib/main.dart` |
| Optional scout (UI when DSN missing) | `DemoHome` |
| `ScoutApp` + `navigatorObservers` | `main()` |
| App API Dio + `attachScout()` | `apiDio` in `main()` |
| `setUser()` after init | `main()` |
| Test error + `flush()` | **Send test error** button |
| Screen trail | **Go to checkout** → `/` → `/checkout` |
| Network event | **Call demo API** (httpbin via app Dio) |

## Try in the dashboard

1. **Issues** — tap **Send test error**
2. **Analytics → Sessions** — open the app, navigate to checkout, go back
3. **Events** — tap **Call demo API** for a network row

Keep `.env` out of git — it contains your ingest key.

## GoRouter apps

This example uses imperative `MaterialApp` routes. For GoRouter, see [../README.md § Navigation B](../README.md#b--gorouter).

## Timeout troubleshooting

`receive timeout` usually means the DSN is **missing the port**. Copy the full DSN from the dashboard — do not drop `:PORT`.

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://your-host/health
# expect 200
```
