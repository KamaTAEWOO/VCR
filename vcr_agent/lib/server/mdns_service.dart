// TODO: mDNS service registration for VCR Agent
//
// The `nsd` package requires Flutter framework and cannot be used in a pure
// Dart CLI application. For mDNS service registration in a non-Flutter context,
// we would need one of the following approaches:
//
// 1. Use `multicast_dns` package from Dart team (for discovery only, not registration)
// 2. Use native platform tools:
//    - macOS: `dns-sd -R "VCR Agent" _vcr._tcp local 8765`
//    - Linux: `avahi-publish-service "VCR Agent" _vcr._tcp 8765`
//    - Windows: Would need Bonjour SDK
// 3. Implement a simple UDP multicast responder manually
//
// For MVP, the VCR App supports manual IP:Port entry as a fallback,
// so mDNS is not strictly required. Users can connect via:
//   ws://<notebook-ip>:8765
//
// Implementation plan:
// - Register service type: _vcr._tcp
// - Port: 8765 (configurable)
// - TXT record: version=0.1.0

import 'dart:io';

/// mDNS service registration for VCR Agent discovery.
///
/// NOTE: Currently uses platform-native commands as a fallback since the
/// `nsd` package requires Flutter. This works on macOS and Linux.
/// On unsupported platforms, this gracefully degrades (no-op).
class MdnsService {
  /// The platform process running dns-sd or avahi
  Process? _process;

  /// Service name
  final String serviceName;

  /// Service port
  final int port;

  /// Whether the service is currently registered
  bool get isRegistered => _process != null;

  MdnsService({
    this.serviceName = 'VCR Agent',
    this.port = 9000,
  });

  /// Register the mDNS service.
  ///
  /// Uses platform-native tools:
  /// - macOS: `dns-sd`
  /// - Linux: `avahi-publish-service`
  ///
  /// Returns true if registration was successful, false otherwise.
  /// Does NOT throw on failure - mDNS is optional for MVP.
  Future<bool> register() async {
    try {
      if (Platform.isMacOS) {
        return await _registerMacOS();
      } else if (Platform.isLinux) {
        return await _registerLinux();
      } else {
        _log('mDNS registration not supported on ${Platform.operatingSystem}');
        return false;
      }
    } catch (e) {
      _log('Failed to register mDNS service: $e');
      return false;
    }
  }

  /// Register using macOS dns-sd command.
  Future<bool> _registerMacOS() async {
    try {
      _process = await Process.start(
        'dns-sd',
        [
          '-R',
          serviceName,
          '_vcr._tcp',
          'local',
          port.toString(),
          'version=0.1.0',
        ],
      );

      // Check if process starts successfully (wait briefly)
      final exitFuture = _process!.exitCode;
      final result = await Future.any([
        exitFuture,
        Future.delayed(const Duration(seconds: 1), () => -1),
      ]);

      if (result != -1) {
        // Process exited immediately - registration failed
        _process = null;
        _log('dns-sd registration failed');
        return false;
      }

      _log('mDNS service registered via dns-sd: $serviceName on port $port');
      return true;
    } catch (e) {
      _log('dns-sd not available: $e');
      return false;
    }
  }

  /// Register using Linux avahi-publish-service command.
  Future<bool> _registerLinux() async {
    try {
      _process = await Process.start(
        'avahi-publish-service',
        [
          serviceName,
          '_vcr._tcp',
          port.toString(),
          'version=0.1.0',
        ],
      );

      // Check if process starts successfully
      final exitFuture = _process!.exitCode;
      final result = await Future.any([
        exitFuture,
        Future.delayed(const Duration(seconds: 1), () => -1),
      ]);

      if (result != -1) {
        _process = null;
        _log('avahi-publish-service registration failed');
        return false;
      }

      _log(
          'mDNS service registered via avahi: $serviceName on port $port');
      return true;
    } catch (e) {
      _log('avahi-publish-service not available: $e');
      return false;
    }
  }

  /// Unregister the mDNS service.
  Future<void> unregister() async {
    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
      _process = null;
      _log('mDNS service unregistered');
    }
  }

  /// Dispose all resources.
  Future<void> dispose() async {
    await unregister();
  }

  void _log(String message) {
    final timestamp =
        DateTime.now().toIso8601String().substring(11, 19);
    print('[$timestamp] [mDNS] $message');
  }
}
