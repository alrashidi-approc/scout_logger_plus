import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_plus/src/breadcrumbs.dart';

void main() {
  test('records navigation log and network steps', () {
    final buf = BreadcrumbBuffer(maxEntries: 10);
    buf.add(type: 'navigation', route: '/', message: 'Home', data: {'action': 'push'});
    buf.add(type: 'log', route: '/', message: 'Opened app', level: 'info');
    buf.add(type: 'network', route: '/', message: 'GET /api', data: {'method': 'GET', 'url': '/api'});

    final items = buf.toJson();
    expect(items, hasLength(3));
    expect(items.first['type'], 'navigation');
    expect(items.first['label'], 'Home');
    expect(items.first['timestamp'], isNotNull);
    expect(items.last['type'], 'network');
  });
}
