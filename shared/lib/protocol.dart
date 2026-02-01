/// WebSocket message type constants for VCR protocol.
///
/// All messages follow the structure:
/// ```json
/// {
///   "type": "<message_type>",
///   "id": "<optional_request_id>",
///   "payload": { ... }
/// }
/// ```
class MessageType {
  MessageType._();

  /// Client -> Server: Command execution request
  static const String command = 'command';

  /// Server -> Client: Command execution result
  static const String response = 'response';

  /// Server -> Client: Emulator screen frame (JPEG Base64)
  static const String frame = 'frame';

  /// Server -> Client: Agent state change notification
  static const String status = 'status';

  /// Client -> Server: Connection keepalive ping
  static const String ping = 'ping';

  /// Server -> Client: Keepalive pong response
  static const String pong = 'pong';

  /// Server -> Client: Sent immediately upon client connection
  static const String welcome = 'welcome';

  /// Server -> Client: Connected device list
  static const String devices = 'devices';

  /// Client -> Server: Shell command input
  static const String shellInput = 'shell_input';

  /// Server -> Client: Shell stdout/stderr output
  static const String shellOutput = 'shell_output';

  /// Server -> Client: Shell process exited
  static const String shellExit = 'shell_exit';

  /// Client -> Server: Terminal resize request
  static const String shellResize = 'shell_resize';

  /// Server -> Client: Foreground process info (e.g. claude CLI detected)
  static const String foregroundProcess = 'foreground_process';

  /// All valid message types
  static const List<String> allTypes = [
    command,
    response,
    frame,
    status,
    ping,
    pong,
    welcome,
    devices,
    shellInput,
    shellOutput,
    shellExit,
    shellResize,
    foregroundProcess,
  ];

  /// Check if a string is a valid message type
  static bool isValid(String type) => allTypes.contains(type);
}

/// Response status values
class ResponseStatus {
  ResponseStatus._();

  static const String success = 'success';
  static const String error = 'error';
  static const String warning = 'warning';
}

/// Error codes returned in error responses
class ErrorCode {
  ErrorCode._();

  static const String parseError = 'PARSE_ERROR';
  static const String projectNotFound = 'PROJECT_NOT_FOUND';
  static const String projectAlreadyRunning = 'PROJECT_ALREADY_RUNNING';
  static const String flutterNotFound = 'FLUTTER_NOT_FOUND';
  static const String adbNotFound = 'ADB_NOT_FOUND';
  static const String emulatorNotRunning = 'EMULATOR_NOT_RUNNING';
  static const String buildFailed = 'BUILD_FAILED';
  static const String fileError = 'FILE_ERROR';
  static const String unknownCommand = 'UNKNOWN_COMMAND';
}

/// Default connection constants
class ConnectionDefaults {
  ConnectionDefaults._();

  /// Default WebSocket server port
  static const int port = 9000;

  /// mDNS service type for discovery
  static const String mdnsServiceType = '_vcr._tcp';

  /// Agent version string
  static const String agentVersion = '0.1.0';

  /// Keepalive ping interval in seconds
  static const int pingIntervalSeconds = 30;

  /// Server timeout (no ping received) in seconds
  static const int serverTimeoutSeconds = 60;

  /// Client reconnect delay in seconds
  static const int reconnectDelaySeconds = 5;

  /// Maximum reconnect attempts
  static const int maxReconnectAttempts = 5;

  /// Screen capture interval in milliseconds (~10fps)
  static const int captureIntervalMs = 100;

  /// JPEG quality for screen capture (0-100)
  static const int jpegQuality = 40;
}
