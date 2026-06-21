import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_plus/src/scout_ingest_dio.dart';

void main() {
  const ingestBase = 'http://localhost:8081';

  test('marks ingest dio requests as internal', () {
    final dio = ScoutIngestDio.create(
      baseUrl: Uri.parse(ingestBase),
      ingestKey: 'sk_live_test',
    );

    expect(dio.options.extra[ScoutIngestDio.internalKey], isTrue);
    dio.close(force: true);
  });

  test('isIngestTraffic detects internal extra flag', () {
    final options = RequestOptions(path: '/anything', extra: {ScoutIngestDio.internalKey: true});

    expect(
      ScoutIngestDio.isIngestTraffic(options, Uri.parse(ingestBase)),
      isTrue,
    );
  });

  test('isIngestTraffic detects scout batch path on ingest host', () {
    final options = RequestOptions(
      path: ScoutIngestDio.batchPath,
      baseUrl: ingestBase,
    );

    expect(
      ScoutIngestDio.isIngestTraffic(options, Uri.parse(ingestBase)),
      isTrue,
    );
  });

  test('isIngestTraffic ignores normal app API calls', () {
    final options = RequestOptions(
      path: '/api/users',
      baseUrl: 'https://api.example.com',
    );

    expect(
      ScoutIngestDio.isIngestTraffic(options, Uri.parse(ingestBase)),
      isFalse,
    );
  });
}
