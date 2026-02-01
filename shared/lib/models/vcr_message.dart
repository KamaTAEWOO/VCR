/// Base VCR WebSocket message.
///
/// All messages follow this structure:
/// ```json
/// {
///   "type": "<message_type>",
///   "id": "<optional_request_id>",
///   "payload": { ... }
/// }
/// ```
class VcrMessage {
  /// Message type identifier (command, response, frame, status, ping, pong, welcome)
  final String type;

  /// Optional request-response matching ID (UUID)
  final String? id;

  /// Type-specific payload data
  final Map<String, dynamic> payload;

  const VcrMessage({
    required this.type,
    this.id,
    required this.payload,
  });

  factory VcrMessage.fromJson(Map<String, dynamic> json) {
    return VcrMessage(
      type: json['type'] as String,
      id: json['id'] as String?,
      payload: json['payload'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type,
      'payload': payload,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  @override
  String toString() => 'VcrMessage(type: $type, id: $id, payload: $payload)';
}
