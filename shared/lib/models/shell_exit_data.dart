import 'vcr_message.dart';
import '../protocol.dart';

/// Shell exit message sent from Server to Client when the shell process exits.
///
/// ```json
/// {
///   "type": "shell_exit",
///   "payload": {
///     "exitCode": 0
///   }
/// }
/// ```
class ShellExitData {
  /// Shell process exit code (0 = success)
  final int exitCode;

  const ShellExitData({
    required this.exitCode,
  });

  factory ShellExitData.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    return ShellExitData(
      exitCode: payload['exitCode'] as int? ?? -1,
    );
  }

  factory ShellExitData.fromMessage(VcrMessage message) {
    return ShellExitData(
      exitCode: message.payload['exitCode'] as int? ?? -1,
    );
  }

  VcrMessage toMessage() {
    return VcrMessage(
      type: MessageType.shellExit,
      payload: {'exitCode': exitCode},
    );
  }

  Map<String, dynamic> toJson() => toMessage().toJson();

  bool get isSuccess => exitCode == 0;

  @override
  String toString() => 'ShellExitData(exitCode: $exitCode)';
}
