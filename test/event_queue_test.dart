import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_plus/src/event_queue.dart';
import 'package:scout_logger_plus/src/ingest_client.dart';
import 'package:scout_logger_plus/src/scout_ingest_dio.dart';
import 'package:scout_models/scout_models.dart';

IngestClient _mockClient(void Function(RequestOptions options, RequestInterceptorHandler handler) onRequest) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8081',
    validateStatus: (_) => true,
  ));
  dio.interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return IngestClient.forTest(
    baseUrl: Uri.parse('http://localhost:8081'),
    ingestKey: 'sk_live_test',
    dio: dio,
  );
}

void main() {
  test('flush sends batch and clears queue', () async {
    var posts = 0;
    final client = _mockClient((options, handler) {
      posts++;
      expect(options.path, ScoutIngestDio.batchPath);
      expect(options.headers['Authorization'], 'Bearer sk_live_test');
      expect(options.extra[ScoutIngestDio.internalKey], isTrue);
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 202,
        data: {'ok': true, 'accepted': 1},
      ));
    });
    final queue = EventQueue(
      client: client,
      maxBatch: 10,
      flushInterval: const Duration(hours: 1),
    );
    queue.add(const IngestEvent(type: 'error', timestamp: '2026-01-01T00:00:00Z', payload: {'message': 'x'}));
    await queue.flush();
    expect(posts, 1);
    client.close();
  });

  test('send returns false on ingest rejection', () async {
    final client = _mockClient((options, handler) {
      handler.resolve(Response(requestOptions: options, statusCode: 500));
    });

    final ok = await client.send([
      const IngestEvent(type: 'error', timestamp: '2026-01-01T00:00:00Z', payload: {'message': 'x'}),
    ]);

    expect(ok, isFalse);
    client.close();
  });
}
