import 'package:flutter/material.dart';

import 'scout.dart';

/// Drop-in helper — merges scout navigation observers into your app shell.
///
/// ```dart
/// runApp(ScoutApp(
///   builder: (scoutObservers) => MaterialApp(
///     navigatorObservers: scoutObservers,
///     home: HomeScreen(),
///   ),
/// ));
/// ```
class ScoutApp extends StatelessWidget {
  const ScoutApp({super.key, required this.builder});

  final Widget Function(List<NavigatorObserver> scoutObservers) builder;

  @override
  Widget build(BuildContext context) =>
      builder(Scout.isInitialized ? Scout.instance.navigatorObservers : const []);
}
