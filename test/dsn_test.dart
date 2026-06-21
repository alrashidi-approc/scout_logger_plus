import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_plus/scout_logger_plus.dart';

void main() {
  test('parseDsn extracts key, host, project', () {
    final dsn = parseDsn('http://sk_live_abc123@46.62.217.25:8081/proj_01');
    expect(dsn.ingestKey, 'sk_live_abc123');
    expect(dsn.baseUrl.toString(), 'http://46.62.217.25:8081');
    expect(dsn.projectId, 'proj_01');
  });

  test('parseDsn rejects missing port', () {
    expect(
      () => parseDsn('http://sk_live_abc123@46.62.217.25/proj_01'),
      throwsArgumentError,
    );
  });

  test('parseDsn rejects missing key', () {
    expect(() => parseDsn('http://46.62.217.25:8081/proj'), throwsArgumentError);
  });
}
