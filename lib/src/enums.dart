/// Severity — shown in dashboard filters and badges.
enum ScoutLevel { error, info, warning, success }

/// Error kind — drives issue grouping and dashboard categories.
enum ScoutCategory { network, system, crashing, logic, ui }

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
