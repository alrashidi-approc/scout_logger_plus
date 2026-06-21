import 'dart:convert';

import 'package:dio/dio.dart';

import 'secrets.dart';

const _defaultRedact = {
  'authorization',
  'cookie',
  'set-cookie',
  'x-api-key',
  'x-auth-token',
  'proxy-authorization',
};

String? truncateBody(dynamic data, int maxLen) {
  if (data == null) return null;
  final text = switch (data) {
    String s => s,
    List<int> bytes when bytes.length > maxLen => '<binary ${bytes.length} bytes>',
    List<int> bytes => utf8.decode(bytes, allowMalformed: true),
    _ => _encodeJson(data),
  };
  if (text.length <= maxLen) return text;
  return '${text.substring(0, maxLen)}… [truncated ${text.length - maxLen} chars]';
}

Map<String, dynamic> sanitizeHeaders(
  Map<String, dynamic> headers, {
  Set<String> redact = _defaultRedact,
}) {
  return {
    for (final e in headers.entries)
      e.key: redact.contains(e.key.toLowerCase())
          ? '[Redacted]'
          : e.value is List
              ? (e.value as List).join(', ')
              : e.value,
  };
}

Map<String, dynamic> captureRequest(
  RequestOptions options, {
  int maxBodyLength = 8192,
  Set<String> redactHeaders = _defaultRedact,
  Set<String> redactQueryParams = const {},
  bool captureBodies = true,
}) {
  final url = redactUrl(options.uri.toString(), redactQueryKeys: redactQueryParams);
  return {
    'method': options.method,
    'url': url,
    if (options.queryParameters.isNotEmpty)
      'query': {
        for (final e in options.queryParameters.entries)
          e.key: redactQueryParams.contains(e.key.toLowerCase()) ? '[Redacted]' : e.value,
      },
    'headers': sanitizeHeaders(Map<String, dynamic>.from(options.headers), redact: redactHeaders),
    if (captureBodies && options.data != null) 'body': truncateBody(options.data, maxBodyLength),
  };
}

Map<String, dynamic>? captureResponse(
  Response<dynamic> response, {
  int maxBodyLength = 8192,
  Set<String> redactHeaders = _defaultRedact,
  bool captureBodies = true,
}) {
  return {
    'statusCode': response.statusCode,
    'headers': sanitizeHeaders(Map<String, dynamic>.from(response.headers.map.map(
          (k, v) => MapEntry(k, v.length == 1 ? v.first : v.join(', ')),
        )), redact: redactHeaders),
    if (captureBodies && response.data != null) 'body': truncateBody(response.data, maxBodyLength),
  };
}

String buildCurl(
  RequestOptions options, {
  int maxBodyLength = 8192,
  Set<String> redactHeaders = _defaultRedact,
  Set<String> redactQueryParams = const {},
  bool captureBodies = true,
  Response<dynamic>? response,
}) {
  final buf = StringBuffer('curl -X ${options.method}');
  final requestHeaders = sanitizeHeaders(Map<String, dynamic>.from(options.headers), redact: redactHeaders);
  for (final e in requestHeaders.entries) {
    buf.write(' -H ${_shellQuote('${e.key}: ${e.value}')}');
  }
  if (captureBodies && options.data != null) {
    final body = truncateBody(options.data, maxBodyLength);
    if (body != null) buf.write(' -d ${_shellQuote(body)}');
  }
  buf.write(' ${_shellQuote(redactUrl(options.uri.toString(), redactQueryKeys: redactQueryParams))}');
  if (response != null) {
    buf.write(' # → ${response.statusCode}');
  }
  return buf.toString();
}

String dioErrorType(DioException err) => err.type.name;

/// Human-readable summary for dashboard display (full payload kept separately).
Map<String, dynamic> buildNetworkReadable({
  required String method,
  required String url,
  int? statusCode,
  int? durationMs,
  String? error,
  String? errorType,
  required bool hasResponse,
  Map<String, dynamic>? request,
  Map<String, dynamic>? response,
  bool slow = false,
  int? slowThresholdMs,
}) {
  final outcome = _outcome(statusCode, hasResponse, error);
  final path = _shortUrl(url);
  final duration = durationMs != null ? _fmtMs(durationMs) : null;

  final requestDetail = _partDetail(request, label: 'request');
  final responseDetail = hasResponse
      ? _responseDetail(statusCode, response)
      : _noResponseDetail(error, errorType);

  final slowSuffix = slow ? ' — slow' : '';
  final title = switch (outcome) {
    'success' => '$method $path succeeded (${statusCode ?? 'OK'})$slowSuffix',
    'http_error' => '$method $path failed with HTTP $statusCode$slowSuffix',
    'no_response' => '$method $path — no response${errorType != null ? ' ($errorType)' : ''}$slowSuffix',
    _ => '$method $path failed$slowSuffix',
  };

  final lines = <String>[
    'The app sent a $method request to $url.',
    if (requestDetail.isNotEmpty) 'Request: $requestDetail.',
    if (hasResponse)
      'Server responded with HTTP $statusCode${responseDetail.isNotEmpty ? ' — $responseDetail' : ''}.'
    else
      'No response was received${error != null ? ' — $error' : ''}.',
    if (duration != null) 'Completed in $duration.',
    if (slow && slowThresholdMs != null)
      'Exceeded the slow threshold of ${_fmtMs(slowThresholdMs)}.',
  ];

  return {
    'title': title,
    'outcome': outcome,
    'outcomeLabel': _outcomeLabel(outcome),
    if (slow) 'slow': true,
    if (slowThresholdMs != null) 'slowThresholdMs': slowThresholdMs,
    'lines': lines,
    'request': {
      'method': method,
      'url': url,
      'path': path,
      'summary': requestDetail.isEmpty ? '$method $path' : '$method $path · $requestDetail',
    },
    'response': {
      'hasResponse': hasResponse,
      if (statusCode != null) 'statusCode': statusCode,
      'summary': responseDetail,
      if (error != null) 'error': error,
      if (errorType != null) 'errorType': errorType,
    },
    if (duration != null) 'duration': duration,
  };
}

String _outcome(int? statusCode, bool hasResponse, String? error) {
  if (!hasResponse) return 'no_response';
  if (statusCode != null && statusCode >= 500) return 'http_error';
  if (statusCode != null && statusCode >= 400) return 'http_error';
  if (error != null) return 'failed';
  return 'success';
}

String _outcomeLabel(String outcome) => switch (outcome) {
      'success' => 'Success',
      'http_error' => 'HTTP error',
      'no_response' => 'No response',
      _ => 'Failed',
    };

String _shortUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final path = uri.path.isEmpty ? '/' : uri.path;
  return uri.hasQuery ? '$path?${uri.query}' : path;
}

String _fmtMs(int ms) {
  if (ms < 1000) return '${ms}ms';
  final sec = ms / 1000;
  return sec >= 10 ? '${sec.round()}s' : '${sec.toStringAsFixed(1)}s';
}

String _partDetail(Map<String, dynamic>? part, {required String label}) {
  if (part == null) return '';
  final headers = part['headers'];
  final headerCount = headers is Map ? headers.length : 0;
  final body = part['body'];
  final parts = <String>[
    if (part['query'] is Map && (part['query'] as Map).isNotEmpty) 'query params',
    if (body != null) _bodyKind(body),
    if (headerCount > 0) '$headerCount header${headerCount == 1 ? '' : 's'}',
  ];
  return parts.join(' · ');
}

String _bodyKind(dynamic body) {
  final text = body.toString().trim();
  if (text.startsWith('{') || text.startsWith('[')) return 'JSON body';
  if (text.startsWith('<')) return 'XML/HTML body';
  return 'body (${text.length} chars)';
}

String _responseDetail(int? statusCode, Map<String, dynamic>? response) {
  if (statusCode == null) return '';
  final label = _statusLabel(statusCode);
  final body = response?['body'];
  if (body == null) return label;
  final preview = _preview(body.toString(), 60);
  return '$label · $preview';
}

String _noResponseDetail(String? error, String? errorType) {
  if (errorType != null) return _humanErrorType(errorType);
  return error ?? 'Connection failed before a response arrived';
}

String _humanErrorType(String type) => switch (type) {
      'connectionTimeout' => 'Connection timed out',
      'sendTimeout' => 'Send timed out',
      'receiveTimeout' => 'Receive timed out',
      'connectionError' => 'Connection error',
      'badCertificate' => 'Bad SSL certificate',
      'cancel' => 'Request cancelled',
      'unknown' => 'Unknown network error',
      _ => type,
    };

String _statusLabel(int code) {
  if (code >= 500) return 'Server error';
  if (code == 404) return 'Not found';
  if (code == 401) return 'Unauthorized';
  if (code == 403) return 'Forbidden';
  if (code >= 400) return 'Client error';
  return 'OK';
}

String _preview(String text, int max) =>
    text.length <= max ? text : '${text.substring(0, max)}…';

String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";

String _encodeJson(dynamic data) {
  try {
    return jsonEncode(data);
  } catch (_) {
    return data.toString();
  }
}
