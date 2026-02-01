/// Types of terminal output entries.
enum TerminalEntryType {
  input,
  success,
  error,
  warning,
  log,
  shellOutput,
}

/// A single line/block of terminal output.
///
/// App-only UI model -- no shared equivalent needed.
class TerminalEntry {
  final TerminalEntryType type;
  final String text;
  final DateTime timestamp;

  TerminalEntry({
    required this.type,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Prefix displayed before the text in the terminal.
  String get prefix {
    switch (type) {
      case TerminalEntryType.input:
        return '> ';
      case TerminalEntryType.success:
        return '\u2713 '; // checkmark
      case TerminalEntryType.error:
        return '\u2717 '; // x-mark
      case TerminalEntryType.warning:
        return '\u26A0 '; // warning sign
      case TerminalEntryType.log:
        return '  '; // indent
      case TerminalEntryType.shellOutput:
        return '';
    }
  }
}
