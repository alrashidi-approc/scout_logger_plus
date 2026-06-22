import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_plus/src/resilient_bridge.dart';

void main() {
  test('scoutResilientOutcomeIsError detects error outcomes', () {
    expect(scoutResilientOutcomeIsError('error'), isTrue);
    expect(scoutResilientOutcomeIsError('failed'), isTrue);
    expect(scoutResilientOutcomeIsError('success'), isFalse);
    expect(scoutResilientOutcomeIsError('cache'), isFalse);
  });

  test('ScoutResilientLog.fromMap parses dio_resilient-style payload', () {
    final log = ScoutResilientLog.fromMap({
      'method': 'GET',
      'path': '/inbox',
      'outcome': 'cache',
      'durationMs': 120,
      'fromCache': true,
      'peakHourBucket': 'morning',
    });
    expect(log.method, 'GET');
    expect(log.path, '/inbox');
    expect(log.outcome, 'cache');
    expect(log.fromCache, isTrue);
    expect(log.peakHourBucket, 'morning');
  });
}
