import 'package:flutter_test/flutter_test.dart';

import 'package:scout_logger_plus/src/secrets.dart';

void main() {
  test('redactUrl strips userinfo and sensitive query params', () {
    final out = redactUrl(
      'https://user:secret@api.example.com/pay?token=abc123&page=1',
      redactQueryKeys: {'token'},
    );
    expect(out, isNot(contains('secret')));
    expect(out, isNot(contains('user:')));
    expect(out, contains('Redacted'));
    expect(out, contains('page=1'));
  });

  test('redactContext masks sensitive keys', () {
    final out = redactContext({
      'plan': 'pro',
      'api_key': 'sk_live_xyz',
      'nested': {'password': 'hunter2'},
    });
    expect(out['plan'], 'pro');
    expect(out['api_key'], '[Redacted]');
    expect(out['nested'], {'password': '[Redacted]'});
  });

  test('redactSecretsInText removes ingest key from error strings', () {
    const key = 'sk_live_super_secret_key_12345';
    expect(
      redactSecretsInText('Failed auth with $key on host', [key]),
      isNot(contains(key)),
    );
  });
}
