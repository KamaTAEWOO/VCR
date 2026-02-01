import 'package:flutter_test/flutter_test.dart';
import 'package:vcr/providers/terminal_provider.dart';

void main() {
  group('TerminalProvider shell exit state', () {
    late TerminalProvider provider;
    int notifyCount = 0;

    setUp(() {
      provider = TerminalProvider();
      notifyCount = 0;
      provider.addListener(() => notifyCount++);
    });

    test('initial state: shellExited is false, shellExitCode is null', () {
      expect(provider.shellExited, isFalse);
      expect(provider.shellExitCode, isNull);
      expect(provider.shellActive, isFalse);
    });

    test('setShellActive(true) creates terminal and clears exit code', () {
      // First set an exit code
      provider.setShellExited(1);
      expect(provider.shellExited, isTrue);
      expect(provider.shellExitCode, 1);

      // Now re-activate
      provider.setShellActive(true);
      expect(provider.shellActive, isTrue);
      expect(provider.shellExited, isFalse);
      expect(provider.shellExitCode, isNull);
      expect(provider.shellTerminal, isNotNull);
    });

    test('setShellExited sets exit code and deactivates shell', () {
      provider.setShellActive(true);
      expect(provider.shellActive, isTrue);

      provider.setShellExited(0);
      expect(provider.shellActive, isFalse);
      expect(provider.shellExited, isTrue);
      expect(provider.shellExitCode, 0);
    });

    test('setShellExited with non-zero code', () {
      provider.setShellActive(true);
      provider.setShellExited(137);
      expect(provider.shellExitCode, 137);
      expect(provider.shellExited, isTrue);
      expect(provider.shellActive, isFalse);
    });

    test('setShellActive(false) nulls terminal but does not set exit code', () {
      provider.setShellActive(true);
      expect(provider.shellTerminal, isNotNull);

      provider.setShellActive(false);
      expect(provider.shellTerminal, isNull);
      expect(provider.shellActive, isFalse);
      // shellExitCode should still be null (not set via setShellExited)
      expect(provider.shellExitCode, isNull);
      expect(provider.shellExited, isFalse);
    });

    test('notifyListeners is called on setShellExited', () {
      provider.setShellExited(0);
      expect(notifyCount, 1);
    });

    test('notifyListeners is called on setShellActive', () {
      provider.setShellActive(true);
      expect(notifyCount, 1);
      provider.setShellActive(false);
      expect(notifyCount, 2);
    });

    test('shell terminal is reused when already active', () {
      provider.setShellActive(true);
      final terminal1 = provider.shellTerminal;
      // Calling setShellActive(true) again should reuse the terminal
      provider.setShellActive(true);
      final terminal2 = provider.shellTerminal;
      expect(identical(terminal1, terminal2), isTrue);
    });

    test('full lifecycle: activate -> exit -> restart', () {
      // Activate
      provider.setShellActive(true);
      expect(provider.shellActive, isTrue);
      expect(provider.shellExited, isFalse);

      // Exit
      provider.setShellExited(0);
      expect(provider.shellActive, isFalse);
      expect(provider.shellExited, isTrue);
      expect(provider.shellExitCode, 0);

      // Restart
      provider.setShellActive(true);
      expect(provider.shellActive, isTrue);
      expect(provider.shellExited, isFalse);
      expect(provider.shellExitCode, isNull);
      expect(provider.shellTerminal, isNotNull);
    });
  });
}
