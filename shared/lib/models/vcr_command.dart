import 'vcr_message.dart';
import '../protocol.dart';

/// Command message sent from Client to Server.
///
/// ```json
/// {
///   "type": "command",
///   "id": "550e8400-e29b-41d4-a716-446655440000",
///   "payload": {
///     "raw": "create page Home"
///   }
/// }
/// ```
class VcrCommand {
  /// Request ID for matching with response
  final String? id;

  /// Raw command string entered by user
  final String raw;

  const VcrCommand({
    this.id,
    required this.raw,
  });

  factory VcrCommand.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    return VcrCommand(
      id: json['id'] as String?,
      raw: payload['raw'] as String? ?? '',
    );
  }

  factory VcrCommand.fromMessage(VcrMessage message) {
    return VcrCommand(
      id: message.id,
      raw: message.payload['raw'] as String? ?? '',
    );
  }

  VcrMessage toMessage() {
    return VcrMessage(
      type: MessageType.command,
      id: id,
      payload: {'raw': raw},
    );
  }

  Map<String, dynamic> toJson() => toMessage().toJson();

  @override
  String toString() => 'VcrCommand(id: $id, raw: $raw)';
}
