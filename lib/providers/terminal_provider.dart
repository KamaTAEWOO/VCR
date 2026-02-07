import 'dart:async';

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
  bool _isSwitchingMode = false;

  // -- Tab completion state --
  bool _isCompletionMode = false;
  bool _isTabLoading = false;
  StringBuffer _completionBuffer = StringBuffer();
  List<CompletionItem> _suggestions = [];
  void Function(List<CompletionItem>)? onCompletionResult;

  /// Debounce timer for batching rapid addEntry calls.
  Timer? _entryDebounce;

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
  bool get isSwitchingMode => _isSwitchingMode;
  bool get isCompletionMode => _isCompletionMode;
  bool get isTabLoading => _isTabLoading;
  List<CompletionItem> get suggestions => List.unmodifiable(_suggestions);

  // -- Mutations --

  /// Add a terminal output entry (input echo, success, error, warning, log).
  ///
  /// Uses debounced notification to batch rapid successive adds.
  void addEntry(TerminalEntry entry) {
    _entries.add(entry);
    _scheduleNotify();
  }

  /// Add multiple entries at once (e.g. logs from a response).
  void addEntries(List<TerminalEntry> entries) {
    _entries.addAll(entries);
    _scheduleNotify();
  }

  /// Batch rapid entry additions into a single notify per frame (~16ms).
  void _scheduleNotify() {
    if (_entryDebounce != null) return;
    _entryDebounce = Timer(const Duration(milliseconds: 16), () {
      _entryDebounce = null;
      notifyListeners();
    });
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

  /// Add a command to history only (no terminal echo).
  void addToHistory(String command) {
    _commandHistory.add(command);
    if (_commandHistory.length > TerminalConstants.maxHistorySize) {
      _commandHistory.removeAt(0);
    }
    notifyListeners();
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

  void setSwitchingMode(bool switching) {
    if (_isSwitchingMode == switching) return;
    _isSwitchingMode = switching;
    notifyListeners();
  }

  /// Update the foreground process info from the agent.
  void setForegroundProcess(String processName, bool isAiTool) {
    if (_foregroundProcess == processName && _isAiToolActive == isAiTool) return;
    _foregroundProcess = processName;
    _isAiToolActive = isAiTool;
    _isSwitchingMode = false;
    notifyListeners();
  }

  void writeToShell(String data) {
    _shellTerminal?.write(data);
  }

  // -- Tab completion --

  // STX/ETX control characters: won't appear in shell echo text
  // (echo shows literal \x02 text, but printf outputs actual 0x02 byte).
  static const String _completionStartMarker = '\x02VCR_CS\x03';
  static const String _completionEndMarker = '\x02VCR_CE\x03';

  /// Start capturing shell output for tab completion.
  void startCompletion() {
    _isCompletionMode = true;
    _isTabLoading = true;
    _completionBuffer = StringBuffer();
    _suggestions = [];
    notifyListeners();
  }

  /// Process shell output during completion mode.
  /// Returns true if the output was consumed by completion (should not be
  /// written to the terminal).
  bool handleCompletionOutput(String data) {
    if (!_isCompletionMode) return false;

    _completionBuffer.write(data);
    final buffered = _completionBuffer.toString();

    // Wait until we see the end marker.
    final endIdx = buffered.indexOf(_completionEndMarker);
    if (endIdx == -1) return true; // still accumulating

    // Extract content between markers.
    final startIdx = buffered.indexOf(_completionStartMarker);
    final contentStart = startIdx != -1
        ? startIdx + _completionStartMarker.length
        : 0;
    final content = buffered.substring(contentStart, endIdx);

    // Parse completion results: split lines, trim whitespace/\r, skip empty
    // and the '.' / '..' entries.
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) =>
            l.isNotEmpty && l != '.' && l != '..' && l != './' && l != '../')
        .toList();

    _suggestions = lines.map((name) {
      final isDir = name.endsWith('/');
      final cleanName = isDir ? name.substring(0, name.length - 1) : name;
      return CompletionItem(name: cleanName, isDirectory: isDir);
    }).toList();

    _isCompletionMode = false;
    _isTabLoading = false;
    _completionBuffer = StringBuffer();

    // Write any remaining output after end marker to terminal (shell prompt).
    final afterEnd = endIdx + _completionEndMarker.length;
    if (afterEnd < buffered.length) {
      _shellTerminal?.write(buffered.substring(afterEnd));
    }

    onCompletionResult?.call(_suggestions);
    notifyListeners();
    return true;
  }

  /// Clear suggestions (e.g. when user selects one or changes input).
  void clearSuggestions() {
    if (_suggestions.isEmpty) return;
    _suggestions = [];
    notifyListeners();
  }

  void cancelCompletion() {
    _isCompletionMode = false;
    _isTabLoading = false;
    _completionBuffer = StringBuffer();
    _suggestions = [];
    notifyListeners();
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
    _isSwitchingMode = false;
    _isCompletionMode = false;
    _isTabLoading = false;
    _completionBuffer = StringBuffer();
    _suggestions = [];
    _entryDebounce?.cancel();
    _entryDebounce = null;
    notifyListeners();
  }
}

/// A single tab-completion suggestion.
class CompletionItem {
  final String name;
  final bool isDirectory;

  const CompletionItem({required this.name, required this.isDirectory});
}
