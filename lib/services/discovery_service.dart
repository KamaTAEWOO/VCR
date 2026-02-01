import 'dart:async';

import 'package:nsd/nsd.dart' as nsd;

import '../core/constants.dart';
import '../providers/connection_provider.dart';

/// mDNS discovery service for finding VCR Agents on the local network.
///
/// Uses the nsd package to browse for `_vcr._tcp` services.
/// Falls back gracefully -- if discovery fails, the user can always
/// connect manually via IP:Port input.
class DiscoveryService {
  final ConnectionProvider connectionProvider;

  nsd.Discovery? _discovery;
  Timer? _timeoutTimer;
  bool _disposed = false;

  DiscoveryService({required this.connectionProvider});

  /// Start scanning for VCR Agent services on the local network.
  /// Automatically stops after [NetworkConstants.mdnsTimeout].
  Future<void> startDiscovery() async {
    connectionProvider.clearDiscoveredServers();
    connectionProvider.setSearching(true);

    try {
      _discovery = await nsd.startDiscovery(
        NetworkConstants.mdnsServiceType,
        autoResolve: true,
      );

      _discovery!.addServiceListener((service, status) {
        if (status == nsd.ServiceStatus.found) {
          _onServiceFound(service);
        }
      });

      // Set a timeout to stop searching after the configured duration.
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(NetworkConstants.mdnsTimeout, () {
        stopDiscovery();
      });
    } catch (_) {
      connectionProvider.setSearching(false);
    }
  }

  void _onServiceFound(nsd.Service service) {
    final host = service.host;
    final port = service.port;
    final name = service.name ?? 'VCR Agent';

    if (host == null || port == null) return;

    connectionProvider.addDiscoveredServer(DiscoveredServer(
      name: name,
      host: host,
      port: port,
    ));
  }

  /// Stop the discovery process.
  Future<void> stopDiscovery() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    try {
      if (_discovery != null) {
        await nsd.stopDiscovery(_discovery!);
        _discovery = null;
      }
    } catch (_) {
      // Ignore close errors.
    }

    if (!_disposed) {
      connectionProvider.setSearching(false);
    }
  }

  /// Dispose all resources.
  void dispose() {
    _disposed = true;
    _timeoutTimer?.cancel();
    stopDiscovery();
  }
}
