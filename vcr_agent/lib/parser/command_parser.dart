import 'package:vcr_shared/vcr_shared.dart';

import 'command_types.dart';

/// Parses raw VCR command strings into structured [ParsedCommand] objects.
///
/// Supports the 9 VCR commands defined in FEATURE_SPEC.md:
/// - `create project <name>`
/// - `create page <Name>`
/// - `add button "<text>"`
/// - `add text "<text>"`
/// - `add image <url>`
/// - `hot reload`
/// - `restart`
/// - `status`
/// - `help`
class CommandParser {
  // Regex patterns from FEATURE_SPEC.md

  /// CMD-001: `create project <name>` - name must start with lowercase letter,
  /// followed by lowercase letters, digits, or underscores
  static final RegExp _createProjectPattern =
      RegExp(r'^create\s+project\s+([a-z][a-z0-9_]*)$');

  /// CMD-002: `create page <Name>` - PascalCase (starts with uppercase)
  static final RegExp _createPagePattern =
      RegExp(r'^create\s+page\s+([A-Z][a-zA-Z0-9]*)$');

  /// CMD-003: `add button "<text>"` - text inside double quotes
  static final RegExp _addButtonPattern =
      RegExp(r'^add\s+button\s+"([^"]*)"$');

  /// CMD-004: `add text "<text>"` - text inside double quotes
  static final RegExp _addTextPattern =
      RegExp(r'^add\s+text\s+"([^"]*)"$');

  /// CMD-005: `add image <url>` - http or https URL
  static final RegExp _addImagePattern =
      RegExp(r'^add\s+image\s+(https?://\S+)$');

  /// CMD-006: `hot reload`
  static final RegExp _hotReloadPattern = RegExp(r'^hot\s+reload$');

  /// CMD-007: `restart`
  static final RegExp _restartPattern = RegExp(r'^restart$');

  /// CMD-008: `status`
  static final RegExp _statusPattern = RegExp(r'^status$');

  /// CMD-009: `help`
  static final RegExp _helpPattern = RegExp(r'^help$');

  /// CMD-010: `shell stop`
  static final RegExp _shellStopPattern = RegExp(r'^shell\s+stop$');

  /// CMD-011: `shell`
  static final RegExp _shellPattern = RegExp(r'^shell$');

  /// Parse a raw command string into a [ParseResult].
  ///
  /// The input is trimmed before parsing.
  /// Returns [ParseResult.success] with a [ParsedCommand] on match,
  /// or [ParseResult.error] with error details on failure.
  ParseResult parse(String raw) {
    final input = raw.trim();

    // Ignore empty input
    if (input.isEmpty) {
      return ParseResult.error(
        message: 'Empty command',
        errorCode: ErrorCode.parseError,
      );
    }

    // Try each pattern in order

    // CMD-001: create project <name>
    final createProjectMatch = _createProjectPattern.firstMatch(input);
    if (createProjectMatch != null) {
      return ParseResult.success(
        CreateProjectCommand(name: createProjectMatch.group(1)!),
      );
    }

    // CMD-002: create page <Name>
    final createPageMatch = _createPagePattern.firstMatch(input);
    if (createPageMatch != null) {
      return ParseResult.success(
        CreatePageCommand(name: createPageMatch.group(1)!),
      );
    }

    // CMD-003: add button "<text>"
    final addButtonMatch = _addButtonPattern.firstMatch(input);
    if (addButtonMatch != null) {
      return ParseResult.success(
        AddButtonCommand(text: addButtonMatch.group(1)!),
      );
    }

    // CMD-004: add text "<text>"
    final addTextMatch = _addTextPattern.firstMatch(input);
    if (addTextMatch != null) {
      return ParseResult.success(
        AddTextCommand(text: addTextMatch.group(1)!),
      );
    }

    // CMD-005: add image <url>
    final addImageMatch = _addImagePattern.firstMatch(input);
    if (addImageMatch != null) {
      return ParseResult.success(
        AddImageCommand(url: addImageMatch.group(1)!),
      );
    }

    // CMD-006: hot reload
    if (_hotReloadPattern.hasMatch(input)) {
      return ParseResult.success(HotReloadCommand());
    }

    // CMD-007: restart
    if (_restartPattern.hasMatch(input)) {
      return ParseResult.success(RestartCommand());
    }

    // CMD-008: status
    if (_statusPattern.hasMatch(input)) {
      return ParseResult.success(StatusCommand());
    }

    // CMD-009: help
    if (_helpPattern.hasMatch(input)) {
      return ParseResult.success(HelpCommand());
    }

    // CMD-010: shell stop (must match before shell)
    if (_shellStopPattern.hasMatch(input)) {
      return ParseResult.success(ShellStopCommand());
    }

    // CMD-011: shell
    if (_shellPattern.hasMatch(input)) {
      return ParseResult.success(ShellCommand());
    }

    // Check for partial matches to give better error messages
    if (input.startsWith('create project')) {
      return ParseResult.error(
        message:
            'Invalid project name. Use lowercase letters, digits, and underscores. '
            'Must start with a letter. Example: create project my_app',
        errorCode: ErrorCode.parseError,
      );
    }

    if (input.startsWith('create page')) {
      return ParseResult.error(
        message:
            'Invalid page name. Use PascalCase (start with uppercase letter). '
            'Example: create page HomePage',
        errorCode: ErrorCode.parseError,
      );
    }

    if (input.startsWith('add button')) {
      return ParseResult.error(
        message:
            'Invalid button command. Text must be enclosed in double quotes. '
            'Example: add button "Click Me"',
        errorCode: ErrorCode.parseError,
      );
    }

    if (input.startsWith('add text')) {
      return ParseResult.error(
        message:
            'Invalid text command. Text must be enclosed in double quotes. '
            'Example: add text "Hello World"',
        errorCode: ErrorCode.parseError,
      );
    }

    if (input.startsWith('add image')) {
      return ParseResult.error(
        message:
            'Invalid image URL. Must be a valid http or https URL. '
            'Example: add image https://example.com/photo.jpg',
        errorCode: ErrorCode.parseError,
      );
    }

    // Completely unknown command
    return ParseResult.error(
      message: 'Unknown command: $input. Type "help" for available commands.',
      errorCode: ErrorCode.unknownCommand,
    );
  }
}
