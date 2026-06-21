import 'enums.dart';

class ScoutOptions {
  const ScoutOptions({
    this.environment = 'production',
    this.release,
    this.sessionId,
    this.platform,
    this.autoCollectRelease = true,
    this.enableFlutterHooks = true,
    this.trackNavigation = true,
    this.flushInterval = const Duration(seconds: 15),
    this.maxBatchSize = 20,
    this.enabledLevels = const {
      ScoutLevel.error,
      ScoutLevel.info,
      ScoutLevel.warning,
      ScoutLevel.success,
    },
    this.networkCaptureBodies = true,
    this.networkMaxBodyLength = 8192,
    this.networkRedactHeaders = const {
      'authorization',
      'cookie',
      'set-cookie',
      'x-api-key',
      'x-auth-token',
      'proxy-authorization',
    },
    this.networkRedactQueryParams = const {
      'token',
      'access_token',
      'refresh_token',
      'api_key',
      'apikey',
      'key',
      'secret',
      'password',
      'auth',
      'dsn',
    },
    this.networkSlowThresholdMs = 3000,
    this.recoverOrphanSessions = true,
    this.sessionBackgroundTimeout = const Duration(minutes: 30),
    this.autoTrackConnectivity = true,
    this.debug = false,
  });

  final String environment;
  final String? release;
  final String? sessionId;
  final String? platform;
  final bool autoCollectRelease;
  final bool enableFlutterHooks;
  final bool trackNavigation;
  final Duration flushInterval;
  final int maxBatchSize;
  final Set<ScoutLevel> enabledLevels;
  final bool networkCaptureBodies;
  final int networkMaxBodyLength;
  final Set<String> networkRedactHeaders;
  final Set<String> networkRedactQueryParams;
  /// Flag network events slower than this (ms). Set to `null` to disable.
  final int? networkSlowThresholdMs;
  final bool recoverOrphanSessions;
  final Duration? sessionBackgroundTimeout;
  final bool autoTrackConnectivity;
  final bool debug;
}
