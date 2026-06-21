import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:devicelocale/devicelocale.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Collects device, app, and connectivity details for every event payload.
class DeviceCollector {
  Map<String, dynamic> _cached = {};

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
        deviceName = a.name.isNotEmpty ? a.name : '${a.manufacturer} ${a.model}'.trim();
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
      if (locale != null) ...locale,
      if (pkg != null) ...{
        'appVersion': pkg.version,
        'buildNumber': pkg.buildNumber,
        'packageName': pkg.packageName,
      },
    };
    return Map<String, dynamic>.from(_cached);
  }

  void patch(Map<String, dynamic> data) => _cached.addAll(data);

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
        'countryCode': locale.countryCode!.toUpperCase(),
    };
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
