import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'ingest_interceptor.dart';

/// Private Dio used only to upload events to the scout ingest API.
///
/// Never share this instance with the app — use [ScoutDioInterceptor] on the
/// app's own [Dio] for network monitoring.
abstract final class ScoutIngestDio {
  static const internalKey = 'scout_internal';
  static const batchPath = '/v1/events/batch';

  static Dio create({
    required Uri baseUrl,
    required String ingestKey,
    void Function(Object error)? onFailure,
  }) {
    final dio = Dio(BaseOptions(
      baseUrl: _trimTrailingSlash(baseUrl.toString()),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      validateStatus: (_) => true,
      extra: const {internalKey: true},
    ));
    dio.interceptors.addAll([
      _InternalMarkerInterceptor(),
      IngestAuthInterceptor(ingestKey),
      IngestResultInterceptor(onFailure: onFailure),
    ]);
    return dio;
  }

  @visibleForTesting
  static Dio createForTest({
    required Uri baseUrl,
    required String ingestKey,
    required Dio dio,
    void Function(Object error)? onFailure,
  }) {
    dio.interceptors.addAll([
      _InternalMarkerInterceptor(),
      IngestAuthInterceptor(ingestKey),
      IngestResultInterceptor(onFailure: onFailure),
    ]);
    return dio;
  }

  static String _trimTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// Returns true when a request belongs to scout's private ingest client.
  static bool isIngestTraffic(RequestOptions options, Uri ingestBaseUrl) {
    if (options.extra[internalKey] == true) return true;

    final uri = options.uri;
    if (uri.host != ingestBaseUrl.host) return false;
    if (ingestBaseUrl.hasPort && uri.port != ingestBaseUrl.port) return false;
    return uri.path.contains(batchPath);
  }
}

class _InternalMarkerInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[ScoutIngestDio.internalKey] = true;
    handler.next(options);
  }
}
