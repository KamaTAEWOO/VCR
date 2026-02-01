import 'dart:io';

import 'package:vcr_shared/vcr_shared.dart';

/// Controls device detection for Android devices.
///
/// Replaces the old EmulatorController with multi-device support.
/// Detects physical Android devices and emulators.
class DeviceController {
  /// Cached ADB path
  String? _adbPath;

  // ---------------------------------------------------------------------------
  // ADB / Android
  // ---------------------------------------------------------------------------

  /// Check if ADB is available on the system.
  Future<bool> isAdbAvailable() async {
    try {
      final result = await Process.run('adb', ['version']);
      if (result.exitCode == 0) {
        _adbPath = 'adb';
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get the ADB path, checking common locations if not in PATH.
  Future<String?> getAdbPath() async {
    if (_adbPath != null) return _adbPath;

    // Try PATH first
    if (await isAdbAvailable()) return _adbPath;

    // Try common locations
    final commonPaths = [
      '${Platform.environment['HOME']}/Android/Sdk/platform-tools/adb',
      '${Platform.environment['HOME']}/Library/Android/sdk/platform-tools/adb',
      '/usr/local/bin/adb',
    ];

    for (final path in commonPaths) {
      if (File(path).existsSync()) {
        _adbPath = path;
        return _adbPath;
      }
    }

    return null;
  }

  /// Parse `adb devices -l` output to get connected Android devices.
  ///
  /// Returns a list of [DeviceInfo] for all connected Android devices,
  /// including both emulators and physical devices.
  Future<List<DeviceInfo>> _getAndroidDevices() async {
    final adb = await getAdbPath();
    if (adb == null) return [];

    try {
      final result = await Process.run(adb, ['devices', '-l']);
      if (result.exitCode != 0) return [];

      final output = result.stdout as String;
      final lines = output.split('\n');
      final devices = <DeviceInfo>[];

      for (final line in lines) {
        final trimmed = line.trim();
        // Skip header line and empty lines
        if (trimmed.isEmpty ||
            trimmed.startsWith('List of') ||
            !trimmed.contains('device')) {
          continue;
        }

        // Skip lines that say "offline" or "unauthorized"
        if (trimmed.contains('offline') || trimmed.contains('unauthorized')) {
          continue;
        }

        // Parse: <serial>  device <properties...>
        // Example: LMV500Ne6f3ea0c       device usb:336592896X product:mh2lm model:LM_V500N device:mh2lm transport_id:3
        // Example: emulator-5554          device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a transport_id:1
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length < 2 || parts[1] != 'device') continue;

        final serial = parts[0];

        // Extract model name from "model:" field
        String name = serial;
        for (final part in parts) {
          if (part.startsWith('model:')) {
            name = part.substring(6).replaceAll('_', ' ');
            break;
          }
        }

        devices.add(DeviceInfo(
          id: serial,
          name: name,
          platform: 'android',
        ));
      }

      return devices;
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Combined
  // ---------------------------------------------------------------------------

  /// Get all connected Android devices.
  ///
  /// Returns a list of [DeviceInfo] for connected Android devices.
  Future<List<DeviceInfo>> getConnectedDevices() async {
    return await _getAndroidDevices();
  }

  /// Check if any Android emulator is running (backward compat).
  ///
  /// Looks for devices with "emulator-" prefix.
  Future<String?> getRunningEmulator() async {
    final devices = await _getAndroidDevices();
    for (final device in devices) {
      if (device.id.startsWith('emulator-')) {
        return device.id;
      }
    }
    return null;
  }

  /// Check if an emulator is currently running (backward compat).
  Future<bool> isEmulatorRunning() async {
    final emulator = await getRunningEmulator();
    return emulator != null;
  }

  /// Get screen size for a specific Android device.
  ///
  /// Runs `adb -s <deviceId> shell wm size` to determine dimensions.
  Future<({int width, int height})?> getScreenSize(String deviceId) async {
    final adb = await getAdbPath();
    if (adb == null) return null;

    try {
      final result = await Process.run(
        adb,
        ['-s', deviceId, 'shell', 'wm', 'size'],
      );

      if (result.exitCode != 0) return null;

      final output = result.stdout as String;
      // Output format: "Physical size: 1080x1920"
      final match = RegExp(r'(\d+)x(\d+)').firstMatch(output);
      if (match != null) {
        return (
          width: int.parse(match.group(1)!),
          height: int.parse(match.group(2)!),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
