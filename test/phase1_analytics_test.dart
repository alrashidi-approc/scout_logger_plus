import 'package:flutter_test/flutter_test.dart';

import 'package:scout_logger_plus/src/screen_trail.dart';
import 'package:scout_logger_plus/src/session_summary.dart';

void main() {
  test('screen trail records dwell time between routes', () {
    final trail = ScreenTrail();
    trail.record('/home');
    trail.record('/checkout');
    final json = trail.toJson();
    expect(json.first['route'], '/home');
    expect(json.first['durationMs'], isA<int>());
    expect(json.first['durationMs'], greaterThanOrEqualTo(0));
  });

  test('buildSessionSummary aggregates breadcrumbs and trail', () {
    final summary = buildSessionSummary(
      breadcrumbs: [
        {'type': 'navigation'},
        {'type': 'network'},
        {'type': 'error'},
        {'type': 'log'},
      ],
      screenTrail: [
        {'route': '/home', 'durationMs': 1000},
        {'route': '/checkout', 'durationMs': 5000},
      ],
    );
    expect(summary['screensVisited'], 2);
    expect(summary['networkCalls'], 1);
    expect(summary['errors'], 1);
    expect(summary['longestScreen'], '/checkout');
    expect(summary['longestScreenMs'], 5000);
  });
}
