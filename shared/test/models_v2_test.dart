import 'package:test/test.dart';
import 'package:vcr_shared/models/welcome_data.dart';
import 'package:vcr_shared/models/shell_output_data.dart';

void main() {
  group('WelcomeData.shellActive', () {
    test('fromJson parses shell_active field', () {
      final json = {
        'payload': {
          'agent_version': '0.2.0',
          'flutter_version': '3.24.0',
          'commands': <String>[],
          'shell_active': true,
        },
      };
      final data = WelcomeData.fromJson(json);
      expect(data.shellActive, isTrue);
    });

    test('fromJson defaults shell_active to false when missing', () {
      final json = {
        'payload': {
          'agent_version': '0.2.0',
          'flutter_version': '3.24.0',
          'commands': <String>[],
        },
      };
      final data = WelcomeData.fromJson(json);
      expect(data.shellActive, isFalse);
    });

    test('toMessage includes shell_active in payload', () {
      const data = WelcomeData(
        agentVersion: '0.2.0',
        flutterVersion: '3.24.0',
        commands: [],
        shellActive: true,
      );
      final msg = data.toMessage();
      expect(msg.payload['shell_active'], isTrue);
    });

    test('toMessage includes shell_active false by default', () {
      const data = WelcomeData(
        agentVersion: '0.2.0',
        flutterVersion: '3.24.0',
        commands: [],
      );
      final msg = data.toMessage();
      expect(msg.payload['shell_active'], isFalse);
    });

    test('round-trip serialization preserves shellActive', () {
      const original = WelcomeData(
        agentVersion: '0.2.0',
        flutterVersion: '3.24.0',
        commands: ['status', 'help'],
        shellActive: true,
        projectName: 'my_app',
      );
      final json = original.toJson();
      final restored = WelcomeData.fromJson(json);
      expect(restored.shellActive, original.shellActive);
      expect(restored.agentVersion, original.agentVersion);
      expect(restored.projectName, original.projectName);
    });
  });

  group('ShellOutputData.isHistory', () {
    test('fromJson parses is_history field', () {
      final json = {
        'payload': {
          'output': 'user@host:~\$ ',
          'stream': 'stdout',
          'is_history': true,
        },
      };
      final data = ShellOutputData.fromJson(json);
      expect(data.isHistory, isTrue);
      expect(data.output, 'user@host:~\$ ');
      expect(data.stream, 'stdout');
    });

    test('fromJson defaults is_history to false when missing', () {
      final json = {
        'payload': {
          'output': 'hello',
          'stream': 'stdout',
        },
      };
      final data = ShellOutputData.fromJson(json);
      expect(data.isHistory, isFalse);
    });

    test('toMessage includes is_history in payload', () {
      const data = ShellOutputData(
        output: 'buffered output',
        stream: 'stdout',
        isHistory: true,
      );
      final msg = data.toMessage();
      expect(msg.payload['is_history'], isTrue);
      expect(msg.payload['output'], 'buffered output');
    });

    test('round-trip serialization preserves isHistory', () {
      const original = ShellOutputData(
        output: 'test output',
        stream: 'stderr',
        isHistory: true,
      );
      final json = original.toJson();
      final restored = ShellOutputData.fromJson(json);
      expect(restored.isHistory, original.isHistory);
      expect(restored.output, original.output);
      expect(restored.stream, original.stream);
    });

    test('isStdout and isStderr helpers work correctly', () {
      const stdout = ShellOutputData(output: '', stream: 'stdout');
      const stderr = ShellOutputData(output: '', stream: 'stderr');
      expect(stdout.isStdout, isTrue);
      expect(stdout.isStderr, isFalse);
      expect(stderr.isStdout, isFalse);
      expect(stderr.isStderr, isTrue);
    });
  });
}
