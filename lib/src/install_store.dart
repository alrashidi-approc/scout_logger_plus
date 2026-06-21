import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Persistent install + anonymous identity for analytics without login.
abstract final class InstallStore {
  static const _fileName = 'scout_install.json';

  static Future<Map<String, dynamic>> loadOrCreate() async {
    if (kIsWeb) return _fresh();
    try {
      final file = await _file();
      Map<String, dynamic> data;
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        data = raw is Map ? Map<String, dynamic>.from(raw) : _fresh();
      } else {
        data = _fresh();
      }
      data['launchCount'] = (data['launchCount'] as int? ?? 0) + 1;
      data['daysSinceInstall'] = _daysSince(data['firstOpenAt'] as String?);
      await file.writeAsString(jsonEncode(data));
      return data;
    } catch (_) {
      return _fresh(launchCount: 1);
    }
  }

  static Map<String, dynamic> _fresh({int launchCount = 1}) {
    final now = DateTime.now().toUtc();
    final id = const Uuid().v4();
    return {
      'installId': id,
      'anonymousId': id,
      'firstOpenAt': now.toIso8601String(),
      'launchCount': launchCount,
      'daysSinceInstall': 0,
    };
  }

  static int _daysSince(String? iso) {
    final start = DateTime.tryParse(iso ?? '');
    if (start == null) return 0;
    return DateTime.now().toUtc().difference(start.toUtc()).inDays;
  }

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }
}
