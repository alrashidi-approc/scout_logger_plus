import 'dart:async';

import 'package:flutter/widgets.dart';

class ScoutLifecycleBinding with WidgetsBindingObserver {
  ScoutLifecycleBinding({
    required this.onPause,
    this.onResume,
    this.onEnd,
    this.backgroundTimeout,
    this.onBackgroundTimeout,
  });

  final Future<void> Function() onPause;
  final void Function()? onResume;
  final void Function()? onEnd;
  final Duration? backgroundTimeout;
  final void Function()? onBackgroundTimeout;

  bool _installed = false;
  Timer? _backgroundTimer;

  void install() {
    if (_installed) return;
    WidgetsBinding.instance.addObserver(this);
    _installed = true;
  }

  void dispose() {
    _backgroundTimer?.cancel();
    if (!_installed) return;
    WidgetsBinding.instance.removeObserver(this);
    _installed = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _backgroundTimer?.cancel();
        onResume?.call();
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(onPause());
        _scheduleBackgroundEnd();
      case AppLifecycleState.detached:
        _backgroundTimer?.cancel();
        onEnd?.call();
        unawaited(onPause());
    }
  }

  void _scheduleBackgroundEnd() {
    final timeout = backgroundTimeout;
    if (timeout == null || onBackgroundTimeout == null) return;
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer(timeout, () {
      onBackgroundTimeout?.call();
      unawaited(onPause());
    });
  }
}
