import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:scout_models/scout_models.dart';

import 'scout_ingest_dio.dart';

/// Uploads batched events to the scout server using a private ingest [Dio].
class IngestClient {
  factory IngestClient({
    required Uri baseUrl,
    required String ingestKey,
    void Function(Object error)? onError,
  }) {
    return IngestClient._(
      ingestKey: ingestKey,
      dio: ScoutIngestDio.create(
        baseUrl: baseUrl,
        ingestKey: ingestKey,
        onFailure: onError,
      ),
    );
  }

  @visibleForTesting
  factory IngestClient.forTest({
    required Uri baseUrl,
    required String ingestKey,
    required Dio dio,
    void Function(Object error)? onError,
  }) {
    return IngestClient._(
      ingestKey: ingestKey,
      dio: ScoutIngestDio.createForTest(
        baseUrl: baseUrl,
        ingestKey: ingestKey,
        dio: dio,
        onFailure: onError,
      ),
    );
  }

  IngestClient._({required this.ingestKey, required Dio dio}) : _dio = dio;

  final String ingestKey;
  final Dio _dio;

  Future<bool> send(List<IngestEvent> events) async {
    if (events.isEmpty) return true;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ScoutIngestDio.batchPath,
        data: {'events': events.map((e) => e.toJson()).toList()},
      );
      final code = response.statusCode;
      return code == 200 || code == 202;
    } on DioException {
      return false;
    }
  }

  void close({bool force = false}) => _dio.close(force: force);
}
