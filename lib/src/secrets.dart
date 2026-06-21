const _redacted = '[Redacted]';

const _sensitiveQueryKeys = {
  'token',
  'access_token',
  'refresh_token',
  'id_token',
  'api_key',
  'apikey',
  'key',
  'secret',
  'password',
  'passwd',
  'auth',
  'authorization',
  'session',
  'session_id',
  'dsn',
};

const _sensitiveContextKeys = {
  'password',
  'passwd',
  'secret',
  'token',
  'access_token',
  'refresh_token',
  'api_key',
  'apikey',
  'authorization',
  'scout_dsn',
  'dsn',
  'ingest_key',
};

bool isSensitiveKey(String key) {
  final k = key.toLowerCase().replaceAll('-', '_');
  if (_sensitiveContextKeys.contains(k)) return true;
  return k.contains('password') || k.contains('secret') || k.contains('token') || k.endsWith('_key');
}

Map<String, dynamic> redactContext(Map<String, dynamic> data) {
  return {
    for (final e in data.entries)
      e.key: isSensitiveKey(e.key)
          ? _redacted
          : e.value is Map
              ? redactContext(Map<String, dynamic>.from(e.value as Map))
              : e.value,
  };
}

/// Strip credentials from URLs before they are sent to the dashboard.
String redactUrl(String url, {Set<String>? redactQueryKeys}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;

  final keys = redactQueryKeys ?? _sensitiveQueryKeys;
  final query = {
    for (final e in uri.queryParameters.entries)
      e.key: keys.contains(e.key.toLowerCase()) ? _redacted : e.value,
  };

  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
    queryParameters: query.isEmpty ? null : query,
    fragment: uri.fragment.isEmpty ? null : uri.fragment,
  ).toString();
}

String redactSecretsInText(String text, Iterable<String> secrets) {
  var out = text;
  for (final secret in secrets) {
    if (secret.length < 8) continue;
    out = out.replaceAll(secret, _redacted);
  }
  return out;
}

String maskIngestKey(String key) {
  if (key.length <= 12) return _redacted;
  return '${key.substring(0, 8)}…${_redacted}';
}
