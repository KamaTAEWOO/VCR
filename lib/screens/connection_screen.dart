import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/saved_server.dart';
import '../providers/connection_provider.dart';
import '../services/discovery_service.dart';
import '../services/server_storage_service.dart';
import '../services/websocket_service.dart';
import '../widgets/server_list_tile.dart';

/// Initial screen: mDNS server discovery + manual IP:Port connection.
///
/// Matches UI_SPEC.md section 3.1 wireframe and widget tree.
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _ipController =
      TextEditingController(text: 'kamataewoo.duckdns.org');
  final TextEditingController _portController =
      TextEditingController(text: '9000');
  DiscoveryService? _discoveryService;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    // Start mDNS discovery after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDiscovery();
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _discoveryService?.dispose();
    super.dispose();
  }

  void _startDiscovery() {
    final connProvider = context.read<ConnectionProvider>();
    _discoveryService = DiscoveryService(connectionProvider: connProvider);
    _discoveryService!.startDiscovery();
  }

  Future<void> _connectToServer(String host, int port, {String? serverName}) async {
    if (_isConnecting) return;

    setState(() => _isConnecting = true);

    try {
      final wsService = context.read<WebSocketService>();
      await wsService.connect(host, port);

      // Discovery no longer needed.
      _discoveryService?.stopDiscovery();

      // Save the server to history on successful connection
      if (mounted) {
        await _saveServerToHistory(host, port, serverName);
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/terminal');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is String ? e : 'Connection failed: $e'),
            backgroundColor: VcrColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _saveServerToHistory(String host, int port, String? serverName) async {
    final storageService = context.read<ServerStorageService>();
    final connProvider = context.read<ConnectionProvider>();

    final server = SavedServer(
      id: '${host}_${port}_${DateTime.now().millisecondsSinceEpoch}',
      name: serverName ?? '$host:$port',
      host: host,
      port: port,
      lastConnected: DateTime.now(),
    );

    final updatedServers = await storageService.addOrUpdateServer(
      connProvider.savedServers,
      server,
    );
    connProvider.setSavedServers(updatedServers);
  }

  Future<void> _toggleServerFavorite(String serverId) async {
    final storageService = context.read<ServerStorageService>();
    final connProvider = context.read<ConnectionProvider>();

    final updatedServers = await storageService.toggleFavorite(
      connProvider.savedServers,
      serverId,
    );
    connProvider.setSavedServers(updatedServers);
  }

  Future<void> _deleteServer(String serverId) async {
    final storageService = context.read<ServerStorageService>();
    final connProvider = context.read<ConnectionProvider>();

    final updatedServers = await storageService.removeServer(
      connProvider.savedServers,
      serverId,
    );
    connProvider.setSavedServers(updatedServers);
  }

  void _connectManually() {
    final ip = _ipController.text.trim();
    final portStr = _portController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an IP address.'),
          backgroundColor: VcrColors.warning,
        ),
      );
      return;
    }
    final port = int.tryParse(portStr) ?? NetworkConstants.defaultPort;
    _connectToServer(ip, port);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Spacing.xxl),
                const _VcrLogo(),
                const SizedBox(height: Spacing.xl),
                _buildSavedServersSection(),
                const SizedBox(height: Spacing.lg),
                _buildServerDiscoverySection(),
                const SizedBox(height: Spacing.lg),
                _buildManualConnectDivider(),
                const SizedBox(height: Spacing.lg),
                _buildManualConnectForm(),
                const SizedBox(height: Spacing.md),
                _buildConnectButton(),
                const SizedBox(height: Spacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Saved Servers Section --

  Widget _buildSavedServersSection() {
    return Consumer<ConnectionProvider>(
      builder: (context, connProvider, _) {
        final servers = connProvider.savedServers;

        if (servers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved Servers', style: VcrTypography.titleLarge),
            const SizedBox(height: Spacing.sm),
            ...servers.map((server) => Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sm),
                  child: _SavedServerTile(
                    server: server,
                    onTap: () => _connectToServer(
                      server.host,
                      server.port,
                      serverName: server.name,
                    ),
                    onFavoriteToggle: () => _toggleServerFavorite(server.id),
                    onDelete: () => _deleteServer(server.id),
                  ),
                )),
          ],
        );
      },
    );
  }

  // -- Server Discovery Section --

  Widget _buildServerDiscoverySection() {
    return Consumer<ConnectionProvider>(
      builder: (context, connProvider, _) {
        final servers = connProvider.discoveredServers;
        final isSearching = connProvider.isSearching;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discovered Servers', style: VcrTypography.titleLarge),
            const SizedBox(height: Spacing.sm),
            if (servers.isNotEmpty)
              ...servers.map((server) => Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: ServerListTile(
                      name: server.name,
                      host: server.host,
                      port: server.port,
                      onTap: () => _connectToServer(
                        server.host,
                        server.port,
                        serverName: server.name,
                      ),
                    ),
                  )),
            if (isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: VcrColors.accent,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      'Searching...',
                      style: VcrTypography.bodyMedium.copyWith(
                        color: VcrColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            if (!isSearching && servers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                child: Text(
                  'No servers found. Try manual connection.',
                  style: VcrTypography.bodyMedium.copyWith(
                    color: VcrColors.textSecondary,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // -- Manual Connect Divider --

  Widget _buildManualConnectDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: VcrColors.textMuted)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          child: Text(
            'OR CONNECT MANUALLY',
            style: VcrTypography.labelMedium.copyWith(
              color: VcrColors.textMuted,
            ),
          ),
        ),
        const Expanded(child: Divider(color: VcrColors.textMuted)),
      ],
    );
  }

  // -- Manual Connect Form --

  Widget _buildManualConnectForm() {
    return Column(
      children: [
        TextField(
          controller: _ipController,
          style: VcrTypography.bodyLarge,
          decoration: const InputDecoration(
            labelText: 'IP Address',
            hintText: '192.168.0.100 or mydomain.duckdns.org',
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: Spacing.sm),
        TextField(
          controller: _portController,
          style: VcrTypography.bodyLarge,
          decoration: const InputDecoration(
            labelText: 'Port',
            hintText: '8765',
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  // -- Connect Button --

  Widget _buildConnectButton() {
    return ElevatedButton(
      onPressed: _isConnecting ? null : _connectManually,
      child: _isConnecting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VcrColors.bgPrimary,
              ),
            )
          : const Text('CONNECT'),
    );
  }
}

// =============================================================================
// Saved Server Tile (internal widget)
// =============================================================================

class _SavedServerTile extends StatelessWidget {
  final SavedServer server;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDelete;

  const _SavedServerTile({
    required this.server,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VcrColors.bgSecondary,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          child: Row(
            children: [
              // Favorite star button
              IconButton(
                icon: Icon(
                  server.isFavorite ? Icons.star : Icons.star_border,
                  color: server.isFavorite
                      ? VcrColors.warning
                      : VcrColors.textMuted,
                  size: 20,
                ),
                onPressed: onFavoriteToggle,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              // Server info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: VcrTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${server.host}:${server.port}',
                      style: VcrTypography.bodyMedium.copyWith(
                        color: VcrColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: VcrColors.textMuted,
                  size: 18,
                ),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// VCR Logo (internal widget)
// =============================================================================

class _VcrLogo extends StatelessWidget {
  const _VcrLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'VCR',
                style: VcrTypography.headlineLarge.copyWith(
                  color: VcrColors.accent,
                  fontSize: 40,
                ),
              ),
              TextSpan(
                text: ' \u25B6', // play triangle
                style: VcrTypography.headlineLarge.copyWith(
                  color: VcrColors.accent,
                  fontSize: 32,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          'Vibe Code Runner',
          textAlign: TextAlign.center,
          style: VcrTypography.headlineMedium.copyWith(
            color: VcrColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
