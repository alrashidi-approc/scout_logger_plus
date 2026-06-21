import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import 'screen_trail.dart';

typedef SessionEventSink = void Function(Map<String, dynamic> payload);

/// One app visit: open → close. Screens are tracked separately in breadcrumbs.
class SessionTracker {
  SessionTracker({
    required this.trail,
    required this.onEvent,
    String? sessionId,
  }) : sessionId = sessionId ?? const Uuid().v4();

  final ScreenTrail trail;
  final SessionEventSink onEvent;
  final String sessionId;

  late final DateTime startedAt = DateTime.now();
  bool _started = false;
  bool _ended = false;

  bool get isActive => _started && !_ended;

  void start() {
    if (_started || _ended) return;
    _started = true;
    onEvent({
      'action': 'start',
      'sessionId': sessionId,
      'startedAt': startedAt.toUtc().toIso8601String(),
    });
  }

  void stop({Map<String, dynamic>? summary, String? reason}) {
    if (!_started || _ended) return;
    _ended = true;
    trail.finalizeDwell();
    final endedAt = DateTime.now().toUtc();
    final durationMs = endedAt.difference(startedAt).inMilliseconds;
    onEvent({
      'action': 'end',
      'sessionId': sessionId,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'durationMs': durationMs,
      if (reason != null) 'reason': reason,
      if (summary != null && summary.isNotEmpty) 'summary': summary,
    });
  }

  void onScreen(String? route, {String action = 'view'}) => trail.record(route, action: action);
}

class ScoutNavigationObserver extends NavigatorObserver {
  ScoutNavigationObserver(this._onRoute);

  final void Function(String? route, {String action}) _onRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRoute(_name(route), action: 'push');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRoute(_name(previousRoute), action: 'pop');
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _onRoute(_name(newRoute), action: 'replace');
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  String? _name(Route<dynamic>? route) {
    if (route == null) return null;
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    final args = route.settings.arguments?.toString();
    if (args != null && args.isNotEmpty) return args;
    return route.toString().replaceFirst('RouteSettings(', '').replaceFirst(')', '');
  }
}
