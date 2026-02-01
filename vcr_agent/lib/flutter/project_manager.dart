import 'dart:io';

/// Manages the state of the current Flutter project.
///
/// Tracks which project is active, which page is current,
/// and provides file read/write utilities.
class ProjectManager {
  /// Current project directory path
  String? _projectPath;

  /// Current project name
  String? _projectName;

  /// Currently active page name (PascalCase)
  String? _currentPage;

  /// Currently active page file path
  String? _currentPageFile;

  /// List of all created pages (PascalCase names)
  final List<String> _pages = [];

  // --- Getters ---

  String? get projectPath => _projectPath;
  String? get projectName => _projectName;
  String? get currentPage => _currentPage;
  String? get currentPageFile => _currentPageFile;
  List<String> get pages => List.unmodifiable(_pages);
  bool get hasProject => _projectPath != null;
  bool get hasCurrentPage => _currentPage != null && _currentPageFile != null;

  /// Set the active project.
  void setProject({required String name, required String path}) {
    _projectPath = path;
    _projectName = name;
    _currentPage = null;
    _currentPageFile = null;
    _pages.clear();
  }

  /// Set the currently active page.
  ///
  /// The active page is where `add *` commands will insert widgets.
  void setCurrentPage({required String name, required String filePath}) {
    _currentPage = name;
    _currentPageFile = filePath;
    if (!_pages.contains(name)) {
      _pages.add(name);
    }
  }

  /// Clear all project state (for when a project is stopped/closed).
  void clear() {
    _projectPath = null;
    _projectName = null;
    _currentPage = null;
    _currentPageFile = null;
    _pages.clear();
  }

  /// Check if a page file already exists.
  bool pageFileExists(String snakeName) {
    if (_projectPath == null) return false;
    final file = File('$_projectPath/lib/pages/${snakeName}_page.dart');
    return file.existsSync();
  }

  /// Get the file path for a page by its snake_case name.
  String getPageFilePath(String snakeName) {
    return '$_projectPath/lib/pages/${snakeName}_page.dart';
  }

  /// Get a human-readable status summary.
  Map<String, dynamic> getStatusInfo() {
    return {
      'project_name': _projectName,
      'project_path': _projectPath,
      'current_page': _currentPage,
      'current_page_file': _currentPageFile,
      'pages': _pages,
      'has_project': hasProject,
    };
  }

  @override
  String toString() {
    return 'ProjectManager('
        'project: $_projectName, '
        'path: $_projectPath, '
        'currentPage: $_currentPage, '
        'pages: $_pages)';
  }
}
