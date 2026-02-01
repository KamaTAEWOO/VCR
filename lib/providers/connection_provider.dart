import 'package:flutter/foundation.dart';

/// WebSocket connection states.
enum VcrConnectionState {
  disconnected,
  connecting,
  connected,
}

/// Discovered server info from mDNS.
class DiscoveredServer {
  final String name;
  final String host;
  final int port;

  const DiscoveredServer({
    required this.name,
    required this.host,
    required this.port,
  });
}

/// Manages WebSocket connection state, server discovery results,
/// and reconnection logic.
class ConnectionProvider extends ChangeNotifier {
  VcrConnectionState _state = VcrConnectionState.disconnected;
  String? _host;
  int? _port;
  String? _projectName;
  String? _agentVersion;
  List<String> _availableCommands = [];

  List<DiscoveredServer> _discoveredServers = [];
  bool _isSearching = false;

  int _reconnectAttempts = 0;

  // -- Getters --

  VcrConnectionState get state => _state;
  String? get host => _host;
  int? get port => _port;
  String? get projectName => _projectName;
  String? get agentVersion => _agentVersion;
  List<String> get availableCommands => _availableCommands;

  List<DiscoveredServer> get discoveredServers =>
      List.unmodifiable(_discoveredServers);
  bool get isSearching => _isSearching;

  int get reconnectAttempts => _reconnectAttempts;
  bool get isConnected => _state == VcrConnectionState.connected;

  // -- Setters / Mutations --

  void setConnecting(String host, int port) {
    _state = VcrConnectionState.connecting;
    _host = host;
    _port = port;
    notifyListeners();
  }

  void setConnected({
    String? projectName,
    String? agentVersion,
    List<String>? commands,
  }) {
    _state = VcrConnectionState.connected;
    _reconnectAttempts = 0;
    if (projectName != null) _projectName = projectName;
    if (agentVersion != null) _agentVersion = agentVersion;
    if (commands != null) _availableCommands = commands;
    notifyListeners();
  }

  void setDisconnected() {
    _state = VcrConnectionState.disconnected;
    notifyListeners();
  }

  void incrementReconnectAttempts() {
    _reconnectAttempts++;
    notifyListeners();
  }

  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
  }

  void setProjectName(String? name) {
    _projectName = name;
    notifyListeners();
  }

  // -- mDNS Discovery --

  void setSearching(bool searching) {
    _isSearching = searching;
    notifyListeners();
  }

  void setDiscoveredServers(List<DiscoveredServer> servers) {
    _discoveredServers = servers;
    notifyListeners();
  }

  void addDiscoveredServer(DiscoveredServer server) {
    // Avoid duplicates by host:port
    final exists = _discoveredServers
        .any((s) => s.host == server.host && s.port == server.port);
    if (!exists) {
      _discoveredServers = [..._discoveredServers, server];
      notifyListeners();
    }
  }

  void clearDiscoveredServers() {
    _discoveredServers = [];
    notifyListeners();
  }
}
