import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persists the active session so we can close it after crash, force-quit, or hot restart.
abstract final class SessionStore {
  static const _fileName = 'scout_active_session.json';

  static Future<Map<String, dynamic>?> readActive() async {
    if (kIsWeb) return null;
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      if (map['sessionId'] == null || map['startedAt'] == null) return null;
      return map;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeActive({required String sessionId, required String startedAt}) async {
    if (kIsWeb) return;
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode({'sessionId': sessionId, 'startedAt': startedAt}));
    } catch (_) {}
  }

  static Future<void> clear() async {
    if (kIsWeb) return;
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }
}
