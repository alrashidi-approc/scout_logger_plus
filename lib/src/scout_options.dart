import 'package:scout_models/scout_models.dart';

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
    this.useRemoteConfig = true,
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
    this.networkIgnoreStatusCodes = const {},
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
  final bool useRemoteConfig;
  final Duration flushInterval;
  final int maxBatchSize;
  final Set<ScoutLevel> enabledLevels;
  final bool networkCaptureBodies;
  final int networkMaxBodyLength;
  final Set<String> networkRedactHeaders;
  final Set<String> networkRedactQueryParams;
  /// Flag network events slower than this (ms). Set to `null` to disable.
  final int? networkSlowThresholdMs;
  final Set<int> networkIgnoreStatusCodes;
  final bool recoverOrphanSessions;
  final Duration? sessionBackgroundTimeout;
  final bool autoTrackConnectivity;
  final bool debug;

  /// Merge dashboard [ProjectSdkConfig] — remote wins for SDK knobs; local identity fields stay.
  ScoutOptions withRemote(ProjectSdkConfig remote) {
    final resolved = remote.resolved();
    return ScoutOptions(
      environment: environment,
      release: release,
      sessionId: sessionId,
      platform: platform,
      autoCollectRelease: autoCollectRelease,
      enableFlutterHooks: resolved.enableFlutterHooks ?? enableFlutterHooks,
      trackNavigation: resolved.trackNavigation ?? trackNavigation,
      useRemoteConfig: useRemoteConfig,
      flushInterval: flushInterval,
      maxBatchSize: maxBatchSize,
      enabledLevels: resolved.enabledLevels!
          .map((l) => ScoutLevelX.parse(l))
          .toSet(),
      networkCaptureBodies: resolved.networkCaptureBodies ?? networkCaptureBodies,
      networkMaxBodyLength: networkMaxBodyLength,
      networkRedactHeaders: networkRedactHeaders,
      networkRedactQueryParams: networkRedactQueryParams,
      networkSlowThresholdMs: resolved.networkSlowThresholdMs ?? networkSlowThresholdMs,
      networkIgnoreStatusCodes: resolved.networkIgnoreStatusCodes!.toSet(),
      recoverOrphanSessions: recoverOrphanSessions,
      sessionBackgroundTimeout: sessionBackgroundTimeout,
      autoTrackConnectivity: autoTrackConnectivity,
      debug: debug,
    );
  }
}
