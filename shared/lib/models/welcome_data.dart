import 'vcr_message.dart';
import '../protocol.dart';

/// Welcome message sent from Server to Client immediately upon connection.
///
/// ```json
/// {
///   "type": "welcome",
///   "payload": {
///     "agent_version": "0.2.0",
///     "project_name": "my_app",
///     "project_path": "/Users/dev/projects/my_app",
///     "flutter_version": "3.24.0",
///     "commands": ["create project", "create page", ...],
///     "shell_active": true
///   }
/// }
/// ```
class WelcomeData {
  /// Agent version string
  final String agentVersion;

  /// Current project name (null if no project active)
  final String? projectName;

  /// Current project path (null if no project active)
  final String? projectPath;

  /// Flutter SDK version
  final String flutterVersion;

  /// List of available commands
  final List<String> commands;

  /// Whether a shell process is currently active on the agent
  final bool shellActive;

  const WelcomeData({
    required this.agentVersion,
    this.projectName,
    this.projectPath,
    required this.flutterVersion,
    required this.commands,
    this.shellActive = false,
  });

  factory WelcomeData.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    return WelcomeData(
      agentVersion: payload['agent_version'] as String? ?? '0.0.0',
      projectName: payload['project_name'] as String?,
      projectPath: payload['project_path'] as String?,
      flutterVersion: payload['flutter_version'] as String? ?? 'unknown',
      commands: (payload['commands'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      shellActive: payload['shell_active'] as bool? ?? false,
    );
  }

  factory WelcomeData.fromMessage(VcrMessage message) {
    return WelcomeData(
      agentVersion:
          message.payload['agent_version'] as String? ?? '0.0.0',
      projectName: message.payload['project_name'] as String?,
      projectPath: message.payload['project_path'] as String?,
      flutterVersion:
          message.payload['flutter_version'] as String? ?? 'unknown',
      commands: (message.payload['commands'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      shellActive: message.payload['shell_active'] as bool? ?? false,
    );
  }

  VcrMessage toMessage() {
    return VcrMessage(
      type: MessageType.welcome,
      payload: {
        'agent_version': agentVersion,
        'project_name': projectName,
        'project_path': projectPath,
        'flutter_version': flutterVersion,
        'commands': commands,
        'shell_active': shellActive,
      },
    );
  }

  Map<String, dynamic> toJson() => toMessage().toJson();

  @override
  String toString() =>
      'WelcomeData(agentVersion: $agentVersion, projectName: $projectName, flutterVersion: $flutterVersion, shellActive: $shellActive)';
}
