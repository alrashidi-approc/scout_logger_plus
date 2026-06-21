import 'package:dio/dio.dart';

import 'network_capture.dart';
import 'scout.dart';
import 'scout_ingest_dio.dart';

/// Observes **app API** HTTP traffic — attach only to your own [Dio] instance.
///
/// Scout keeps a separate private ingest [Dio] internally. Never call
/// [attachScout] on that client.
///
/// Add this interceptor **first** on your app Dio so every request is timed
/// and logged on response or error (including timeouts with no response body).
class ScoutDioInterceptor extends Interceptor {
  ScoutDioInterceptor(this._scout);

  final Scout _scout;
  static const _startedKey = 'scout_started';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_skip(options)) {
      handler.next(options);
      return;
    }
    options.extra[_startedKey] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_skip(response.requestOptions)) {
      _finish(response.requestOptions, response: response);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_skip(err.requestOptions)) {
      _finish(err.requestOptions, error: err);
    }
    handler.next(err);
  }

  bool _skip(RequestOptions options) =>
      ScoutIngestDio.isIngestTraffic(options, _scout.baseUrl);

  void _finish(RequestOptions options, {Response<dynamic>? response, DioException? error}) {
    final opts = _scout.options;
    final started = options.extra[_startedKey] as int?;
    final durationMs = started != null ? DateTime.now().millisecondsSinceEpoch - started : null;
    final request = captureRequest(
      options,
      maxBodyLength: opts.networkMaxBodyLength,
      redactHeaders: opts.networkRedactHeaders,
      redactQueryParams: opts.networkRedactQueryParams,
      captureBodies: opts.networkCaptureBodies,
    );
    final capturedResponse = response != null
        ? captureResponse(
            response,
            maxBodyLength: opts.networkMaxBodyLength,
            redactHeaders: opts.networkRedactHeaders,
            captureBodies: opts.networkCaptureBodies,
          )
        : error?.response != null
            ? captureResponse(
                error!.response!,
                maxBodyLength: opts.networkMaxBodyLength,
                redactHeaders: opts.networkRedactHeaders,
                captureBodies: opts.networkCaptureBodies,
              )
            : null;

    final statusCode = response?.statusCode ?? error?.response?.statusCode;
    final failed = error != null || (statusCode != null && statusCode >= 400);
    final curl = buildCurl(
      options,
      maxBodyLength: opts.networkMaxBodyLength,
      redactHeaders: opts.networkRedactHeaders,
      redactQueryParams: opts.networkRedactQueryParams,
      captureBodies: opts.networkCaptureBodies,
      response: response ?? error?.response,
    );

    _scout.recordNetwork(
      method: options.method,
      url: request['url'] as String? ?? options.uri.toString(),
      statusCode: statusCode,
      durationMs: durationMs,
      error: error?.message,
      errorType: error != null ? dioErrorType(error) : null,
      failed: failed,
      fromInterceptor: true,
      request: request,
      response: capturedResponse,
      curl: curl,
    );
  }
}

/// Attach scout network logging to your **app API** [Dio] only.
extension ScoutAppDio on Dio {
  void attachScout([Scout? scout]) {
    interceptors.insert(0, ScoutDioInterceptor(scout ?? Scout.instance));
  }
}
