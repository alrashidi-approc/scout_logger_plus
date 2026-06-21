import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_plus/src/remote_config_client.dart';

void main() {
  test('fetch parses client config response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8081', validateStatus: (_) => true));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'ok': true,
          'configVersion': 3,
          'updatedAt': '2026-06-21T20:00:00Z',
          'sdk': {
            'enabledLevels': ['error'],
            'networkIgnoreStatusCodes': [401],
          },
        },
      ));
    }));

    final remote = await RemoteConfigClient(dio).fetch();
    expect(remote, isNotNull);
    expect(remote!.configVersion, 3);
    expect(remote.sdk.resolved().enabledLevels, ['error']);
    expect(remote.sdk.resolved().networkIgnoreStatusCodes, [401]);
  });

  test('fetch returns null on failure', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8081', validateStatus: (_) => true));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(requestOptions: options, statusCode: 500));
    }));

    expect(await RemoteConfigClient(dio).fetch(), isNull);
  });
}
