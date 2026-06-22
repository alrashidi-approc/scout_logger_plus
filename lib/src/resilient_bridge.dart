/// Bridge for [dio_resilient](https://pub.dev/packages/dio_resilient) `onRequestLog` callbacks.
///
/// No dependency on dio_resilient — map your log to [ScoutResilientLog] and call
/// [Scout.recordResilientLog]. Skip `outcome: error` (use [ScoutDioInterceptor] for HTTP errors).
class ScoutResilientLog {
  const ScoutResilientLog({
    required this.method,
    required this.path,
    required this.outcome,
    this.durationMs,
    this.statusCode,
    this.errorMessage,
    this.fromCache = false,
    this.queuedOffline = false,
    this.peakHourBucket,
    this.url,
  });

  final String method;
  /// Path or absolute URL.
  final String path;
  /// e.g. `success`, `cache`, `queued`, `error` — [Scout.recordResilientLog] skips `error`.
  final String outcome;
  final int? durationMs;
  final int? statusCode;
  final String? errorMessage;
  final bool fromCache;
  final bool queuedOffline;
  final String? peakHourBucket;
  /// When set, used instead of [path].
  final String? url;

  /// Map from dio_resilient-style JSON without adding a package dependency.
  factory ScoutResilientLog.fromMap(Map<String, dynamic> map) => ScoutResilientLog(
        method: map['method']?.toString() ?? 'GET',
        path: map['path']?.toString() ?? map['url']?.toString() ?? '/',
        outcome: map['outcome']?.toString() ?? 'success',
        durationMs: _intOrNull(map['durationMs']),
        statusCode: _intOrNull(map['statusCode']),
        errorMessage: map['errorMessage']?.toString() ?? map['error']?.toString(),
        fromCache: map['fromCache'] == true || map['cacheHit'] == true,
        queuedOffline: map['queuedOffline'] == true || map['queued'] == true,
        peakHourBucket: map['peakHourBucket']?.toString(),
        url: map['url']?.toString(),
      );

  static int? _intOrNull(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');
}

bool scoutResilientOutcomeIsError(String outcome) {
  final o = outcome.toLowerCase().trim();
  return o == 'error' || o == 'failed' || o == 'failure';
}
