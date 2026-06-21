import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_plus/src/ingest_interceptor.dart';

void main() {
  test('IngestAuthInterceptor adds bearer token', () async {
    final dio = Dio();
    dio.interceptors.addAll([
      IngestAuthInterceptor('sk_live_test'),
      InterceptorsWrapper(onRequest: (options, handler) {
        expect(options.headers['Authorization'], 'Bearer sk_live_test');
        expect(options.headers['Content-Type'], 'application/json');
        handler.resolve(Response(requestOptions: options, statusCode: 200));
      }),
    ]);

    await dio.get('/ping');
  });
}
