import 'package:vcr_shared/vcr_shared.dart';

/// Base class for all parsed VCR commands.
sealed class ParsedCommand {
  /// The command type constant from [VcrCommands]
  String get commandType;

  /// Human-readable description of what this command does
  String get description;
}

/// `create project <name>` - Create a new Flutter project
class CreateProjectCommand extends ParsedCommand {
  /// Project name (lowercase, underscores allowed)
  final String name;

  CreateProjectCommand({required this.name});

  @override
  String get commandType => VcrCommands.createProject;

  @override
  String get description => 'Create Flutter project "$name"';

  @override
  String toString() => 'CreateProjectCommand(name: $name)';
}

/// `create page <Name>` - Create a new page in the current project
class CreatePageCommand extends ParsedCommand {
  /// Page name in PascalCase
  final String name;

  CreatePageCommand({required this.name});

  @override
  String get commandType => VcrCommands.createPage;

  @override
  String get description => 'Create page "$name"';

  @override
  String toString() => 'CreatePageCommand(name: $name)';
}

/// `add button "<text>"` - Add a button widget to the current page
class AddButtonCommand extends ParsedCommand {
  /// Button label text
  final String text;

  AddButtonCommand({required this.text});

  @override
  String get commandType => VcrCommands.addButton;

  @override
  String get description => 'Add button "$text"';

  @override
  String toString() => 'AddButtonCommand(text: $text)';
}

/// `add text "<text>"` - Add a text widget to the current page
class AddTextCommand extends ParsedCommand {
  /// Text content
  final String text;

  AddTextCommand({required this.text});

  @override
  String get commandType => VcrCommands.addText;

  @override
  String get description => 'Add text "$text"';

  @override
  String toString() => 'AddTextCommand(text: $text)';
}

/// `add image <url>` - Add an image widget to the current page
class AddImageCommand extends ParsedCommand {
  /// Image URL (http or https)
  final String url;

  AddImageCommand({required this.url});

  @override
  String get commandType => VcrCommands.addImage;

  @override
  String get description => 'Add image from "$url"';

  @override
  String toString() => 'AddImageCommand(url: $url)';
}

/// `hot reload` - Trigger hot reload on the running Flutter process
class HotReloadCommand extends ParsedCommand {
  @override
  String get commandType => VcrCommands.hotReload;

  @override
  String get description => 'Hot reload';

  @override
  String toString() => 'HotReloadCommand()';
}

/// `restart` - Trigger hot restart on the running Flutter process
class RestartCommand extends ParsedCommand {
  @override
  String get commandType => VcrCommands.restart;

  @override
  String get description => 'Hot restart';

  @override
  String toString() => 'RestartCommand()';
}

/// `status` - Query current agent status
class StatusCommand extends ParsedCommand {
  @override
  String get commandType => VcrCommands.status;

  @override
  String get description => 'Show status';

  @override
  String toString() => 'StatusCommand()';
}

/// `help` - Show available commands
class HelpCommand extends ParsedCommand {
  @override
  String get commandType => VcrCommands.help;

  @override
  String get description => 'Show help';

  @override
  String toString() => 'HelpCommand()';
}

/// `shell` - Start an interactive shell session
class ShellCommand extends ParsedCommand {
  @override
  String get commandType => VcrCommands.shell;

  @override
  String get description => 'Start shell';

  @override
  String toString() => 'ShellCommand()';
}

/// `shell stop` - Stop the running shell session
class ShellStopCommand extends ParsedCommand {
  @override
  String get commandType => VcrCommands.shell;

  @override
  String get description => 'Stop shell';

  @override
  String toString() => 'ShellStopCommand()';
}

/// Result of command parsing - either a valid command or a parse error.
class ParseResult {
  /// The parsed command (null if parsing failed)
  final ParsedCommand? command;

  /// Error message (null if parsing succeeded)
  final String? errorMessage;

  /// Error code (null if parsing succeeded)
  final String? errorCode;

  const ParseResult._({
    this.command,
    this.errorMessage,
    this.errorCode,
  });

  factory ParseResult.success(ParsedCommand command) {
    return ParseResult._(command: command);
  }

  factory ParseResult.error({
    required String message,
    required String errorCode,
  }) {
    return ParseResult._(
      errorMessage: message,
      errorCode: errorCode,
    );
  }

  bool get isSuccess => command != null;
  bool get isError => command == null;

  @override
  String toString() {
    if (isSuccess) return 'ParseResult.success(${command!})';
    return 'ParseResult.error($errorCode: $errorMessage)';
  }
}
