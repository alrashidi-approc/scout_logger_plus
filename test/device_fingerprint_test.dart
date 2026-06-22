import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_plus/src/install_store.dart';

void main() {
  test('newInstallId prefers device_guard fingerprint', () {
    expect(
      InstallStore.newInstallId(deviceKey: 'efa01e25-ccf5-64a7-03eb-f0e6fda59ff3'),
      'efa01e25-ccf5-64a7-03eb-f0e6fda59ff3',
    );
    expect(InstallStore.newInstallId(deviceKey: 'unknown').length, greaterThan(30));
  });
}
