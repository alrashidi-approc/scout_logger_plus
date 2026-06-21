import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scout_logger_plus/src/network_capture.dart';

void main() {
  test('sanitizeHeaders redacts sensitive values', () {
    final out = sanitizeHeaders({
      'Authorization': 'Bearer secret',
      'Content-Type': 'application/json',
    });
    expect(out['Authorization'], '[Redacted]');
    expect(out['Content-Type'], 'application/json');
  });

  test('truncateBody limits large strings', () {
    expect(truncateBody('hello world', 5), 'hello… [truncated 6 chars]');
  });

  test('buildCurl includes method url headers and body', () {
    final options = RequestOptions(
      method: 'POST',
      path: '/pay',
      baseUrl: 'https://api.example.com',
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer x'},
      data: '{"amount":10}',
    );
    final curl = buildCurl(options);
    expect(curl, contains("curl -X POST"));
    expect(curl, contains('https://api.example.com/pay'));
    expect(curl, contains('[Redacted]'));
    expect(curl, contains('{"amount":10}'));
  });

  test('captureRequest and captureResponse include structured data', () {
    final options = RequestOptions(
      method: 'GET',
      path: '/users',
      baseUrl: 'https://api.example.com',
      queryParameters: {'page': '1'},
    );
    final request = captureRequest(options);
    expect(request['method'], 'GET');
    expect(request['query'], {'page': '1'});

    final response = captureResponse(
      Response(
        requestOptions: options,
        statusCode: 200,
        data: {'ok': true},
        headers: Headers.fromMap({'content-type': ['application/json']}),
      ),
    );
    expect(response?['statusCode'], 200);
    expect(response?['body'], contains('ok'));
  });

  test('buildNetworkReadable explains no response', () {
    final readable = buildNetworkReadable(
      method: 'GET',
      url: 'https://api.example.com/users',
      error: 'Receive timeout',
      errorType: 'receiveTimeout',
      hasResponse: false,
      durationMs: 15000,
      request: {'headers': {'Accept': 'application/json'}},
    );
    expect(readable['outcome'], 'no_response');
    expect(readable['title'], contains('no response'));
    expect(readable['lines'], isA<List>());
  });
}
