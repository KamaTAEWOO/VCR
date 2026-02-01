import 'vcr_message.dart';
import '../protocol.dart';

/// Response message sent from Server to Client after command execution.
///
/// ```json
/// {
///   "type": "response",
///   "id": "550e8400-e29b-41d4-a716-446655440000",
///   "payload": {
///     "status": "success",
///     "message": "Page Home created",
///     "logs": ["Creating lib/pages/home_page.dart...", "Hot reload triggered"],
///     "error_code": null
///   }
/// }
/// ```
class VcrResponse {
  /// Request ID matching the original command
  final String? id;

  /// Response status: "success", "error", or "warning"
  final String status;

  /// Human-readable summary message
  final String message;

  /// Detailed execution logs
  final List<String> logs;

  /// Error code (only present when status == "error")
  final String? errorCode;

  const VcrResponse({
    this.id,
    required this.status,
    required this.message,
    this.logs = const [],
    this.errorCode,
  });

  /// Create a success response
  factory VcrResponse.success({
    String? id,
    required String message,
    List<String> logs = const [],
  }) {
    return VcrResponse(
      id: id,
      status: ResponseStatus.success,
      message: message,
      logs: logs,
    );
  }

  /// Create an error response
  factory VcrResponse.error({
    String? id,
    required String message,
    required String errorCode,
    List<String> logs = const [],
  }) {
    return VcrResponse(
      id: id,
      status: ResponseStatus.error,
      message: message,
      logs: logs,
      errorCode: errorCode,
    );
  }

  /// Create a warning response
  factory VcrResponse.warning({
    String? id,
    required String message,
    List<String> logs = const [],
  }) {
    return VcrResponse(
      id: id,
      status: ResponseStatus.warning,
      message: message,
      logs: logs,
    );
  }

  factory VcrResponse.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    return VcrResponse(
      id: json['id'] as String?,
      status: payload['status'] as String? ?? ResponseStatus.error,
      message: payload['message'] as String? ?? '',
      logs: (payload['logs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      errorCode: payload['error_code'] as String?,
    );
  }

  factory VcrResponse.fromMessage(VcrMessage message) {
    return VcrResponse(
      id: message.id,
      status:
          message.payload['status'] as String? ?? ResponseStatus.error,
      message: message.payload['message'] as String? ?? '',
      logs: (message.payload['logs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      errorCode: message.payload['error_code'] as String?,
    );
  }

  VcrMessage toMessage() {
    final payloadMap = <String, dynamic>{
      'status': status,
      'message': message,
      'logs': logs,
    };
    if (errorCode != null) {
      payloadMap['error_code'] = errorCode;
    }
    return VcrMessage(
      type: MessageType.response,
      id: id,
      payload: payloadMap,
    );
  }

  Map<String, dynamic> toJson() => toMessage().toJson();

  bool get isSuccess => status == ResponseStatus.success;
  bool get isError => status == ResponseStatus.error;
  bool get isWarning => status == ResponseStatus.warning;

  @override
  String toString() =>
      'VcrResponse(id: $id, status: $status, message: $message)';
}
