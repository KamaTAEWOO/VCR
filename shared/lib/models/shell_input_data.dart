import 'vcr_message.dart';
import '../protocol.dart';

/// Shell input message sent from Client to Server.
///
/// ```json
/// {
///   "type": "shell_input",
///   "payload": {
///     "input": "ls -la"
///   }
/// }
/// ```
class ShellInputData {
  /// Raw shell command string to execute
  final String input;

  const ShellInputData({
    required this.input,
  });

  factory ShellInputData.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    return ShellInputData(
      input: payload['input'] as String? ?? '',
    );
  }

  factory ShellInputData.fromMessage(VcrMessage message) {
    return ShellInputData(
      input: message.payload['input'] as String? ?? '',
    );
  }

  VcrMessage toMessage() {
    return VcrMessage(
      type: MessageType.shellInput,
      payload: {'input': input},
    );
  }

  Map<String, dynamic> toJson() => toMessage().toJson();

  @override
  String toString() => 'ShellInputData(input: $input)';
}
