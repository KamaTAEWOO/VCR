/// VCR command type constants.
///
/// These represent the 9 commands available in the VCR command language.
class VcrCommands {
  VcrCommands._();

  static const String createProject = 'create_project';
  static const String createPage = 'create_page';
  static const String addButton = 'add_button';
  static const String addText = 'add_text';
  static const String addImage = 'add_image';
  static const String hotReload = 'hot_reload';
  static const String restart = 'restart';
  static const String status = 'status';
  static const String help = 'help';
  static const String shell = 'shell';

  /// Human-readable command syntax for help display
  static const Map<String, String> helpText = {
    createProject: 'create project <name>  - Create a new Flutter project',
    createPage: 'create page <Name>    - Create a new page (PascalCase)',
    addButton: 'add button "<text>"   - Add a button to current page',
    addText: 'add text "<text>"     - Add text to current page',
    addImage: 'add image <url>       - Add an image to current page',
    hotReload: 'hot reload             - Trigger hot reload',
    restart: 'restart                - Trigger hot restart',
    status: 'status                 - Show current agent status',
    help: 'help                   - Show this help message',
    shell: 'shell                  - Open/close system terminal',
  };

  /// All available command names for the welcome message
  static const List<String> availableCommands = [
    'create project',
    'create page',
    'add button',
    'add text',
    'add image',
    'hot reload',
    'restart',
    'status',
    'help',
    'shell',
  ];
}
