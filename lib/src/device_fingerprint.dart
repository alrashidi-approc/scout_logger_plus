import 'dart:io';

import 'package:device_guard/device_guard.dart';
import 'package:flutter/foundation.dart';

/// Hardware-backed device id from [device_guard] — fingerprint only, no attestation.
Future<String?> resolveDeviceFingerprint() async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return null;
  try {
    final guard = DeviceGuard();
    final id = await guard.getPersistentId();
    if (_isValidFingerprint(id)) return id;
    final reg = await guard.getRegistrationData();
    if (_isValidFingerprint(reg.uuid)) return reg.uuid;
  } catch (_) {}
  return null;
}

bool _isValidFingerprint(String? id) =>
    id != null && id.isNotEmpty && !id.startsWith('Error:');
