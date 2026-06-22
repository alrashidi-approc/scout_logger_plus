import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_plus/scout_logger_plus.dart';

void main() {
  test('shouldLogNetwork respects scope', () {
    expect(
      shouldLogNetwork(scope: ScoutNetworkLogScope.all, isError: false, slow: false),
      isTrue,
    );
    expect(
      shouldLogNetwork(scope: ScoutNetworkLogScope.errorsOnly, isError: true, slow: false),
      isTrue,
    );
    expect(
      shouldLogNetwork(scope: ScoutNetworkLogScope.errorsOnly, isError: false, slow: true),
      isFalse,
    );
    expect(
      shouldLogNetwork(scope: ScoutNetworkLogScope.slowOnly, isError: true, slow: false),
      isFalse,
    );
    expect(
      shouldLogNetwork(scope: ScoutNetworkLogScope.slowOnly, isError: false, slow: true),
      isTrue,
    );
  });

  test('resolveNetworkUrl joins apiBaseUrl with path', () {
    expect(
      resolveNetworkUrl('/inbox', apiBaseUrl: 'https://api.example.com'),
      'https://api.example.com/inbox',
    );
    expect(
      resolveNetworkUrl('https://api.example.com/inbox', apiBaseUrl: 'https://other.com'),
      'https://api.example.com/inbox',
    );
  });

  test('buildNetworkReadable handles path-only url', () {
    final readable = buildNetworkReadable(
      method: 'GET',
      url: '/EPAMobileAppServices/resources/inbox',
      statusCode: 404,
      hasResponse: true,
      response: {'body': 'not found'},
    );
    expect(readable['title'], contains('/EPAMobileAppServices'));
    expect(readable['outcome'], 'http_error');
  });
}
