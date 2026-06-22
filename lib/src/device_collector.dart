import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:devicelocale/devicelocale.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Collects device, app, and connectivity details for every event payload.
class DeviceCollector {
  Map<String, dynamic> _cached = {};
  final Battery _battery = Battery();
  bool _countryManual = false;

  static const _ipApiUrl = 'http://ip-api.com/json?fields=status,countryCode';

  Future<String?> _batteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (level < 0) return null;
      return (level / 100).toStringAsFixed(2);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> collect() async {
    if (_cached.isNotEmpty) return Map<String, dynamic>.from(_cached);

    final connectivity = await Connectivity().checkConnectivity();
    final online = !connectivity.contains(ConnectivityResult.none);
    final dispatcher = ui.PlatformDispatcher.instance;

    var platform = defaultTargetPlatform.name;
    var osVersion = kIsWeb ? 'web' : Platform.operatingSystemVersion;
    var manufacturer = 'unknown';
    var deviceModel = 'unknown';
    var deviceName = 'unknown';
    var deviceId = 'unknown';
    var isSimulator = kIsWeb;
    int? ramTotalMb;
    int? ramFreeMb;
    int? diskFreeMb;
    int? diskTotalMb;
    int? androidSdkInt;

    if (!kIsWeb) {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        platform = 'android';
        osVersion = a.version.release;
        manufacturer = a.manufacturer;
        deviceModel = a.model;
        deviceName = '${a.manufacturer} ${a.model}'.trim().isNotEmpty
            ? '${a.manufacturer} ${a.model}'.trim()
            : a.model;
        deviceId = a.id;
        isSimulator = !a.isPhysicalDevice;
        ramTotalMb = a.physicalRamSize;
        ramFreeMb = a.availableRamSize;
        diskFreeMb = a.freeDiskSize ~/ (1024 * 1024);
        diskTotalMb = a.totalDiskSize ~/ (1024 * 1024);
        androidSdkInt = a.version.sdkInt;
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        platform = 'ios';
        osVersion = i.systemVersion;
        manufacturer = 'Apple';
        deviceModel = i.modelName.isNotEmpty ? i.modelName : i.utsname.machine;
        deviceName = i.name.isNotEmpty ? i.name : deviceModel;
        deviceId = i.identifierForVendor ?? 'unknown';
        isSimulator = !i.isPhysicalDevice;
        ramTotalMb = i.physicalRamSize;
        ramFreeMb = i.availableRamSize;
        diskFreeMb = i.freeDiskSize ~/ (1024 * 1024);
        diskTotalMb = i.totalDiskSize ~/ (1024 * 1024);
      } else if (Platform.isMacOS) {
        final m = await info.macOsInfo;
        platform = 'macos';
        osVersion = '${m.majorVersion}.${m.minorVersion}.${m.patchVersion}';
        manufacturer = 'Apple';
        deviceModel = m.modelName.isNotEmpty ? m.modelName : m.model;
        deviceName = m.computerName.isNotEmpty ? m.computerName : deviceModel;
        deviceId = m.systemGUID ?? 'unknown';
      }
    }

    PackageInfo? pkg;
    try {
      pkg = await PackageInfo.fromPlatform();
    } catch (_) {}

    final locale = await _deviceLocale();
    final batteryLevel = await _batteryLevel();
    final now = DateTime.now();

    _cached = {
      'platform': platform,
      'version': osVersion,
      'osVersion': osVersion,
      'deviceName': deviceName,
      'manufacturer': manufacturer,
      'deviceModel': deviceModel,
      'deviceId': deviceId,
      'isSimulator': isSimulator,
      if (ramTotalMb != null) 'ramTotalMb': ramTotalMb,
      if (ramFreeMb != null) 'ramFreeMb': ramFreeMb,
      if (diskFreeMb != null) 'diskFreeMb': diskFreeMb,
      if (diskTotalMb != null) 'diskTotalMb': diskTotalMb,
      if (androidSdkInt != null) 'androidSdkInt': androidSdkInt,
      'darkMode': dispatcher.platformBrightness == ui.Brightness.dark,
      'textScaleFactor': dispatcher.textScaleFactor,
      'timezone': now.timeZoneName,
      'timezoneOffsetMin': now.timeZoneOffset.inMinutes,
      'isOnline': online,
      'connectivity': connectivity.map((c) => c.name).toList(),
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
      if (locale != null) ...locale,
      if (pkg != null) ...{
        'appVersion': pkg.version,
        'buildNumber': pkg.buildNumber,
        'packageName': pkg.packageName,
      },
    };
    return Map<String, dynamic>.from(_cached);
  }

  Map<String, dynamic> current() => Map<String, dynamic>.from(_cached);

  /// Sets [device.country] from ip-api.com, else device locale. No location permission.
  Future<void> refreshCountry() async {
    if (_countryManual) return;
    final fromIp = await _countryFromIpApi();
    if (fromIp != null) {
      _cached['country'] = fromIp;
      return;
    }
    final locale = _cached['localeCountry']?.toString();
    if (locale != null && locale.isNotEmpty) _cached['country'] = locale.toUpperCase();
  }

  void patch(Map<String, dynamic> data, {bool lockCountry = false}) {
    if (lockCountry && data.containsKey('country')) _countryManual = true;
    _cached.addAll(data);
  }

  Future<void> refreshBattery() async {
    final level = await _batteryLevel();
    if (level != null) _cached['batteryLevel'] = level;
  }

  static Future<Map<String, String>> _deviceLocale() async {
    ui.Locale locale = ui.PlatformDispatcher.instance.locale;
    if (!kIsWeb) {
      try {
        locale = await Devicelocale.currentAsLocale ?? locale;
      } catch (_) {}
    }
    return {
      'locale': locale.toLanguageTag(),
      'languageCode': locale.languageCode,
      if (locale.countryCode != null && locale.countryCode!.isNotEmpty)
        'localeCountry': locale.countryCode!.toUpperCase(),
    };
  }

  Future<String?> _countryFromIpApi() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client.getUrl(Uri.parse(_ipApiUrl));
      final res = await req.close().timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      if (j['status'] != 'success') return null;
      final code = j['countryCode']?.toString().trim();
      return code == null || code.isEmpty ? null : code.toUpperCase();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

Future<Map<String, dynamic>> collectRelease({String? environment}) async {
  try {
    final pkg = await PackageInfo.fromPlatform();
    final name = '${pkg.packageName}@${pkg.version}+${pkg.buildNumber}';
    return {
      'name': name,
      'version': pkg.version,
      'buildNumber': pkg.buildNumber,
      'bundleId': pkg.packageName,
      if (environment != null) 'environment': environment,
    };
  } catch (_) {
    return {if (environment != null) 'environment': environment};
  }
}
