import 'package:flutter_test/flutter_test.dart';

import 'package:scout_logger_plus/src/network_capture.dart';
import 'package:scout_logger_plus/src/session_summary.dart';

void main() {
  test('buildNetworkReadable flags slow requests', () {
    final readable = buildNetworkReadable(
      method: 'GET',
      url: 'https://api.example.com/users',
      statusCode: 200,
      durationMs: 4500,
      hasResponse: true,
      slow: true,
      slowThresholdMs: 3000,
    );
    expect(readable['slow'], isTrue);
    expect(readable['title'], contains('slow'));
    expect(readable['lines'], contains('Exceeded the slow threshold of 3.0s.'));
  });

  test('buildSessionSummary counts user actions', () {
    final summary = buildSessionSummary(
      breadcrumbs: [
        {'type': 'action'},
        {'type': 'action'},
        {'type': 'network'},
      ],
      screenTrail: [],
    );
    expect(summary['actions'], 2);
    expect(summary['networkCalls'], 1);
  });
}
