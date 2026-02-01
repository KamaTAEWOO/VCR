import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:vcr_shared/vcr_shared.dart';

/// Callback type for incoming commands
typedef CommandCallback = Future<VcrResponse> Function(
    VcrCommand command, String clientId);

/// WebSocket server for VCR Agent.
///
/// Based on shelf + shelf_web_socket.
/// Manages multiple client connections and provides:
/// - Welcome message on connect
/// - JSON message receiving/parsing/routing
/// - Response/status/frame message sending
/// - Client lifecycle management with broadcast support
class WebSocketServer {
  /// The HTTP server instance
  HttpServer? _server;

  /// Connected clients: clientId -> WebSocketChannel
  final Map<String, WebSocketChannel> _clients = {};

  /// Client stream subscriptions for cleanup
  final Map<String, StreamSubscription> _subscriptions = {};

  /// Counter for generating client IDs
  int _clientIdCounter = 0;

  /// Server port
  final int port;

  /// Callback for handling incoming commands
  CommandCallback? onCommand;

  /// Callback for when a client connects
  void Function(String clientId)? onClientConnected;

  /// Callback for when a client disconnects
  void Function(String clientId)? onClientDisconnected;

  /// Callback for shell input from clients
  void Function(String input, String clientId)? onShellInput;

  /// Callback for shell resize from clients
  void Function(int columns, int rows, String clientId)? onShellResize;

  /// Provider of welcome data for new connections
  WelcomeData Function()? welcomeDataProvider;

  /// Whether the server is running
  bool get isRunning => _server != null;

  /// Number of connected clients
  int get clientCount => _clients.length;

  /// List of connected client IDs
  List<String> get clientIds => _clients.keys.toList();

  WebSocketServer({this.port = ConnectionDefaults.port});

  /// Start the WebSocket server.
  Future<void> start() async {
    if (_server != null) {
      throw StateError('Server is already running');
    }

    final wsHandler = webSocketHandler(_handleWebSocket);

    // Route: /ws -> WebSocket upgrade; everything else -> 404.
    // Also accept root path / for compatibility with simple clients.
    FutureOr<shelf.Response> router(shelf.Request request) {
      final path = request.url.path;
      if (path == 'ws' || path.isEmpty) {
        return wsHandler(request);
      }
      return shelf.Response.notFound('Not found. Use ws://host:$port/ws');
    }

    final pipeline = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(router);

    _server = await shelf_io.serve(pipeline, InternetAddress.anyIPv4, port);
    _server!.autoCompress = true;

    _log('WebSocket server started on ws://0.0.0.0:$port/ws');
    _log('Local IP addresses:');
    for (final addr in await _getLocalAddresses()) {
      _log('  ws://$addr:$port/ws');
    }
  }

  /// Handle a new WebSocket connection.
  void _handleWebSocket(WebSocketChannel webSocket, String? subprotocol) {
    final clientId = 'client_${++_clientIdCounter}';
    _clients[clientId] = webSocket;

    _log('Client connected: $clientId (total: ${_clients.length})');

    // Send welcome message
    _sendWelcome(clientId);

    // Notify listener
    onClientConnected?.call(clientId);

    // Listen for incoming messages
    final subscription = webSocket.stream.listen(
      (data) => _handleMessage(clientId, data),
      onError: (error) {
        _log('Client $clientId error: $error');
        _removeClient(clientId);
      },
      onDone: () {
        _log('Client $clientId disconnected');
        _removeClient(clientId);
      },
    );

    _subscriptions[clientId] = subscription;
  }

  /// Handle an incoming message from a client.
  void _handleMessage(String clientId, dynamic data) {
    if (data is! String) {
      _log('Ignoring non-text message from $clientId');
      return;
    }

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final message = VcrMessage.fromJson(json);

      switch (message.type) {
        case MessageType.command:
          _handleCommand(clientId, message);
          break;

        case MessageType.ping:
          _handlePing(clientId);
          break;

        case MessageType.shellInput:
          final shellData = ShellInputData.fromMessage(message);
          onShellInput?.call(shellData.input, clientId);
          break;

        case MessageType.shellResize:
          final resizeData = ShellResizeData.fromMessage(message);
          onShellResize?.call(resizeData.columns, resizeData.rows, clientId);
          break;

        default:
          _log('Unknown message type from $clientId: ${message.type}');
      }
    } catch (e) {
      _log('Failed to parse message from $clientId: $e');
      // Send error response
      sendToClient(
        clientId,
        VcrResponse.error(
          message: 'Invalid message format: $e',
          errorCode: ErrorCode.parseError,
        ).toMessage(),
      );
    }
  }

  /// Handle a command message.
  Future<void> _handleCommand(String clientId, VcrMessage message) async {
    final command = VcrCommand.fromMessage(message);

    if (onCommand != null) {
      try {
        final response = await onCommand!(command, clientId);
        // Match response ID with command ID
        final responseWithId = VcrResponse(
          id: command.id,
          status: response.status,
          message: response.message,
          logs: response.logs,
          errorCode: response.errorCode,
        );
        sendToClient(clientId, responseWithId.toMessage());
      } catch (e) {
        sendToClient(
          clientId,
          VcrResponse.error(
            id: command.id,
            message: 'Internal error: $e',
            errorCode: ErrorCode.parseError,
          ).toMessage(),
        );
      }
    } else {
      sendToClient(
        clientId,
        VcrResponse.error(
          id: command.id,
          message: 'Command handler not registered',
          errorCode: ErrorCode.parseError,
        ).toMessage(),
      );
    }
  }

  /// Handle a ping message by sending pong.
  void _handlePing(String clientId) {
    sendToClient(
      clientId,
      VcrMessage(type: MessageType.pong, payload: {}),
    );
  }

  /// Send a welcome message to a newly connected client.
  void _sendWelcome(String clientId) {
    final welcomeData = welcomeDataProvider?.call() ??
        WelcomeData(
          agentVersion: ConnectionDefaults.agentVersion,
          flutterVersion: 'unknown',
          commands: VcrCommands.availableCommands,
        );

    sendToClient(clientId, welcomeData.toMessage());
  }

  /// Send a message to a specific client.
  void sendToClient(String clientId, VcrMessage message) {
    final channel = _clients[clientId];
    if (channel != null) {
      try {
        channel.sink.add(jsonEncode(message.toJson()));
      } catch (e) {
        _log('Failed to send to $clientId: $e');
        _removeClient(clientId);
      }
    }
  }

  /// Broadcast a message to all connected clients.
  void broadcast(VcrMessage message) {
    final data = jsonEncode(message.toJson());
    final disconnected = <String>[];

    for (final entry in _clients.entries) {
      try {
        entry.value.sink.add(data);
      } catch (e) {
        _log('Failed to broadcast to ${entry.key}: $e');
        disconnected.add(entry.key);
      }
    }

    // Clean up disconnected clients
    for (final clientId in disconnected) {
      _removeClient(clientId);
    }
  }

  /// Broadcast a status update to all clients.
  void broadcastStatus(AgentState state, {String? message}) {
    broadcast(
      StatusData(state: state, message: message).toMessage(),
    );
  }

  /// Broadcast a frame to all clients.
  void broadcastFrame(FrameData frame) {
    broadcast(frame.toMessage());
  }

  /// Remove a client and clean up resources.
  void _removeClient(String clientId) {
    _subscriptions[clientId]?.cancel();
    _subscriptions.remove(clientId);

    final channel = _clients.remove(clientId);
    try {
      channel?.sink.close();
    } catch (_) {
      // Ignore close errors
    }

    onClientDisconnected?.call(clientId);
    _log('Client removed: $clientId (total: ${_clients.length})');
  }

  /// Get local network addresses.
  Future<List<String>> _getLocalAddresses() async {
    final addresses = <String>[];
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface_ in interfaces) {
        for (final addr in interface_.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback) {
            addresses.add(addr.address);
          }
        }
      }
    } catch (_) {
      // Ignore errors
    }
    return addresses;
  }

  /// Stop the server and disconnect all clients.
  Future<void> stop() async {
    _log('Stopping WebSocket server...');

    // Close all client connections
    for (final clientId in _clients.keys.toList()) {
      _removeClient(clientId);
    }

    // Close the HTTP server
    await _server?.close(force: true);
    _server = null;

    _log('WebSocket server stopped');
  }

  /// Log helper
  void _log(String message) {
    final timestamp =
        DateTime.now().toIso8601String().substring(11, 19);
    print('[$timestamp] [WS] $message');
  }
}
