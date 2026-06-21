import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Load scout config from a `.env` asset in your app.
///
/// Register in your app `pubspec.yaml`:
/// ```yaml
/// flutter:
///   assets:
///     - .env
/// ```
class ScoutEnv {
  ScoutEnv._();

  static bool _loaded = false;

  static Future<void> load({String fileName = '.env'}) async {
    await dotenv.load(fileName: fileName);
    _loaded = true;
  }

  static bool get isLoaded => _loaded;

  /// Project DSN from the scout dashboard (`SCOUT_DSN`).
  static String? get dsn => _read('SCOUT_DSN');

  /// Optional override for [ScoutOptions.environment].
  static String? get environment => _read('SCOUT_ENVIRONMENT');

  static String? read(String key) => _read(key);

  static String? _read(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
