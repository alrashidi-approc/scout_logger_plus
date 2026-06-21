/// Session breadcrumb trail — navigation, logs, and network steps before an event.
class BreadcrumbBuffer {
  BreadcrumbBuffer({this.maxEntries = 50});

  final int maxEntries;
  final List<Map<String, dynamic>> _entries = [];

  void add({
    required String type,
    String? route,
    String? message,
    String? level,
    Map<String, dynamic>? data,
  }) {
    final at = DateTime.now().toUtc().toIso8601String();
    final label = message ?? route ?? type;
    _entries.add({
      'type': type,
      'route': route,
      'name': label,
      'label': label,
      if (message != null) 'message': message,
      if (level != null) 'level': level,
      'timestamp': at,
      'at': at,
      if (data != null) ...data,
    });
    if (_entries.length > maxEntries) _entries.removeAt(0);
  }

  List<Map<String, dynamic>> toJson() => List<Map<String, dynamic>>.from(_entries);
}
