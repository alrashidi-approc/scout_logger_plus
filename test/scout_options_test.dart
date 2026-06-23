import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_plus/src/scout_options.dart';
import 'package:scout_logger_plus/src/enums.dart';
import 'package:scout_models/scout_models.dart';

void main() {
  test('withRemote merges dashboard sdk knobs', () {
    const local = ScoutOptions(
      networkIgnoreStatusCodes: {401},
      enabledLevels: {ScoutLevel.error, ScoutLevel.info},
    );
    final merged = local.withRemote(const ProjectSdkConfig(
      enabledLevels: ['error', 'warning'],
      networkIgnoreStatusCodes: [403, 404],
      trackNavigation: false,
      networkLogScope: 'errorsOnly',
    ));

    expect(merged.enabledLevels, {ScoutLevel.error, ScoutLevel.warning});
    expect(merged.networkIgnoreStatusCodes, {403, 404});
    expect(merged.trackNavigation, isFalse);
    expect(merged.networkLogScope, ScoutNetworkLogScope.errorsOnly);
    expect(merged.environment, local.environment);
    expect(merged.useRemoteConfig, local.useRemoteConfig);
  });

  test('withRemote widens errorsOnly to all when info or success enabled', () {
    const local = ScoutOptions();
    final merged = local.withRemote(const ProjectSdkConfig(
      enabledLevels: ['error', 'info', 'warning', 'success'],
      networkLogScope: 'errorsOnly',
    ));
    expect(merged.networkLogScope, ScoutNetworkLogScope.all);
  });
}
