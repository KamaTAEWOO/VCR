import 'vcr_message.dart';
import '../protocol.dart';

/// Foreground process info sent from Server to Client.
///
/// Reports the current foreground process running in the shell,
/// with a flag indicating whether it's an AI tool (e.g. claude CLI).
///
/// ```json
/// {
///   "type": "foreground_process",
///   "payload": {
///     "process_name": "claude",
///     "is_ai_tool": true
///   }
/// }
/// ```
class ForegroundProcessData {
  /// Name of the foreground process (empty string if none detected).
  final String processName;

  /// Whether the detected process is an AI coding tool.
  final bool isAiTool;

  const ForegroundProcessData({
    required this.processName,
    required this.isAiTool,
  });

  factory ForegroundProcessData.fromMessage(VcrMessage message) {
    return ForegroundProcessData(
      processName: message.payload['process_name'] as String? ?? '',
      isAiTool: message.payload['is_ai_tool'] as bool? ?? false,
    );
  }

  VcrMessage toMessage() {
    return VcrMessage(
      type: MessageType.foregroundProcess,
      payload: {
        'process_name': processName,
        'is_ai_tool': isAiTool,
      },
    );
  }

  @override
  String toString() =>
      'ForegroundProcessData(processName: $processName, isAiTool: $isAiTool)';
}
