import 'vcr_message.dart';
import '../protocol.dart';

/// Shell resize message sent from Client to Server.
///
/// Requests the agent to resize the shell PTY dimensions.
///
/// ```json
/// {
///   "type": "shell_resize",
///   "payload": {
///     "columns": 80,
///     "rows": 24
///   }
/// }
/// ```
class ShellResizeData {
  final int columns;
  final int rows;

  const ShellResizeData({
    required this.columns,
    required this.rows,
  });

  factory ShellResizeData.fromMessage(VcrMessage message) {
    return ShellResizeData(
      columns: message.payload['columns'] as int? ?? 80,
      rows: message.payload['rows'] as int? ?? 24,
    );
  }

  VcrMessage toMessage() {
    return VcrMessage(
      type: MessageType.shellResize,
      payload: {
        'columns': columns,
        'rows': rows,
      },
    );
  }
}
