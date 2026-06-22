# scout_logger_plus example

Minimal reference app — copy patterns into your client project.

**Release:** [`v1.0.0`](https://github.com/alrashidi-approc/scout_logger_plus/releases/tag/v1.0.0) · Full guide: [../README.md](../README.md)

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
| Screen trail + `navigationType` | **Go to checkout** |
| Network event | **Call demo API** |

## Try in the dashboard

1. **Issues** — tap **Send test error**
2. **Events** → **Timeline** → **User journey** — **PUSH** on checkout
3. **Analytics → Sessions** — full visit trail
4. **Events** — network row from demo API call

Keep `.env` out of git.

## GoRouter

See [../README.md § Navigation B](../README.md#b--gorouter).
