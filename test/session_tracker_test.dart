import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_plus/src/screen_trail.dart';
import 'package:scout_logger_plus/src/session_tracker.dart';
import 'package:scout_models/scout_models.dart';

void main() {
  test('start and stop emit one session event each with duration', () {
    final events = <Map<String, dynamic>>[];
    final tracker = SessionTracker(
      trail: ScreenTrail(),
      onEvent: events.add,
      sessionId: 'session-1',
      heartbeatInterval: const Duration(hours: 1),
    );

    tracker.start();
    tracker.stop(summary: {'screensVisited': 2});

    expect(events, hasLength(2));
    expect(events.first['action'], 'start');
    expect(events.first.containsKey('durationMs'), isFalse);
    expect(events.last['action'], 'end');
    expect(events.last['durationMs'], isA<int>());
    expect(events.last['summary'], {'screensVisited': 2});
  });

  test('onScreen updates trail only — no session events', () {
    final events = <Map<String, dynamic>>[];
    final trail = ScreenTrail();
    final tracker = SessionTracker(
      trail: trail,
      onEvent: events.add,
      sessionId: 'session-1',
      heartbeatInterval: const Duration(hours: 1),
    );

    tracker.start();
    tracker.onScreen('/home', navigationType: NavTransition.push);

    expect(events, hasLength(1));
    expect(trail.currentRoute, '/home');
    expect(trail.toJson().single['navigationType'], 'push');
  });

  test('isActive reflects session state', () {
    final tracker = SessionTracker(trail: ScreenTrail(), onEvent: (_) {});
    expect(tracker.isActive, isFalse);
    tracker.start();
    expect(tracker.isActive, isTrue);
    tracker.stop();
    expect(tracker.isActive, isFalse);
  });
}
