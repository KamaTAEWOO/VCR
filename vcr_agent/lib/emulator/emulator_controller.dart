import 'dart:io';

/// Controls emulator-related operations.
///
/// Checks for ADB availability and emulator running state.
class EmulatorController {
  /// Cached ADB path
  String? _adbPath;

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

  /// Check if any Android emulator is running.
  ///
  /// Runs `adb devices` and looks for an "emulator-" device.
  /// Returns the device name if found, null otherwise.
  Future<String?> getRunningEmulator() async {
    final adb = await getAdbPath();
    if (adb == null) return null;

    try {
      final result = await Process.run(adb, ['devices']);
      if (result.exitCode != 0) return null;

      final output = result.stdout as String;
      final lines = output.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        // Look for emulator devices like "emulator-5554  device"
        if (trimmed.startsWith('emulator-') && trimmed.contains('device')) {
          final parts = trimmed.split(RegExp(r'\s+'));
          if (parts.isNotEmpty) {
            return parts[0]; // e.g., "emulator-5554"
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if an emulator is currently running.
  Future<bool> isEmulatorRunning() async {
    final emulator = await getRunningEmulator();
    return emulator != null;
  }

  /// Get emulator screen resolution.
  ///
  /// Runs `adb shell wm size` to determine the emulator screen dimensions.
  /// Returns (width, height) or null if unable to determine.
  Future<({int width, int height})?> getScreenSize() async {
    final adb = await getAdbPath();
    if (adb == null) return null;

    try {
      final result = await Process.run(
        adb,
        ['shell', 'wm', 'size'],
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
