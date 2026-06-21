class ScreenTrailEntry {
  ScreenTrailEntry({
    required this.route,
    required this.at,
    this.action = 'view',
    this.screenName,
    this.durationMs,
  });

  final String route;
  final DateTime at;
  final String action;
  final String? screenName;
  int? durationMs;

  Map<String, dynamic> toJson() => {
        'route': route,
        'action': action,
        'at': at.toUtc().toIso8601String(),
        if (screenName != null) 'screenName': screenName,
        if (durationMs != null) 'durationMs': durationMs,
      };
}

/// Navigation flow the user followed before an error.
class ScreenTrail {
  static const maxEntries = 40;

  final List<ScreenTrailEntry> _entries = [];

  String? _currentRoute;
  String? _previousRoute;
  DateTime? _routeEnteredAt;

  String? get currentRoute => _currentRoute;
  String? get previousRoute => _previousRoute;

  void record(String? route, {String action = 'view', String? screenName}) {
    if (route == null || route.isEmpty) return;
    _closeCurrentDwell();
    _previousRoute = _currentRoute;
    _currentRoute = route;
    _routeEnteredAt = DateTime.now();
    _entries.add(ScreenTrailEntry(route: route, at: _routeEnteredAt!, action: action, screenName: screenName));
    if (_entries.length > maxEntries) _entries.removeAt(0);
  }

  void finalizeDwell() => _closeCurrentDwell();

  void _closeCurrentDwell() {
    if (_entries.isEmpty || _routeEnteredAt == null) return;
    _entries.last.durationMs = DateTime.now().difference(_routeEnteredAt!).inMilliseconds;
  }

  Map<String, dynamic> screenSnapshot() => {
        if (_currentRoute != null) 'currentRoute': _currentRoute,
        if (_previousRoute != null) 'previousRoute': _previousRoute,
        if (_entries.isNotEmpty) 'screenName': _entries.last.screenName ?? _currentRoute,
        if (_entries.isNotEmpty && _entries.last.durationMs != null)
          'currentScreenMs': _entries.last.durationMs,
      };

  List<Map<String, dynamic>> toJson() {
    finalizeDwell();
    return _entries.map((e) => e.toJson()).toList();
  }
}
