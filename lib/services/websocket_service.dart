import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:vcr_shared/models/foreground_process_data.dart';
import 'package:vcr_shared/models/shell_input_data.dart';
import 'package:vcr_shared/models/shell_output_data.dart';
import 'package:vcr_shared/models/shell_exit_data.dart';
import 'package:vcr_shared/models/shell_resize_data.dart';
import 'package:vcr_shared/models/vcr_message.dart' as shared;
import 'package:vcr_shared/protocol.dart';

import '../core/constants.dart';
import '../models/agent_state.dart';
import '../models/device_info.dart';
import '../models/frame_data.dart';
import '../models/terminal_entry.dart';
import '../models/vcr_message.dart';
import '../models/vcr_response.dart';
import '../providers/connection_provider.dart';
import '../providers/preview_provider.dart';
import '../providers/terminal_provider.dart';

/// WebSocket client service that connects to a VCR Agent,
/// routes incoming messages to the appropriate providers,
/// and handles keepalive + auto-reconnect.
class WebSocketService {
  final ConnectionProvider connectionProvider;
  final TerminalProvider terminalProvider;
  final PreviewProvider previewProvider;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _intentionalDisconnect = false;
  bool _isDisconnecting = false;

  WebSocketService({
    required this.connectionProvider,
    required this.terminalProvider,
    required this.previewProvider,
  });

  // =========================================================================
  // Public API
  // =========================================================================

  /// Connect to a VCR Agent at [host]:[port].
  ///
  /// Throws a user-friendly [String] on failure (caught by the UI layer).
  Future<void> connect(String host, int port) async {
    // Clean up any previous connection before starting a new one.
    _cleanup();

    _intentionalDisconnect = false;
    _isDisconnecting = false;
    connectionProvider.setConnecting(host, port);

    final uri = Uri.parse('ws://$host:$port/ws');
    debugPrint('[WS] Connecting to $uri ...');

    try {
      _channel = WebSocketChannel.connect(uri);

      // Wait for the connection with a timeout to avoid hanging forever
      // when the server is unreachable (e.g. wrong IP, firewall).
      await _channel!.ready.timeout(
        NetworkConstants.connectTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Connection timed out after ${NetworkConstants.connectTimeout.inSeconds}s',
          );
        },
      );

      debugPrint('[WS] Connected to $uri');

      // Start listening for incoming messages.
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // Start ping keepalive timer.
      _startPingTimer();
    } catch (e) {
      debugPrint('[WS] Connection failed: $e');
      _cleanup();
      connectionProvider.setDisconnected();
      throw _formatConnectionError(e);
    }
  }

  /// Convert raw exceptions into user-friendly error messages.
  ///
  /// Note: WebSocketChannel wraps SocketExceptions inside
  /// WebSocketChannelException, so we check the message string
  /// on both exception types.
  String _formatConnectionError(Object error) {
    if (error is TimeoutException) {
      return 'Connection timed out. Check the IP address and ensure the Agent is running.';
    }

    // Extract the message string regardless of wrapper type.
    final errorStr = error.toString();

    if (errorStr.contains('Connection refused')) {
      return 'Connection refused.\n'
          '• Is the VCR Agent running? (dart run bin/vcr_agent.dart)\n'
          '• macOS Firewall may be blocking — check System Settings → Network → Firewall';
    }
    if (errorStr.contains('Network is unreachable')) {
      return 'Network unreachable. Check your Wi-Fi connection.';
    }
    if (errorStr.contains('No route to host')) {
      return 'No route to host. Are both devices on the same network?';
    }

    if (error is SocketException) {
      return 'Network error: ${error.message}';
    }
    if (error is WebSocketChannelException) {
      return 'WebSocket error: ${error.message}';
    }
    return 'Connection failed: $error';
  }

  /// Send a user command to the Agent.
  void sendCommand(String rawCommand) {
    if (rawCommand.trim().isEmpty) return;

    // Record in terminal
    terminalProvider.recordCommand(rawCommand);

    // Build and send the message
    final msg = VcrMessage.command(
      raw: rawCommand,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    _send(msg);
  }

  /// Send shell input to the Agent.
  void sendShellInput(String input) {
    final data = ShellInputData(input: input);
    final sharedMsg = data.toMessage();
    final msg = VcrMessage(
      type: sharedMsg.type,
      payload: sharedMsg.payload,
    );
    _send(msg);
  }

  /// Send terminal resize to the Agent's shell.
  void sendShellResize(int columns, int rows) {
    final data = ShellResizeData(columns: columns, rows: rows);
    final sharedMsg = data.toMessage();
    final msg = VcrMessage(
      type: sharedMsg.type,
      payload: sharedMsg.payload,
    );
    _send(msg);
  }

  /// Intentionally disconnect from the Agent.
  void disconnect() {
    _intentionalDisconnect = true;
    _cleanup();
    connectionProvider.setDisconnected();
    previewProvider.reset();
    terminalProvider.reset();
  }

  /// Dispose all resources.
  void dispose() {
    _intentionalDisconnect = true;
    _cleanup();
  }

  // =========================================================================
  // Message Routing
  // =========================================================================

  void _onMessage(dynamic rawData) {
    if (rawData is! String) return;

    try {
      final msg = VcrMessage.fromRawJson(rawData);

      switch (msg.type) {
        case 'welcome':
          _handleWelcome(msg);
          break;
        case 'response':
          _handleResponse(msg);
          break;
        case 'frame':
          _handleFrame(msg);
          break;
        case 'status':
          _handleStatus(msg);
          break;
        case 'devices':
          _handleDevices(msg);
          break;
        case MessageType.shellOutput:
          _handleShellOutput(msg);
          break;
        case MessageType.shellExit:
          _handleShellExit(msg);
          break;
        case MessageType.foregroundProcess:
          _handleForegroundProcess(msg);
          break;
        case 'pong':
          // Keepalive acknowledged -- nothing to do.
          break;
        default:
          // Unknown message type -- ignore.
          break;
      }
    } catch (e) {
      // Malformed message -- ignore silently.
    }
  }

  void _handleWelcome(VcrMessage msg) {
    final payload = msg.payload;
    connectionProvider.setConnected(
      projectName: payload['project_name'] as String?,
      agentVersion: payload['agent_version'] as String?,
      commands: (payload['commands'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );

    // If agent reports a state, update preview provider.
    previewProvider.setAgentState(AgentState.idle);

    // Auto-activate shell if the agent reports it is already running.
    final shellActive = payload['shell_active'] as bool? ?? false;
    if (shellActive) {
      terminalProvider.setShellActive(true);
    }

    terminalProvider.addEntry(TerminalEntry(
      type: TerminalEntryType.success,
      text:
          'Connected to VCR Agent v${payload['agent_version'] ?? 'unknown'}',
    ));
  }

  void _handleResponse(VcrMessage msg) {
    final response = VcrResponse.fromPayload(msg.payload, id: msg.id);

    // Add logs first
    for (final log in response.logs) {
      terminalProvider.addEntry(TerminalEntry(
        type: TerminalEntryType.log,
        text: log,
      ));
    }

    // Add the final message
    final TerminalEntryType entryType;
    if (response.isSuccess) {
      entryType = TerminalEntryType.success;
    } else if (response.isWarning) {
      entryType = TerminalEntryType.warning;
    } else {
      entryType = TerminalEntryType.error;
    }

    terminalProvider.addEntry(TerminalEntry(
      type: entryType,
      text: response.message,
    ));
  }

  void _handleFrame(VcrMessage msg) {
    final data = msg.payload['data'] as String?;
    if (data == null) return;

    final seq = msg.payload['seq'] as int? ?? -1;

    // Parse device identification fields (nullable for backward compat)
    final deviceFields = FrameData.parseDeviceFields(msg.payload);

    try {
      final bytes = base64Decode(data);
      previewProvider.updateFrame(
        Uint8List.fromList(bytes),
        seq: seq,
        deviceId: deviceFields.deviceId,
        deviceName: deviceFields.deviceName,
        platform: deviceFields.platform,
      );
    } catch (_) {
      // Failed to decode base64 -- skip frame.
    }
  }

  /// Handle the 'devices' message type from the agent.
  ///
  /// Expected payload format:
  /// ```json
  /// {
  ///   "devices": [
  ///     {"id": "emulator-5554", "name": "Pixel 7", "platform": "android", "is_capturing": true}
  ///   ]
  /// }
  /// ```
  void _handleDevices(VcrMessage msg) {
    final devicesList = msg.payload['devices'] as List<dynamic>?;
    if (devicesList == null) return;

    final devices = devicesList
        .whereType<Map<String, dynamic>>()
        .map((json) => DeviceInfo.fromJson(json))
        .toList();

    previewProvider.updateDeviceList(devices);

    debugPrint('[WS] Received device list: ${devices.length} device(s)');
  }

  void _handleStatus(VcrMessage msg) {
    final stateStr = msg.payload['state'] as String?;
    if (stateStr != null) {
      previewProvider.setAgentState(AgentState.fromString(stateStr));
    }

    final message = msg.payload['message'] as String?;
    if (message != null && message.isNotEmpty) {
      terminalProvider.addEntry(TerminalEntry(
        type: TerminalEntryType.log,
        text: message,
      ));
    }
  }

  void _handleShellOutput(VcrMessage msg) {
    final sharedMsg = _toSharedMessage(msg);
    final data = ShellOutputData.fromMessage(sharedMsg);
    // Auto-activate shell on first output (handles race condition where
    // welcome arrives before shell is started on the agent side).
    if (!terminalProvider.shellActive) {
      terminalProvider.setShellActive(true);
    }
    terminalProvider.writeToShell(data.output);
  }

  void _handleShellExit(VcrMessage msg) {
    final sharedMsg = _toSharedMessage(msg);
    final data = ShellExitData.fromMessage(sharedMsg);
    terminalProvider.setShellExited(data.exitCode);
  }

  void _handleForegroundProcess(VcrMessage msg) {
    final sharedMsg = _toSharedMessage(msg);
    final data = ForegroundProcessData.fromMessage(sharedMsg);
    terminalProvider.setForegroundProcess(data.processName, data.isAiTool);
  }

  // =========================================================================
  // Connection lifecycle
  // =========================================================================

  void _onError(dynamic error) {
    debugPrint('[WS] Stream error: $error');
    _handleDisconnect();
  }

  void _onDone() {
    _handleDisconnect();
  }

  void _handleDisconnect() {
    // Guard against double-firing (onError + onDone can both call this).
    if (_isDisconnecting) return;
    _isDisconnecting = true;

    _stopPingTimer();
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    if (_intentionalDisconnect) return;

    debugPrint('[WS] Connection lost. Scheduling reconnect...');
    previewProvider.setAgentState(AgentState.disconnected);
    previewProvider.reset();
    terminalProvider.reset();
    connectionProvider.setDisconnected();

    // Attempt auto-reconnect
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;

    final host = connectionProvider.host;
    final port = connectionProvider.port;
    if (host == null || port == null) return;

    if (connectionProvider.reconnectAttempts >=
        NetworkConstants.maxReconnectAttempts) {
      terminalProvider.addEntry(TerminalEntry(
        type: TerminalEntryType.error,
        text:
            'Reconnection failed after ${NetworkConstants.maxReconnectAttempts} attempts.',
      ));
      return;
    }

    connectionProvider.incrementReconnectAttempts();
    terminalProvider.addEntry(TerminalEntry(
      type: TerminalEntryType.warning,
      text:
          'Connection lost. Reconnecting in ${NetworkConstants.reconnectDelay.inSeconds}s '
          '(${connectionProvider.reconnectAttempts}/${NetworkConstants.maxReconnectAttempts})...',
    ));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(NetworkConstants.reconnectDelay, () {
      if (!_intentionalDisconnect) {
        connect(host, port);
      }
    });
  }

  // =========================================================================
  // Keepalive
  // =========================================================================

  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(NetworkConstants.pingInterval, (_) {
      _send(VcrMessage.ping());
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  // =========================================================================
  // Helpers
  // =========================================================================

  void _send(VcrMessage msg) {
    try {
      _channel?.sink.add(msg.toRawJson());
    } catch (_) {
      // Sink might be closed -- ignore.
    }
  }

  /// Convert an app-local VcrMessage to a shared VcrMessage
  /// so that shared model fromMessage() factories can be used.
  shared.VcrMessage _toSharedMessage(VcrMessage msg) {
    return shared.VcrMessage(
      type: msg.type,
      id: msg.id,
      payload: msg.payload,
    );
  }

  void _cleanup() {
    _stopPingTimer();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isDisconnecting = false;
  }
}
