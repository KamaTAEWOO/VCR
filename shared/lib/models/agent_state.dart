import 'vcr_message.dart';
import '../protocol.dart';

/// Enum representing the current state of the VCR Agent.
enum AgentState {
  /// Agent running, no project active
  idle('idle'),

  /// Flutter app is running normally
  running('running'),

  /// Hot reload in progress
  hotReloading('hot_reloading'),

  /// Hot restart in progress
  hotRestarting('hot_restarting'),

  /// Build in progress
  building('building'),

  /// Build error occurred
  buildError('build_error'),

  /// General error
  error('error');

  final String value;

  const AgentState(this.value);

  /// Parse a string value to AgentState
  static AgentState fromString(String value) {
    return AgentState.values.firstWhere(
      (state) => state.value == value,
      orElse: () => AgentState.error,
    );
  }
}

/// Status update message sent from Server to Client.
///
/// ```json
/// {
///   "type": "status",
///   "payload": {
///     "state": "hot_reloading",
///     "message": "Performing hot reload..."
///   }
/// }
/// ```
class StatusData {
  /// Current agent state
  final AgentState state;

  /// Optional detail message
  final String? message;

  const StatusData({
    required this.state,
    this.message,
  });

  factory StatusData.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    return StatusData(
      state: AgentState.fromString(payload['state'] as String? ?? 'error'),
      message: payload['message'] as String?,
    );
  }

  factory StatusData.fromMessage(VcrMessage message) {
    return StatusData(
      state: AgentState.fromString(
          message.payload['state'] as String? ?? 'error'),
      message: message.payload['message'] as String?,
    );
  }

  VcrMessage toMessage() {
    final payloadMap = <String, dynamic>{
      'state': state.value,
    };
    if (message != null) {
      payloadMap['message'] = message;
    }
    return VcrMessage(
      type: MessageType.status,
      payload: payloadMap,
    );
  }

  Map<String, dynamic> toJson() => toMessage().toJson();

  @override
  String toString() => 'StatusData(state: ${state.value}, message: $message)';
}
