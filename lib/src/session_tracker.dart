import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:scout_models/scout_models.dart';
import 'package:uuid/uuid.dart';

import 'screen_trail.dart';

typedef SessionEventSink = void Function(Map<String, dynamic> payload);

/// One app visit: open → close. Screens are tracked separately in breadcrumbs.
class SessionTracker {
  SessionTracker({
    required this.trail,
    required this.onEvent,
    String? sessionId,
    this.heartbeatInterval = const Duration(minutes: 2),
  }) : sessionId = sessionId ?? const Uuid().v4();

  final ScreenTrail trail;
  final SessionEventSink onEvent;
  final String sessionId;
  final Duration heartbeatInterval;

  late final DateTime startedAt = DateTime.now();
  bool _started = false;
  bool _ended = false;
  Timer? _heartbeat;

  bool get isActive => _started && !_ended;

  void start() {
    if (_started || _ended) return;
    _started = true;
    onEvent({
      'action': 'start',
      'sessionId': sessionId,
      'startedAt': startedAt.toUtc().toIso8601String(),
    });
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _pulse());
  }

  void _pulse() {
    if (!_started || _ended) return;
    onEvent({
      'action': 'heartbeat',
      'sessionId': sessionId,
      'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
    });
  }

  void stop({Map<String, dynamic>? summary, String? reason}) {
    if (!_started || _ended) return;
    _ended = true;
    _heartbeat?.cancel();
    _heartbeat = null;
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

  void onScreen(
    String? route, {
    NavTransition navigationType = NavTransition.push,
    String? screenName,
  }) =>
      trail.record(route, navigationType: navigationType, screenName: screenName);
}

class ScoutNavigationObserver extends NavigatorObserver {
  ScoutNavigationObserver(this._onRoute);

  final void Function(String? route, {NavTransition navigationType}) _onRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRoute(_name(route), navigationType: NavTransition.push);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRoute(_name(previousRoute), navigationType: NavTransition.pop);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _onRoute(_name(newRoute), navigationType: NavTransition.replace);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRoute(_name(previousRoute), navigationType: NavTransition.remove);
    super.didRemove(route, previousRoute);
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
