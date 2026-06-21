import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_plus/src/screen_trail.dart';
import 'package:scout_logger_plus/src/session_summary.dart';
import 'package:scout_models/scout_models.dart';

void main() {
  test('screen trail records dwell time and navigationType between routes', () {
    final trail = ScreenTrail();
    trail.record('/home', navigationType: NavTransition.push);
    trail.record('/checkout', navigationType: NavTransition.push);
    final json = trail.toJson();
    expect(json.first['route'], '/home');
    expect(json.first['navigationType'], 'push');
    expect(json.last['durationMs'], isA<int>());
    expect(json.last['durationMs'], greaterThanOrEqualTo(0));
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
