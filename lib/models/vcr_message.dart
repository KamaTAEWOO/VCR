import 'dart:convert';

// TODO: Replace with package:vcr_shared VcrMessage. Move command()/ping()
// factory constructors and fromRawJson/toRawJson into the shared model.

/// Base message structure for VCR WebSocket protocol.
///
/// All messages have: type, optional id, and a payload map.
/// When shared package is ready, replace this with shared's definition.
class VcrMessage {
  final String type;
  final String? id;
  final Map<String, dynamic> payload;

  const VcrMessage({
    required this.type,
    this.id,
    required this.payload,
  });

  /// Create from a decoded JSON map.
  factory VcrMessage.fromJson(Map<String, dynamic> json) {
    return VcrMessage(
      type: json['type'] as String,
      id: json['id'] as String?,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Create from a raw JSON string.
  factory VcrMessage.fromRawJson(String rawJson) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    return VcrMessage.fromJson(map);
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (id != null) 'id': id,
      'payload': payload,
    };
  }

  /// Serialize to a raw JSON string.
  String toRawJson() => jsonEncode(toJson());

  // --- Factory helpers for common message types ---

  /// Create a command message (client -> server).
  factory VcrMessage.command({
    required String raw,
    String? id,
  }) {
    return VcrMessage(
      type: 'command',
      id: id,
      payload: {'raw': raw},
    );
  }

  /// Create a ping message (client -> server).
  factory VcrMessage.ping() {
    return const VcrMessage(
      type: 'ping',
      payload: {},
    );
  }
}
