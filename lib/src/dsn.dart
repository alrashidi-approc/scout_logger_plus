/// Parsed project DSN from the scout-logger dashboard.
class ScoutDsn {
  const ScoutDsn({
    required this.ingestKey,
    required this.baseUrl,
    required this.projectId,
  });

  final String ingestKey;
  final Uri baseUrl;
  final String projectId;
}

ScoutDsn parseDsn(String raw) {
  final uri = Uri.parse(raw.trim());
  final key = uri.userInfo;
  if (key.isEmpty || !key.startsWith('sk_live_')) {
    throw ArgumentError('DSN must look like https://sk_live_...@host:port/project_id');
  }
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) {
    throw ArgumentError('DSN must include /project_id');
  }
  if (!uri.hasPort) {
    throw ArgumentError(
      'DSN must include an explicit port — copy the full DSN from the dashboard (host:port/project_id)',
    );
  }
  return ScoutDsn(
    ingestKey: key,
    baseUrl: Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null),
    projectId: segments.first,
  );
}

/// Safe for logs — never includes the ingest key.
String describeDsn(ScoutDsn dsn) =>
    '${dsn.baseUrl.scheme}://${dsn.baseUrl.host}:${dsn.baseUrl.port}/${dsn.projectId}';
