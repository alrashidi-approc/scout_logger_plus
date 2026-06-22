import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:scout_models/scout_models.dart';

import 'breadcrumbs.dart';
import 'device_collector.dart';
import 'dsn.dart';
import 'enums.dart';
import 'event_queue.dart';
import 'flutter_binding.dart';
import 'ingest_client.dart';
import 'install_store.dart';
import 'remote_config_client.dart';
import 'resilient_bridge.dart';
import 'network_capture.dart';
import 'scout_env.dart';
import 'scout_options.dart';
import 'secrets.dart';
import 'screen_trail.dart';
import 'session_store.dart';
import 'session_summary.dart';
import 'session_tracker.dart';

/// Client bridge: Flutter app → ingest API → Postgres → dashboard.
class Scout {
  Scout._({
    required ScoutDsn dsn,
    required ScoutOptions options,
    required IngestClient client,
    required RemoteConfigClient remoteConfig,
    required EventQueue queue,
    required DeviceCollector deviceCollector,
    required ScreenTrail screenTrail,
    required SessionTracker sessionTracker,
    required BreadcrumbBuffer breadcrumbs,
  })  : _dsn = dsn,
        _options = options,
        _client = client,
        _remoteConfig = remoteConfig,
        _queue = queue,
        _deviceCollector = deviceCollector,
        _screenTrail = screenTrail,
        _sessionTracker = sessionTracker,
        _breadcrumbs = breadcrumbs;

  static Scout? _instance;

  final ScoutDsn _dsn;
  ScoutOptions _options;
  final IngestClient _client;
  final RemoteConfigClient _remoteConfig;
  int _configVersion = 0;
  final EventQueue _queue;
  final DeviceCollector _deviceCollector;
  final ScreenTrail _screenTrail;
  final SessionTracker _sessionTracker;
  final BreadcrumbBuffer _breadcrumbs;

  Map<String, dynamic> _device = {};
  Map<String, dynamic> _install = {};
  Map<String, dynamic> _release = {};
  ScoutUser _user = const ScoutUser();
  final Map<String, dynamic> _context = {};
  ScoutLifecycleBinding? _lifecycle;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  void Function()? _goRouterDetach;

  late final ScoutNavigationObserver navigationObserver =
      ScoutNavigationObserver(_onRoute);

  List<NavigatorObserver> get navigatorObservers =>
      _options.trackNavigation ? [navigationObserver] : const [];

  static bool get isInitialized => _instance != null;

  static Scout get instance {
    final s = _instance;
    if (s == null) throw StateError('Call Scout.init(dsn) first');
    return s;
  }

  static Future<Scout> init(String dsn, {ScoutOptions options = const ScoutOptions()}) {
    return initWith(parseDsn(dsn), options: options);
  }

  /// Load `.env` (asset) and init from `SCOUT_DSN`. Returns `null` when DSN is missing.
  static Future<Scout?> initFromEnv({
    String fileName = '.env',
    ScoutOptions options = const ScoutOptions(),
  }) async {
    await ScoutEnv.load(fileName: fileName);
    final dsn = ScoutEnv.dsn;
    if (dsn == null) return null;
    final env = ScoutEnv.environment;
    final opts = env != null ? _withEnvironment(options, env) : options;
    return init(dsn, options: opts);
  }

  static ScoutOptions _withEnvironment(ScoutOptions o, String environment) => ScoutOptions(
        environment: environment,
        release: o.release,
        sessionId: o.sessionId,
        platform: o.platform,
        autoCollectRelease: o.autoCollectRelease,
        enableFlutterHooks: o.enableFlutterHooks,
        trackNavigation: o.trackNavigation,
        useRemoteConfig: o.useRemoteConfig,
        flushInterval: o.flushInterval,
        maxBatchSize: o.maxBatchSize,
        enabledLevels: o.enabledLevels,
        networkCaptureBodies: o.networkCaptureBodies,
        networkMaxBodyLength: o.networkMaxBodyLength,
        networkRedactHeaders: o.networkRedactHeaders,
        networkRedactQueryParams: o.networkRedactQueryParams,
        networkSlowThresholdMs: o.networkSlowThresholdMs,
        networkIgnoreStatusCodes: o.networkIgnoreStatusCodes,
        networkLogScope: o.networkLogScope,
        apiBaseUrl: o.apiBaseUrl,
        recoverOrphanSessions: o.recoverOrphanSessions,
        sessionBackgroundTimeout: o.sessionBackgroundTimeout,
        autoTrackConnectivity: o.autoTrackConnectivity,
        debug: o.debug,
      );

  static Future<Scout> initWith(ScoutDsn dsn, {ScoutOptions options = const ScoutOptions()}) async {
    if (_instance != null) return _instance!;

    void logError(String label, Object e) {
      if (!options.debug) return;
      debugPrint('$label ${redactSecretsInText(e.toString(), [dsn.ingestKey])}');
    }

    final trail = ScreenTrail();
    final client = IngestClient(
      baseUrl: dsn.baseUrl,
      ingestKey: dsn.ingestKey,
      onError: options.debug ? (e) => logError('scout_logger_plus ingest:', e) : null,
    );
    final remoteConfig = RemoteConfigClient(client.dio);
    var effectiveOptions = options;
    var configVersion = 0;
    if (options.useRemoteConfig) {
      final remote = await remoteConfig.fetch();
      if (remote != null) {
        effectiveOptions = options.withRemote(remote.sdk);
        configVersion = remote.configVersion;
      }
    }

    late Scout scout;
    final queue = EventQueue(
      client: client,
      maxBatch: effectiveOptions.maxBatchSize,
      flushInterval: effectiveOptions.flushInterval,
      onError: effectiveOptions.debug ? (e) => logError('scout_logger_plus:', e) : null,
      onConfigVersion: (v) => scout._onIngestConfigVersion(v),
    );
    final deviceCollector = DeviceCollector();

    final sessionTracker = SessionTracker(
      trail: trail,
      sessionId: effectiveOptions.sessionId,
      onEvent: (p) => scout._sendSession(p),
    );

    scout = Scout._(
      dsn: dsn,
      options: effectiveOptions,
      client: client,
      remoteConfig: remoteConfig,
      queue: queue,
      deviceCollector: deviceCollector,
      screenTrail: trail,
      sessionTracker: sessionTracker,
      breadcrumbs: BreadcrumbBuffer(),
    );
    scout._configVersion = configVersion;

    scout._device = await deviceCollector.collect();
    scout._install = await InstallStore.loadOrCreate();
    scout._device.addAll({
      'installId': scout._install['installId'],
      'anonymousId': scout._install['anonymousId'],
      'firstOpenAt': scout._install['firstOpenAt'],
      'launchCount': scout._install['launchCount'],
      'daysSinceInstall': scout._install['daysSinceInstall'],
    });
    deviceCollector.patch(scout._device);
    if (effectiveOptions.release != null) {
      scout._release = {'name': effectiveOptions.release, 'environment': effectiveOptions.environment};
    } else if (effectiveOptions.autoCollectRelease) {
      scout._release = await collectRelease(environment: effectiveOptions.environment);
    } else {
      scout._release = {'environment': effectiveOptions.environment};
    }

    queue.start();
    if (effectiveOptions.recoverOrphanSessions) await scout._recoverOrphanSession();
    sessionTracker.start();
    if (effectiveOptions.enableFlutterHooks) scout._installFlutterHooks();
    if (effectiveOptions.autoTrackConnectivity) scout._watchConnectivity();
    _instance = scout;
    return scout;
  }

  Future<void> _recoverOrphanSession() async {
    final orphan = await SessionStore.readActive();
    if (orphan == null) return;
    final startedAt = DateTime.tryParse(orphan['startedAt'] as String? ?? '');
    if (startedAt == null) {
      await SessionStore.clear();
      return;
    }
    final endedAt = DateTime.now().toUtc();
    _sendSession({
      'action': 'end',
      'sessionId': orphan['sessionId'],
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'durationMs': endedAt.difference(startedAt).inMilliseconds,
      'reason': 'recovered',
    });
    await _queue.flush();
    await SessionStore.clear();
  }

  String get projectId => _dsn.projectId;
  String get sessionId => _sessionTracker.sessionId;
  Uri get baseUrl => _dsn.baseUrl;
  ScoutOptions get options => _options;

  void setUser({String? id, String? sessionId, String? email, String? name, Map<String, dynamic>? traits}) {
    _user = ScoutUser(
      id: id,
      sessionId: sessionId ?? _sessionTracker.sessionId,
      email: email,
      name: name,
      traits: traits,
    );
  }

  void clearUser() => _user = const ScoutUser();

  void setRelease(String name, {String? version, String? buildNumber, String? bundleId}) {
    _release = {
      'name': name,
      if (version != null) 'version': version,
      if (buildNumber != null) 'buildNumber': buildNumber,
      if (bundleId != null) 'bundleId': bundleId,
      'environment': _options.environment,
    };
  }

  void setDevice(Map<String, dynamic> device) {
    _device.addAll(device);
    _deviceCollector.patch(device);
  }

  void setContext(Map<String, dynamic> data) => _context.addAll(redactContext(data));
  void setContextKey(String key, dynamic value) =>
      _context[key] = isSensitiveKey(key) ? '[Redacted]' : value;
  void clearContext() => _context.clear();

  void trackScreen(String route, {String? screenName, NavTransition navigationType = NavTransition.push}) {
    if (!_options.trackNavigation) return;
    _sessionTracker.onScreen(route, navigationType: navigationType, screenName: screenName);
    _crumbNav(route, screenName: screenName, navigationType: navigationType);
  }

  /// User interaction — breadcrumb + lightweight span (checkout, button tap, etc.).
  void trackAction(String name, {Map<String, dynamic>? data}) {
    if (name.isEmpty) return;
    _breadcrumbs.add(
      type: 'action',
      route: _screenTrail.currentRoute,
      message: name,
      data: data,
    );
    _enqueue(
      type: 'span',
      level: ScoutLevel.info,
      payload: {
        'message': name,
        'action': {
          'name': name,
          if (data != null && data.isNotEmpty) 'data': data,
        },
      },
    );
  }

  void logInfo(String message, {Map<String, dynamic>? context}) {
    _crumbLog('info', message);
    _record(level: ScoutLevel.info, message: message, context: context);
  }

  void logWarning(String message, {Map<String, dynamic>? context}) {
    _crumbLog('warning', message);
    _record(level: ScoutLevel.warning, message: message, context: context);
  }

  void logSuccess(String message, {Map<String, dynamic>? context}) {
    _crumbLog('success', message);
    _record(level: ScoutLevel.success, message: message, context: context);
  }

  void captureMessage(String message, {ScoutLevel level = ScoutLevel.error, ScoutCategory category = ScoutCategory.system}) {
    _crumbError(message, category: category.wire);
    _record(level: level, message: message, category: category);
  }

  void captureException(
    Object error,
    StackTrace? stack, {
    ScoutLevel level = ScoutLevel.error,
    ScoutCategory category = ScoutCategory.system,
    Map<String, dynamic>? context,
  }) {
    _crumbError(error.toString(), category: category.wire);
    _record(
      level: level,
      category: category,
      message: error.toString(),
      stack: stack?.toString(),
      context: context,
      urgent: category == ScoutCategory.crashing,
    );
  }

  void captureFlutterError(FlutterErrorDetails details) {
    captureException(
      details.exception,
      details.stack,
      category: ScoutCategory.system,
      context: {'library': details.library, 'context': details.context?.toString()},
    );
  }

  void recordNetwork({
    required String method,
    required String url,
    int? statusCode,
    int? durationMs,
    String? error,
    String? errorType,
    bool failed = false,
    bool fromInterceptor = false,
    bool? hasResponseOverride,
    Map<String, dynamic>? request,
    Map<String, dynamic>? response,
    String? curl,
    Map<String, dynamic>? networkExtra,
  }) {
    if (statusCode != null && _options.networkIgnoreStatusCodes.contains(statusCode)) return;
    final resolvedUrl = resolveNetworkUrl(url, apiBaseUrl: _options.apiBaseUrl);
    final safeUrl = redactUrl(resolvedUrl, redactQueryKeys: _options.networkRedactQueryParams);
    final isError = failed || (statusCode != null && statusCode >= 400);
    final threshold = _options.networkSlowThresholdMs;
    final slow = threshold != null && durationMs != null && durationMs >= threshold;
    if (!shouldLogNetwork(scope: _options.networkLogScope, isError: isError, slow: slow)) return;
    final hasResponse = hasResponseOverride ?? (statusCode != null || response != null);
    final readable = buildNetworkReadable(
      method: method,
      url: safeUrl,
      statusCode: statusCode,
      durationMs: durationMs,
      error: error,
      errorType: errorType,
      hasResponse: hasResponse,
      request: request,
      response: response,
      slow: slow,
      slowThresholdMs: threshold,
    );
    final summary = readable['title']?.toString() ??
        error ??
        (statusCode != null ? '$method $url ($statusCode)' : hasResponse ? '$method $url' : '$method $url (no response)');
    _breadcrumbs.add(
      type: 'network',
      route: _screenTrail.currentRoute,
      message: summary,
      level: isError ? 'error' : 'info',
      data: {
        'method': method,
        'url': safeUrl,
        if (statusCode != null) 'statusCode': statusCode,
        if (durationMs != null) 'durationMs': durationMs,
        if (errorType != null) 'errorType': errorType,
        if (slow) 'slow': true,
        if (threshold != null) 'slowThresholdMs': threshold,
        if (!hasResponse) 'noResponse': true,
      },
    );
    _enqueue(
      type: fromInterceptor || isError ? 'network' : 'span',
      level: isError ? ScoutLevel.error : ScoutLevel.info,
      category: isError ? ScoutCategory.network : null,
      payload: {
        'message': summary,
        'network': {
          'method': method,
          'url': safeUrl,
          if (statusCode != null) 'statusCode': statusCode,
          if (durationMs != null) 'durationMs': durationMs,
          if (error != null) 'error': error,
          if (errorType != null) 'errorType': errorType,
          if (slow) 'slow': true,
          if (threshold != null) 'slowThresholdMs': threshold,
          'hasResponse': hasResponse,
          if (request != null) 'request': request,
          if (response != null) 'response': response,
          if (curl != null) 'curl': curl,
          'readable': readable,
          if (networkExtra != null && networkExtra.isNotEmpty) ...networkExtra,
        },
      },
      urgent: isError,
    );
  }

  /// Bridge [dio_resilient] `onRequestLog` — logs success/cache/queue only.
  ///
  /// Skip `outcome: error` here; [ScoutDioInterceptor] captures HTTP failures with body.
  void recordResilientLog(ScoutResilientLog log) {
    if (scoutResilientOutcomeIsError(log.outcome)) return;
    final rawUrl = log.url ?? log.path;
    recordNetwork(
      method: log.method,
      url: rawUrl,
      statusCode: log.statusCode,
      durationMs: log.durationMs,
      error: log.errorMessage,
      failed: log.statusCode != null && log.statusCode! >= 400,
      hasResponseOverride: log.statusCode != null,
      request: {
        'method': log.method,
        'url': resolveNetworkUrl(rawUrl, apiBaseUrl: _options.apiBaseUrl),
        'resilient': {
          'outcome': log.outcome,
          if (log.fromCache) 'fromCache': true,
          if (log.queuedOffline) 'queuedOffline': true,
          if (log.peakHourBucket != null) 'peakHourBucket': log.peakHourBucket,
        },
      },
      response: log.statusCode != null && log.errorMessage != null
          ? {'statusCode': log.statusCode, 'body': log.errorMessage}
          : log.statusCode != null
              ? {'statusCode': log.statusCode}
              : null,
    );
  }

  Future<void> flush() => _queue.flush();

  Future<void> dispose() async {
    _connectivitySub?.cancel();
    _goRouterDetach?.call();
    _goRouterDetach = null;
    _lifecycle?.dispose();
    _endSession();
    _queue.stop();
    await _queue.flush();
    _client.close(force: true);
    if (_instance == this) _instance = null;
  }

  void _endSession({String? reason}) {
    if (!_sessionTracker.isActive) return;
    _sessionTracker.stop(
      reason: reason,
      summary: buildSessionSummary(
        breadcrumbs: _breadcrumbs.toJson(),
        screenTrail: _screenTrail.toJson(),
      ),
    );
  }

  void _record({
    required ScoutLevel level,
    ScoutCategory? category,
    required String message,
    String? stack,
    Map<String, dynamic>? context,
    bool urgent = false,
  }) {
    if (!_options.enabledLevels.contains(level)) return;
    final cat = category ?? (level == ScoutLevel.error ? ScoutCategory.system : null);
    _enqueue(
      type: ingestTypeFor(level: level.wire, category: cat?.wire),
      level: level,
      category: cat,
      payload: {
        'message': message,
        if (stack != null && stack.isNotEmpty) 'stack': stack,
        'overview': {'title': message, if (stack != null && stack.isNotEmpty) 'hasStack': true},
        if (context != null) 'context': context,
      },
      urgent: urgent,
    );
  }

  void _sendSession(Map<String, dynamic> sessionPayload) {
    final action = sessionPayload['action'];
    if (action == 'start') {
      unawaited(SessionStore.writeActive(
        sessionId: sessionPayload['sessionId'] as String,
        startedAt: sessionPayload['startedAt'] as String,
      ));
    } else if (action == 'end') {
      unawaited(SessionStore.clear());
    }
    _enqueue(
      type: 'session',
      level: ScoutLevel.info,
      payload: sessionPayload,
      urgent: action == 'end',
    );
  }

  Map<String, dynamic> _buildPayload({
    required ScoutLevel level,
    ScoutCategory? category,
    required Map<String, dynamic> payload,
  }) {
    return {
      ...payload,
      'level': level.wire,
      if (category != null) 'category': category.wire,
      'environment': _options.environment,
      'release': _release,
      if (_user.hasData) 'user': _user.toJson(),
      if (!_user.hasData && _install['anonymousId'] != null)
        'user': {
          'id': _install['anonymousId'],
          'anonymousId': _install['anonymousId'],
          'sessionId': _sessionTracker.sessionId,
        },
      'device': Map<String, dynamic>.from(_device),
      'screen': _screenTrail.screenSnapshot(),
      'screenTrail': _screenTrail.toJson(),
      'breadcrumbs': _breadcrumbs.toJson(),
      if (_context.isNotEmpty) 'custom': redactContext(_context),
      'session': {
        'id': _sessionTracker.sessionId,
        'startedAt': _sessionTracker.startedAt.toUtc().toIso8601String(),
        'currentScreen': _screenTrail.currentRoute,
      },
    };
  }

  void _enqueue({
    required String type,
    required ScoutLevel level,
    ScoutCategory? category,
    required Map<String, dynamic> payload,
    bool urgent = false,
  }) {
    if (!isKnownEventType(type)) return;
    _queue.add(
      IngestEvent(
        type: type,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        payload: _buildPayload(level: level, category: category, payload: payload),
      ),
      urgent: urgent,
    );
  }

  void _installFlutterHooks() {
    final prevFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      captureFlutterError(details);
      prevFlutter?.call(details);
    };

    final prevPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      captureException(error, stack, category: ScoutCategory.crashing);
      flush();
      return prevPlatform?.call(error, stack) ?? false;
    };

    _lifecycle = ScoutLifecycleBinding(
      onPause: () async {
        _breadcrumbs.add(type: 'lifecycle', route: _screenTrail.currentRoute, message: 'App backgrounded');
        await flush();
      },
      onResume: () {
        _breadcrumbs.add(
          type: 'lifecycle',
          route: _screenTrail.currentRoute,
          message: 'App foregrounded',
        );
        unawaited(_refreshRemoteConfig());
        unawaited(_deviceCollector.refreshBattery().then((_) async {
          _device = await _deviceCollector.collect();
        }));
      },
      onEnd: () {
        _endSession();
        unawaited(flush());
      },
      backgroundTimeout: _options.sessionBackgroundTimeout,
      onBackgroundTimeout: () => _endSession(reason: 'background_timeout'),
    )..install();
  }

  void _watchConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
      final online = !results.contains(ConnectivityResult.none);
      _deviceCollector.patch({
        'isOnline': online,
        'connectivity': results.map((c) => c.name).toList(),
      });
      _device = await _deviceCollector.collect();
      _breadcrumbs.add(
        type: 'lifecycle',
        route: _screenTrail.currentRoute,
        message: online ? 'Back online' : 'Went offline',
        level: online ? 'info' : 'warning',
      );
    });
  }

  void _onRoute(String? route, {NavTransition navigationType = NavTransition.push}) {
    if (!_options.trackNavigation || route == null || route.isEmpty) return;
    _sessionTracker.onScreen(route, navigationType: navigationType);
    _crumbNav(route, navigationType: navigationType);
  }

  void _crumbNav(String route, {String? screenName, NavTransition navigationType = NavTransition.push}) {
    _breadcrumbs.add(
      type: 'navigation',
      route: route,
      message: screenName ?? route,
      data: {
        'navigationType': navigationType.wire,
        if (screenName != null) 'screenName': screenName,
      },
    );
  }

  Future<void> _refreshRemoteConfig({bool silent = false}) async {
    if (!_options.useRemoteConfig) return;
    final remote = await _remoteConfig.fetch();
    if (remote == null) return;
    if (remote.configVersion <= _configVersion) return;
    _configVersion = remote.configVersion;
    _options = _options.withRemote(remote.sdk);
    if (!silent && _options.debug) debugPrint('scout_logger_plus: remote config v$_configVersion applied');
  }

  void _onIngestConfigVersion(int version) {
    if (version <= _configVersion) return;
    unawaited(_refreshRemoteConfig());
  }

  void _crumbLog(String level, String message) {
    _breadcrumbs.add(type: 'log', route: _screenTrail.currentRoute, message: message, level: level);
  }

  void _crumbError(String message, {String? category}) {
    _breadcrumbs.add(
      type: 'error',
      route: _screenTrail.currentRoute,
      message: message,
      level: 'error',
      data: category != null ? {'category': category} : null,
    );
  }

  /// GoRouter location listener — call from [attachScoutGoRouter].
  void attachGoRouterListener(
    void Function(void Function()) addListener,
    void Function(void Function()) removeListener,
    String Function() currentLocation, {
    Duration debounce = const Duration(milliseconds: 100),
  }) {
    _goRouterDetach?.call();
    String? last;
    Timer? timer;
    void sync() {
      String loc;
      try {
        loc = currentLocation();
      } catch (_) {
        return;
      }
      if (loc.isEmpty || loc == last) return;
      last = loc;
      trackScreen(loc, navigationType: NavTransition.go);
    }

    void onChange() {
      timer?.cancel();
      timer = Timer(debounce, sync);
    }

    addListener(onChange);
    sync();
    _goRouterDetach = () {
      timer?.cancel();
      removeListener(onChange);
    };
  }
}

class ScoutUser {
  const ScoutUser({this.id, this.sessionId, this.email, this.name, this.traits});

  final String? id;
  final String? sessionId;
  final String? email;
  final String? name;
  final Map<String, dynamic>? traits;

  bool get hasData => id != null || sessionId != null || email != null || name != null;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (sessionId != null) 'sessionId': sessionId,
        if (email != null) 'email': email,
        if (name != null) 'name': name,
        if (traits != null && traits!.isNotEmpty) 'traits': traits,
      };
}
