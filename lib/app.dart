import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'providers/connection_provider.dart';
import 'providers/preview_provider.dart';
import 'providers/terminal_provider.dart';
import 'screens/connection_screen.dart';
import 'screens/terminal_screen.dart';
import 'services/websocket_service.dart';

/// Root widget that wires up providers, services, routing, and theme.
///
/// - MultiProvider registers 3 ChangeNotifiers + WebSocketService.
/// - Routes: / -> Connection, /terminal -> Terminal.
/// - Listens for disconnection to navigate back to Connection screen.
class VcrApp extends StatefulWidget {
  const VcrApp({super.key});

  @override
  State<VcrApp> createState() => _VcrAppState();
}

class _VcrAppState extends State<VcrApp> {
  late final ConnectionProvider _connectionProvider;
  late final TerminalProvider _terminalProvider;
  late final PreviewProvider _previewProvider;
  late final WebSocketService _webSocketService;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// Track previous connection state to detect transitions.
  VcrConnectionState _previousConnectionState = VcrConnectionState.disconnected;

  @override
  void initState() {
    super.initState();

    _connectionProvider = ConnectionProvider();
    _terminalProvider = TerminalProvider();
    _previewProvider = PreviewProvider();

    _webSocketService = WebSocketService(
      connectionProvider: _connectionProvider,
      terminalProvider: _terminalProvider,
      previewProvider: _previewProvider,
    );

    // Listen for disconnect -> navigate back to connection screen.
    _connectionProvider.addListener(_onConnectionChanged);
  }

  void _onConnectionChanged() {
    final state = _connectionProvider.state;

    // Only navigate when state transitions TO disconnected
    // (not on every notifyListeners while already disconnected).
    if (state == VcrConnectionState.disconnected &&
        _previousConnectionState != VcrConnectionState.disconnected) {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }

    _previousConnectionState = state;
  }

  @override
  void dispose() {
    _connectionProvider.removeListener(_onConnectionChanged);
    _webSocketService.dispose();
    _connectionProvider.dispose();
    _terminalProvider.dispose();
    _previewProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionProvider>.value(
          value: _connectionProvider,
        ),
        ChangeNotifierProvider<TerminalProvider>.value(
          value: _terminalProvider,
        ),
        ChangeNotifierProvider<PreviewProvider>.value(
          value: _previewProvider,
        ),
        Provider<WebSocketService>.value(
          value: _webSocketService,
        ),
      ],
      child: MaterialApp(
        title: 'VCR',
        debugShowCheckedModeBanner: false,
        theme: vcrDarkTheme,
        navigatorKey: _navigatorKey,
        initialRoute: '/',
        routes: {
          '/': (context) => const ConnectionScreen(),
          '/terminal': (context) => const TerminalScreen(),
        },
      ),
    );
  }
}
