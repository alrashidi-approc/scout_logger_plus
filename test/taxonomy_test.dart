import 'package:flutter_test/flutter_test.dart';
import 'package:scout_models/scout_models.dart';

void main() {
  test('ingestTypeFor maps level and category', () {
    expect(ingestTypeFor(level: 'error', category: 'crashing'), 'crash');
    expect(ingestTypeFor(level: 'error', category: 'network'), 'network');
    expect(ingestTypeFor(level: 'error', category: 'system'), 'error');
    expect(ingestTypeFor(level: 'info'), 'log');
    expect(ingestTypeFor(level: 'warning'), 'log');
    expect(ingestTypeFor(level: 'success'), 'log');
  });
}
