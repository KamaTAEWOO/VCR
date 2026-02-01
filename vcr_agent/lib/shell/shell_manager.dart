import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Manages a notebook's shell process (bash/zsh).
///
/// Spawns an interactive login shell, forwards user input via [writeInput],
/// and streams stdout/stderr output through the [onOutput] callback.
/// The shell is started with `TERM=dumb` to minimise ANSI escape sequences.
///
/// Maintains an output buffer (max [maxBufferSize] bytes) so that newly
/// connected clients can receive recent shell history.
class ShellManager {
  /// The running shell process.
  Process? _process;

  /// Stdout stream subscription.
  StreamSubscription<String>? _stdoutSub;

  /// Stderr stream subscription.
  StreamSubscription<String>? _stderrSub;

  int _columns = 50;
  int _rows = 30;

  /// Maximum output buffer size in bytes (default 50KB).
  static const int maxBufferSize = 50 * 1024;

  /// Ring buffer for recent shell output.
  final StringBuffer _outputBuffer = StringBuffer();

  /// Current buffer size in bytes (approximation using string length).
  int _bufferLength = 0;

  /// Called when the shell emits output.
  ///
  /// [output] is the decoded text and [stream] is either `'stdout'` or
  /// `'stderr'`.
  void Function(String output, String stream)? onOutput;

  /// Called when the shell process exits with [exitCode].
  void Function(int exitCode)? onExit;

  /// Called when the foreground process changes.
  ///
  /// [processName] is the detected process name (e.g. 'claude'), and
  /// [isAiTool] indicates whether it is recognized as an AI coding tool.
  /// Called with empty string and false when no special process is detected.
  void Function(String processName, bool isAiTool)? onForegroundProcessChanged;

  /// Timer for periodic foreground process polling.
  Timer? _foregroundPollTimer;

  /// Last reported AI tool detection state (to avoid duplicate callbacks).
  bool _lastAiToolDetected = false;

  /// Whether the shell process is currently active.
  bool get isActive => _process != null;

  /// Start an interactive login shell.
  ///
  /// Uses the user's default shell from the `SHELL` environment variable,
  /// falling back to `/bin/bash` if unset. The `-l` flag is passed so that
  /// login profiles are sourced.
  ///
  /// If a shell is already active this method returns immediately.
  Future<void> start() async {
    if (isActive) return;

    final shell = Platform.environment['SHELL'] ?? '/bin/bash';

    _process = await Process.start(
      'script',
      ['-q', '/dev/null', shell, '-l', '-i'],
      environment: {
        'TERM': 'xterm-256color',
        'LANG': Platform.environment['LANG'] ?? 'en_US.UTF-8',
        'COLUMNS': '$_columns',
        'LINES': '$_rows',
      },
    );

    // Listen to stdout
    _stdoutSub = const Utf8Decoder(allowMalformed: true)
        .bind(_process!.stdout)
        .listen((data) {
      _appendToBuffer(data);
      onOutput?.call(data, 'stdout');
    });

    // Listen to stderr
    _stderrSub = const Utf8Decoder(allowMalformed: true)
        .bind(_process!.stderr)
        .listen((data) {
      _appendToBuffer(data);
      onOutput?.call(data, 'stderr');
    });

    // Monitor process exit
    _process!.exitCode.then((exitCode) {
      _cleanup();
      onExit?.call(exitCode);
    });

    // Set initial PTY dimensions silently after shell starts.
    // Uses control chars to suppress the command echo from appearing.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (isActive) {
        _sendSilentResize(_columns, _rows);
      }
    });

    // Start polling for foreground process every 2 seconds.
    _startForegroundPolling();
  }

  /// Write [input] to the shell's stdin as raw bytes.
  ///
  /// When an AI tool (e.g. claude) is the foreground process and the input
  /// ends with CR (`\r`), the text and CR are sent separately with a short
  /// delay. This is necessary because Claude Code's TUI reads stdin in raw
  /// mode and may not process a CR that arrives in the same read() as the
  /// preceding text.
  void writeInput(String input) {
    if (_process == null) return;

    if (_lastAiToolDetected && input.length > 1 && input.endsWith('\r')) {
      final text = input.substring(0, input.length - 1);
      _process!.stdin.add(utf8.encode(text));
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_process != null) {
          _process!.stdin.add(utf8.encode('\r'));
        }
      });
    } else {
      _process!.stdin.add(utf8.encode(input));
    }
  }

  /// Resize the shell's terminal dimensions.
  ///
  /// When an AI tool (e.g. claude) is the foreground process, the stty-based
  /// resize is suppressed because the stty command text would be injected
  /// into the AI tool's stdin. The dimensions are still recorded so they
  /// take effect once the shell regains the foreground.
  void resize(int columns, int rows) {
    if (_columns == columns && _rows == rows) return;
    _columns = columns;
    _rows = rows;
    if (isActive && !_lastAiToolDetected) {
      _sendSilentResize(columns, rows);
    }
  }

  /// Send a stty resize command silently.
  ///
  /// Temporarily disables echo, runs stty to set dimensions,
  /// re-enables echo, then erases the current line to hide any residue.
  void _sendSilentResize(int columns, int rows) {
    _process!.stdin.add(utf8.encode(
      'stty -echo 2>/dev/null;'
      'stty columns $columns rows $rows 2>/dev/null;'
      'stty echo 2>/dev/null;'
      'printf "\\r\\033[K" 2>/dev/null\n',
    ));
  }

  /// Stop the shell process.
  ///
  /// Kills the process, cancels all stream subscriptions,
  /// and clears the output buffer.
  Future<void> stop() async {
    _process?.kill();
    _cleanup();
    clearBuffer();
  }

  /// Append [data] to the output buffer, trimming from the front if it
  /// exceeds [maxBufferSize].
  void _appendToBuffer(String data) {
    _outputBuffer.write(data);
    _bufferLength += data.length;
    if (_bufferLength > maxBufferSize) {
      final full = _outputBuffer.toString();
      final trimmed = full.substring(full.length - maxBufferSize);
      _outputBuffer
        ..clear()
        ..write(trimmed);
      _bufferLength = trimmed.length;
    }
  }

  /// Return the buffered output accumulated so far.
  String getBufferedOutput() => _outputBuffer.toString();

  /// Clear the output buffer.
  void clearBuffer() {
    _outputBuffer.clear();
    _bufferLength = 0;
  }

  /// Clean up subscriptions and process reference.
  void _cleanup() {
    _foregroundPollTimer?.cancel();
    _foregroundPollTimer = null;
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _process = null;
    // Notify that no foreground process is active.
    if (_lastAiToolDetected) {
      _lastAiToolDetected = false;
      onForegroundProcessChanged?.call('', false);
    }
  }

  // =========================================================================
  // Foreground process detection
  // =========================================================================

  /// Start periodic polling to detect the shell's foreground process.
  void _startForegroundPolling() {
    _foregroundPollTimer?.cancel();
    _foregroundPollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkForegroundProcess(),
    );
  }

  /// Check the shell's process tree for a recognized AI tool.
  ///
  /// Scans all descendants (not just the leaf) so that `claude` is detected
  /// even when it has spawned child workers underneath it.
  Future<void> _checkForegroundProcess() async {
    if (_process == null) return;

    try {
      final allPids = await _collectDescendants(_process!.pid);
      // Check every descendant's command line for an AI tool match.
      String matchedName = '';
      for (final pid in allPids) {
        final cmdLine = await _getProcessName(pid);
        if (_isAiToolProcess(cmdLine)) {
          matchedName = 'claude';
          break; // found one — no need to check further
        }
      }
      final isAiTool = matchedName.isNotEmpty;

      if (isAiTool != _lastAiToolDetected) {
        final wasAiTool = _lastAiToolDetected;
        _lastAiToolDetected = isAiTool;
        onForegroundProcessChanged?.call(matchedName, isAiTool);
        // When AI tool exits and shell regains foreground, apply any
        // pending resize that was suppressed during AI tool usage.
        if (wasAiTool && !isAiTool && isActive) {
          _sendSilentResize(_columns, _rows);
        }
      }
    } catch (_) {
      // Process inspection failed (e.g. shell exited) — ignore.
    }
  }

  /// Collect all descendant PIDs of [rootPid] via breadth-first traversal.
  ///
  /// Uses `pgrep -P <pid>` at each level. Returns PIDs in top-down order
  /// (immediate children first) so that `claude` is found before its workers.
  Future<List<int>> _collectDescendants(int rootPid) async {
    final descendants = <int>[];
    var frontier = [rootPid];

    for (var depth = 0; depth < 10 && frontier.isNotEmpty; depth++) {
      final nextFrontier = <int>[];
      for (final pid in frontier) {
        final result = await Process.run('pgrep', ['-P', '$pid']);
        if (result.exitCode != 0) continue;
        final children = (result.stdout as String)
            .trim()
            .split('\n')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList();
        descendants.addAll(children);
        nextFrontier.addAll(children);
      }
      frontier = nextFrontier;
    }
    return descendants;
  }

  /// Get the command name for a process by its [pid].
  ///
  /// Returns the full command-line string (e.g. 'node /usr/bin/claude').
  Future<String> _getProcessName(int pid) async {
    final result = await Process.run('ps', ['-o', 'args=', '-p', '$pid']);
    if (result.exitCode != 0) return '';
    return (result.stdout as String).trim();
  }

  /// Check if [commandLine] looks like an AI coding tool.
  static bool _isAiToolProcess(String commandLine) {
    if (commandLine.isEmpty) return false;
    final lower = commandLine.toLowerCase();
    // Match 'claude' as a standalone command, path segment, or within args.
    // Covers: 'claude', '/usr/bin/claude', 'node .../claude', 'claude chat', etc.
    return RegExp(r'(^|[/\s])claude(\s|$)').hasMatch(lower);
  }

  /// Release all resources held by this manager.
  ///
  /// Stops the shell process if it is still active.
  void dispose() {
    stop();
  }
}
