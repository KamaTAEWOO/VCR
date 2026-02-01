import 'package:test/test.dart';
import 'package:vcr_agent/shell/shell_manager.dart';

void main() {
  group('ShellManager buffer', () {
    late ShellManager manager;

    setUp(() {
      manager = ShellManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('getBufferedOutput returns empty string initially', () {
      expect(manager.getBufferedOutput(), isEmpty);
    });

    test('clearBuffer clears the buffer', () {
      // We can't directly call _appendToBuffer since it's private,
      // but we can test clearBuffer on an already-empty buffer.
      manager.clearBuffer();
      expect(manager.getBufferedOutput(), isEmpty);
    });

    test('maxBufferSize is 50KB', () {
      expect(ShellManager.maxBufferSize, equals(50 * 1024));
    });

    test('isActive returns false before start', () {
      expect(manager.isActive, isFalse);
    });
  });
}
