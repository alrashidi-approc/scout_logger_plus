Map<String, dynamic> buildSessionSummary({
  required List<Map<String, dynamic>> breadcrumbs,
  required List<Map<String, dynamic>> screenTrail,
}) {
  var networkCalls = 0;
  var errors = 0;
  var logs = 0;
  var actions = 0;
  for (final b in breadcrumbs) {
    switch (b['type']) {
      case 'network':
        networkCalls++;
      case 'error':
        errors++;
      case 'log':
        logs++;
      case 'action':
        actions++;
      default:
        if (b['level'] == 'error') errors++;
    }
  }

  final routes = <String>{};
  String? longestScreen;
  var longestMs = 0;
  for (final step in screenTrail) {
    final route = step['route']?.toString();
    if (route != null && route.isNotEmpty) routes.add(route);
    final ms = step['durationMs'];
    if (ms is int && ms > longestMs) {
      longestMs = ms;
      longestScreen = route;
    }
  }

  return {
    'screensVisited': routes.length,
    'navigationSteps': screenTrail.length,
    'networkCalls': networkCalls,
    'errors': errors,
    'logs': logs,
    if (actions > 0) 'actions': actions,
    if (longestScreen != null) 'longestScreen': longestScreen,
    if (longestMs > 0) 'longestScreenMs': longestMs,
  };
}
