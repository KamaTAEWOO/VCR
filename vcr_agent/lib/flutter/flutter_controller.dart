import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vcr_shared/vcr_shared.dart';

/// Callback type for build log lines
typedef LogCallback = void Function(String line);

/// Callback type for state changes
typedef StateCallback = void Function(AgentState state, String? message);

/// Controls Flutter CLI operations: create, run, hot reload, hot restart.
///
/// Manages the `flutter run` process lifecycle, captures stdout/stderr,
/// and provides hot reload/restart by writing to the process stdin.
class FlutterController {
  /// Regex for valid Flutter project names: lowercase start, only a-z, 0-9, _.
  static final _validProjectName = RegExp(r'^[a-z][a-z0-9_]*$');
  /// The currently running `flutter run` process
  Process? _flutterProcess;

  /// Whether flutter is currently running
  bool get isRunning => _flutterProcess != null;

  /// Callback for build log output
  LogCallback? onLog;

  /// Callback for state changes
  StateCallback? onStateChange;

  /// Stdout subscription
  StreamSubscription<String>? _stdoutSub;

  /// Stderr subscription
  StreamSubscription<String>? _stderrSub;

  /// Cached Flutter version
  String? _flutterVersion;

  /// Get Flutter version string
  Future<String> getFlutterVersion() async {
    if (_flutterVersion != null) return _flutterVersion!;

    try {
      final result = await Process.run('flutter', ['--version', '--machine']);
      if (result.exitCode == 0) {
        try {
          final json = jsonDecode(result.stdout as String);
          _flutterVersion =
              json['frameworkVersion'] as String? ?? 'unknown';
        } catch (_) {
          // Try parsing plain text output
          final output = result.stdout as String;
          final match =
              RegExp(r'Flutter\s+(\S+)').firstMatch(output);
          _flutterVersion = match?.group(1) ?? 'unknown';
        }
      } else {
        _flutterVersion = 'unknown';
      }
    } catch (e) {
      _flutterVersion = 'not found';
    }
    return _flutterVersion!;
  }

  /// Check if Flutter SDK is available on the system
  Future<bool> isFlutterAvailable() async {
    try {
      final result =
          await Process.run('flutter', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Create a new Flutter project.
  ///
  /// Runs `flutter create <name>` in the specified [workingDir].
  /// Returns the path to the created project directory.
  Future<String> createProject({
    required String name,
    required String workingDir,
  }) async {
    // Defensive validation -- CommandParser already validates, but guard
    // against direct callers that might bypass the parser.
    if (!_validProjectName.hasMatch(name)) {
      throw FlutterControllerException(
        'Invalid project name "$name". '
        'Must match [a-z][a-z0-9_]* (lowercase, start with letter).',
        ErrorCode.parseError,
      );
    }

    onStateChange?.call(AgentState.building, 'Creating project $name...');
    onLog?.call('Running: flutter create $name');

    final result = await Process.run(
      'flutter',
      ['create', name],
      workingDirectory: workingDir,
    );

    if (result.exitCode != 0) {
      final stderr = result.stderr as String;
      onLog?.call('Error: $stderr');
      onStateChange?.call(AgentState.error, 'Failed to create project');
      throw FlutterControllerException(
        'flutter create failed: $stderr',
        ErrorCode.buildFailed,
      );
    }

    final stdout = result.stdout as String;
    for (final line in stdout.split('\n')) {
      if (line.trim().isNotEmpty) {
        onLog?.call(line.trim());
      }
    }

    final projectPath = '$workingDir/$name';
    onLog?.call('Project created at $projectPath');
    return projectPath;
  }

  /// Run `flutter run` in the given project directory.
  ///
  /// Starts the Flutter app on the connected emulator/device.
  /// Captures stdout/stderr and streams log lines via [onLog].
  Future<void> runProject({required String projectPath}) async {
    if (_flutterProcess != null) {
      throw FlutterControllerException(
        'Flutter is already running',
        ErrorCode.projectAlreadyRunning,
      );
    }

    onStateChange?.call(AgentState.building, 'Starting flutter run...');
    onLog?.call('Running: flutter run in $projectPath');

    _flutterProcess = await Process.start(
      'flutter',
      ['run'],
      workingDirectory: projectPath,
    );

    // Monitor stdout
    _stdoutSub = _flutterProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      onLog?.call(line);
      _handleFlutterOutput(line);
    });

    // Monitor stderr
    _stderrSub = _flutterProcess!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      onLog?.call('[stderr] $line');
      if (line.contains('Error') || line.contains('error')) {
        onStateChange?.call(AgentState.buildError, line);
      }
    });

    // Monitor process exit
    _flutterProcess!.exitCode.then((exitCode) {
      onLog?.call('Flutter process exited with code $exitCode');
      _cleanup();
      if (exitCode != 0) {
        onStateChange?.call(
            AgentState.error, 'Flutter process exited with code $exitCode');
      } else {
        onStateChange?.call(AgentState.idle, 'Flutter process stopped');
      }
    });
  }

  /// Handle flutter output to detect state transitions
  void _handleFlutterOutput(String line) {
    // Detect successful build completion
    if (line.contains('Syncing files to device') ||
        line.contains('Flutter run key commands') ||
        line.contains('An Observatory debugger')) {
      onStateChange?.call(AgentState.running, 'Flutter app is running');
    }

    // Detect hot reload success
    if (line.contains('Reloaded') &&
        line.contains('source') &&
        line.contains('ms')) {
      onStateChange?.call(AgentState.running, 'Hot reload complete');
    }

    // Detect hot restart success
    if (line.contains('Restarted application')) {
      onStateChange?.call(AgentState.running, 'Hot restart complete');
    }

    // Detect build errors
    if (line.contains('Error:') || line.contains('FAILURE')) {
      onStateChange?.call(AgentState.buildError, line);
    }

    // Detect compilation errors
    if (line.contains('Compiler message:') ||
        line.contains('lib/') && line.contains('Error')) {
      onStateChange?.call(AgentState.buildError, line);
    }
  }

  /// Trigger hot reload by sending 'r' to the flutter process stdin.
  Future<void> hotReload() async {
    if (_flutterProcess == null) {
      throw FlutterControllerException(
        'No Flutter process running',
        ErrorCode.projectNotFound,
      );
    }

    onStateChange?.call(AgentState.hotReloading, 'Performing hot reload...');
    onLog?.call('Triggering hot reload...');
    _flutterProcess!.stdin.write('r');
    await _flutterProcess!.stdin.flush();

    // Give hot reload a moment to process
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Trigger hot restart by sending 'R' to the flutter process stdin.
  Future<void> hotRestart() async {
    if (_flutterProcess == null) {
      throw FlutterControllerException(
        'No Flutter process running',
        ErrorCode.projectNotFound,
      );
    }

    onStateChange?.call(
        AgentState.hotRestarting, 'Performing hot restart...');
    onLog?.call('Triggering hot restart...');
    _flutterProcess!.stdin.write('R');
    await _flutterProcess!.stdin.flush();

    // Give hot restart a moment to process
    await Future.delayed(const Duration(seconds: 1));
  }

  /// Stop the running Flutter process.
  Future<void> stop() async {
    if (_flutterProcess != null) {
      onLog?.call('Stopping Flutter process...');
      // Send 'q' to quit gracefully
      _flutterProcess!.stdin.write('q');
      await _flutterProcess!.stdin.flush();

      // Wait a moment for graceful shutdown
      await Future.delayed(const Duration(seconds: 2));

      // Force kill if still running
      if (_flutterProcess != null) {
        _flutterProcess!.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(seconds: 1));
        _flutterProcess?.kill(ProcessSignal.sigkill);
      }

      _cleanup();
      onStateChange?.call(AgentState.idle, 'Flutter process stopped');
    }
  }

  /// Clean up subscriptions and process reference
  void _cleanup() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _flutterProcess = null;
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await stop();
  }
}

/// Exception thrown by [FlutterController] operations.
class FlutterControllerException implements Exception {
  final String message;
  final String errorCode;

  const FlutterControllerException(this.message, this.errorCode);

  @override
  String toString() => 'FlutterControllerException($errorCode): $message';
}
