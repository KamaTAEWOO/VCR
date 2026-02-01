import 'vcr_message.dart';
import '../protocol.dart';

/// Shell output message sent from Server to Client.
///
/// Streams stdout/stderr from the shell process in real-time.
///
/// ```json
/// {
///   "type": "shell_output",
///   "payload": {
///     "output": "total 42\ndrwxr-xr-x ...",
///     "stream": "stdout",
///     "is_history": false
///   }
/// }
/// ```
class ShellOutputData {
  /// Shell output text
  final String output;

  /// Output stream: 'stdout' or 'stderr'
  final String stream;

  /// Whether this output is historical (from buffer replay on reconnect)
  final bool isHistory;

  const ShellOutputData({
    required this.output,
    required this.stream,
    this.isHistory = false,
  });

  factory ShellOutputData.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    return ShellOutputData(
      output: payload['output'] as String? ?? '',
      stream: payload['stream'] as String? ?? 'stdout',
      isHistory: payload['is_history'] as bool? ?? false,
    );
  }

  factory ShellOutputData.fromMessage(VcrMessage message) {
    return ShellOutputData(
      output: message.payload['output'] as String? ?? '',
      stream: message.payload['stream'] as String? ?? 'stdout',
      isHistory: message.payload['is_history'] as bool? ?? false,
    );
  }

  VcrMessage toMessage() {
    return VcrMessage(
      type: MessageType.shellOutput,
      payload: {
        'output': output,
        'stream': stream,
        'is_history': isHistory,
      },
    );
  }

  Map<String, dynamic> toJson() => toMessage().toJson();

  bool get isStdout => stream == 'stdout';
  bool get isStderr => stream == 'stderr';

  @override
  String toString() => 'ShellOutputData(stream: $stream, output: ${output.length} chars)';
}
