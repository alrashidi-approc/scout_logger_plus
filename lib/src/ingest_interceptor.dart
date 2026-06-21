import 'package:dio/dio.dart';

/// Adds ingest auth headers to every batch upload.
class IngestAuthInterceptor extends Interceptor {
  IngestAuthInterceptor(this.ingestKey);

  final String ingestKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = 'Bearer $ingestKey';
    options.headers['Content-Type'] = 'application/json';
    handler.next(options);
  }
}

/// Validates ingest responses and surfaces transport failures.
class IngestResultInterceptor extends Interceptor {
  IngestResultInterceptor({this.onFailure});

  final void Function(Object error)? onFailure;

  static const _ok = {200, 202};

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_ok.contains(response.statusCode)) {
      handler.next(response);
      return;
    }
    final err = DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Ingest rejected (${response.statusCode})',
    );
    onFailure?.call(err);
    handler.reject(err);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    onFailure?.call(err);
    handler.next(err);
  }
}
