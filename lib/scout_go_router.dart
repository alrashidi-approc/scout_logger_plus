/// GoRouter helpers — import separately so apps without go_router skip this file.
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'src/scout.dart';

/// Observers for [GoRouter.observers] — same as [Scout.navigatorObservers].
List<NavigatorObserver> scoutRouterObservers([Scout? scout]) {
  final s = scout ?? (Scout.isInitialized ? Scout.instance : null);
  return s?.navigatorObservers ?? const [];
}

/// Tracks [GoRouterState.matchedLocation] with debounce (clean paths vs raw Route names).
///
/// Prefer this over [scoutRouterObservers] alone for GoRouter apps.
/// Do not combine both — you will get duplicate screen events.
void attachScoutGoRouter(
  GoRouter router, {
  Scout? scout,
  Duration debounce = const Duration(milliseconds: 100),
}) {
  if (!Scout.isInitialized && scout == null) return;
  final s = scout ?? Scout.instance;
  final provider = router.routeInformationProvider;
  s.attachGoRouterListener(
    provider.addListener,
    provider.removeListener,
    () => router.state.matchedLocation,
    debounce: debounce,
  );
}
