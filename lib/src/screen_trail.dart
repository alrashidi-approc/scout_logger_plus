import 'package:scout_models/scout_models.dart';

class ScreenTrailEntry {
  ScreenTrailEntry({
    required this.route,
    required this.at,
    this.navigationType = NavTransition.push,
    this.screenName,
    this.durationMs,
  });

  final String route;
  final DateTime at;
  final NavTransition navigationType;
  final String? screenName;
  final int? durationMs;

  Map<String, dynamic> toJson() => screenTrailStep(
        route: route,
        navigationType: navigationType,
        screenName: screenName,
        at: at,
        durationMs: durationMs,
      );
}

/// Navigation flow the user followed before an event.
class ScreenTrail {
  static const maxEntries = 40;

  final List<ScreenTrailEntry> _entries = [];

  String? _currentRoute;
  String? _previousRoute;
  DateTime? _routeEnteredAt;

  String? get currentRoute => _currentRoute;
  String? get previousRoute => _previousRoute;

  void record(
    String? route, {
    NavTransition navigationType = NavTransition.push,
    String? screenName,
  }) {
    if (route == null || route.isEmpty) return;
    final dwellMs =
        _routeEnteredAt != null ? DateTime.now().difference(_routeEnteredAt!).inMilliseconds : null;
    _previousRoute = _currentRoute;
    _currentRoute = route;
    _routeEnteredAt = DateTime.now();
    _entries.add(ScreenTrailEntry(
      route: route,
      at: _routeEnteredAt!,
      navigationType: navigationType,
      screenName: screenName,
      durationMs: dwellMs,
    ));
    if (_entries.length > maxEntries) _entries.removeAt(0);
  }

  int? get currentScreenMs =>
      _routeEnteredAt != null ? DateTime.now().difference(_routeEnteredAt!).inMilliseconds : null;

  Map<String, dynamic> screenSnapshot() => {
        if (_currentRoute != null) 'currentRoute': _currentRoute,
        if (_previousRoute != null) 'previousRoute': _previousRoute,
        if (_entries.isNotEmpty) 'screenName': _entries.last.screenName ?? _currentRoute,
        if (currentScreenMs != null) 'currentScreenMs': currentScreenMs,
      };

  List<Map<String, dynamic>> toJson() => _entries.map((e) => e.toJson()).toList();
}
