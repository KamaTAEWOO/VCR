import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import '../core/constants.dart';
import '../models/terminal_entry.dart';

/// Manages terminal command history and output entries.
class TerminalProvider extends ChangeNotifier {
  final List<String> _commandHistory = [];
  final List<TerminalEntry> _entries = [];
  String _currentInput = '';
  bool _shellActive = false;
  Terminal? _shellTerminal;
  int? _shellExitCode;
  String _foregroundProcess = '';
  bool _isAiToolActive = false;

  // -- Getters --

  List<String> get commandHistory => List.unmodifiable(_commandHistory);
  List<TerminalEntry> get entries => List.unmodifiable(_entries);
  String get currentInput => _currentInput;
  bool get shellActive => _shellActive;
  Terminal? get shellTerminal => _shellTerminal;
  int? get shellExitCode => _shellExitCode;
  bool get shellExited => _shellExitCode != null;
  String get foregroundProcess => _foregroundProcess;
  bool get isAiToolActive => _isAiToolActive;
  bool get isClaudeMode => _isAiToolActive;

  // -- Mutations --

  /// Add a terminal output entry (input echo, success, error, warning, log).
  void addEntry(TerminalEntry entry) {
    _entries.add(entry);
    notifyListeners();
  }

  /// Add multiple entries at once (e.g. logs from a response).
  void addEntries(List<TerminalEntry> entries) {
    _entries.addAll(entries);
    notifyListeners();
  }

  /// Record a sent command into history and echo it in terminal output.
  void recordCommand(String command) {
    // Add to history (cap at maxHistorySize)
    _commandHistory.add(command);
    if (_commandHistory.length > TerminalConstants.maxHistorySize) {
      _commandHistory.removeAt(0);
    }

    // Echo the command as an input entry
    addEntry(TerminalEntry(
      type: TerminalEntryType.input,
      text: command,
    ));
  }

  /// Update the current input text (for tracking state).
  void setCurrentInput(String value) {
    _currentInput = value;
    // No notifyListeners here -- the TextField manages its own state.
    // Only call notify if other UI depends on it.
  }

  /// Set whether the shell mode is active.
  void setShellActive(bool active) {
    _shellActive = active;
    if (active) {
      _shellExitCode = null;
      _shellTerminal ??= Terminal(maxLines: 10000);
    } else {
      _shellTerminal = null;
    }
    notifyListeners();
  }

  /// Record that the shell exited with [exitCode].
  void setShellExited(int exitCode) {
    _shellActive = false;
    _shellExitCode = exitCode;
    notifyListeners();
  }

  /// Update the foreground process info from the agent.
  void setForegroundProcess(String processName, bool isAiTool) {
    if (_foregroundProcess == processName && _isAiToolActive == isAiTool) return;
    _foregroundProcess = processName;
    _isAiToolActive = isAiTool;
    notifyListeners();
  }

  void writeToShell(String data) {
    _shellTerminal?.write(data);
  }

  /// Clear all terminal output entries.
  void clearEntries() {
    _entries.clear();
    notifyListeners();
  }

  /// Reset all state (on disconnect).
  void reset() {
    _commandHistory.clear();
    _entries.clear();
    _currentInput = '';
    _shellActive = false;
    _shellTerminal = null;
    _shellExitCode = null;
    _foregroundProcess = '';
    _isAiToolActive = false;
    notifyListeners();
  }
}
