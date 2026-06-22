import 'package:scout_models/scout_models.dart';

/// Severity — shown in dashboard filters and badges.
enum ScoutLevel { error, info, warning, success }

/// Error kind — drives issue grouping and dashboard categories.
enum ScoutCategory { network, system, crashing, logic, ui }

/// Which HTTP calls [ScoutDioInterceptor] / [Scout.recordNetwork] emit.
enum ScoutNetworkLogScope { all, errorsOnly, slowOnly }

extension ScoutNetworkLogScopeX on ScoutNetworkLogScope {
  String get wire => name;

  static ScoutNetworkLogScope parse(String? raw) => switch (normalizeNetworkLogScope(raw)) {
        'errorsOnly' => ScoutNetworkLogScope.errorsOnly,
        'slowOnly' => ScoutNetworkLogScope.slowOnly,
        _ => ScoutNetworkLogScope.all,
      };
}

extension ScoutLevelX on ScoutLevel {
  String get wire => name;

  static ScoutLevel parse(String? raw) => ScoutLevel.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => ScoutLevel.error,
      );
}

extension ScoutCategoryX on ScoutCategory {
  String get wire => name;

  static ScoutCategory parse(String? raw) => ScoutCategory.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => ScoutCategory.system,
      );
}
