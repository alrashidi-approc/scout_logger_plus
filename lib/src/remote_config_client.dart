import 'package:dio/dio.dart';
import 'package:scout_models/scout_models.dart';

/// Fetches dashboard-controlled SDK settings from `GET /v1/client/config`.
class RemoteConfigClient {
  RemoteConfigClient(this._dio);

  static const configPath = '/v1/client/config';

  final Dio _dio;

  Future<ProjectRemoteConfig?> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(configPath);
      if (response.statusCode != 200) return null;
      final data = response.data;
      if (data == null || data['ok'] != true) return null;
      return ProjectRemoteConfig(
        configVersion: data['configVersion'] as int? ?? 1,
        updatedAt: data['updatedAt'] as String? ?? DateTime.now().toUtc().toIso8601String(),
        sdk: ProjectSdkConfig.fromJson(data['sdk'] is Map ? Map<String, dynamic>.from(data['sdk'] as Map) : null),
      );
    } catch (_) {
      return null;
    }
  }
}
