import 'dart:io';

import 'package:vcr_shared/vcr_shared.dart';

/// Generates Flutter code for VCR commands.
///
/// Handles:
/// - Page template generation (CMD-002)
/// - Widget insertion into existing pages (CMD-003, CMD-004, CMD-005)
/// - main.dart route table updates
/// - PascalCase to snake_case conversion
class CodeGenerator {
  /// Convert PascalCase name to snake_case.
  ///
  /// Examples:
  /// - `Home` -> `home`
  /// - `LoginForm` -> `login_form`
  /// - `MyHomePage` -> `my_home_page`
  static String toSnakeCase(String pascalCase) {
    final buffer = StringBuffer();
    for (int i = 0; i < pascalCase.length; i++) {
      final char = pascalCase[i];
      if (char.toUpperCase() == char &&
          char.toLowerCase() != char &&
          i > 0) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }

  /// Generate page file content from the template.
  ///
  /// Creates a StatelessWidget with a Scaffold containing an AppBar
  /// and a centered Column (ready for widget insertion).
  ///
  /// [name] should be PascalCase (e.g., "Home", "LoginForm").
  String generatePageTemplate(String name) {
    return '''import 'package:flutter/material.dart';

class ${name}Page extends StatelessWidget {
  const ${name}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$name')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [],
        ),
      ),
    );
  }
}
''';
  }

  /// Create a page file in the project.
  ///
  /// Creates `lib/pages/<snake_name>_page.dart` with the page template.
  /// Returns the created file path.
  Future<String> createPageFile({
    required String projectPath,
    required String pageName,
  }) async {
    final snakeName = toSnakeCase(pageName);
    final pagesDir = Directory('$projectPath/lib/pages');

    // Create pages directory if it doesn't exist
    if (!pagesDir.existsSync()) {
      await pagesDir.create(recursive: true);
    }

    final filePath = '${pagesDir.path}/${snakeName}_page.dart';
    final file = File(filePath);

    // Check if file already exists
    if (file.existsSync()) {
      throw CodeGeneratorException(
        'Page file already exists: $filePath',
        ErrorCode.fileError,
      );
    }

    // Write the page template
    final content = generatePageTemplate(pageName);
    await file.writeAsString(content);

    return filePath;
  }

  /// Update main.dart to add a route for the new page.
  ///
  /// Adds an import statement and a route entry to the MaterialApp routes.
  Future<void> updateMainDartRoutes({
    required String projectPath,
    required String pageName,
  }) async {
    final snakeName = toSnakeCase(pageName);
    final mainDartPath = '$projectPath/lib/main.dart';
    final mainFile = File(mainDartPath);

    if (!mainFile.existsSync()) {
      throw CodeGeneratorException(
        'main.dart not found at $mainDartPath',
        ErrorCode.fileError,
      );
    }

    var content = await mainFile.readAsString();

    // Add import if not already present
    final importLine =
        "import 'pages/${snakeName}_page.dart';";
    if (!content.contains(importLine)) {
      // Find the last import line and add after it
      final importPattern = RegExp(r"^import\s+'[^']+';", multiLine: true);
      final imports = importPattern.allMatches(content).toList();

      if (imports.isNotEmpty) {
        final lastImport = imports.last;
        final insertPos = lastImport.end;
        content = '${content.substring(0, insertPos)}\n$importLine${content.substring(insertPos)}';
      } else {
        // No imports found, add at the beginning
        content = '$importLine\n$content';
      }
    }

    // Check if routes map already exists in the file
    final routeEntry =
        "'/$snakeName': (context) => const ${pageName}Page(),";

    if (content.contains('routes:')) {
      // Routes map exists, add new route entry
      if (!content.contains(routeEntry)) {
        // Find the routes: { pattern and add entry inside
        final routesPattern = RegExp(r'routes:\s*\{');
        final routesMatch = routesPattern.firstMatch(content);
        if (routesMatch != null) {
          final insertPos = routesMatch.end;
          content =
              '${content.substring(0, insertPos)}\n        $routeEntry${content.substring(insertPos)}';
        }
      }
    } else {
      // No routes map, try to add one to MaterialApp
      // Look for MaterialApp( and add routes after it
      if (content.contains('MaterialApp(')) {
        // Replace the simple MaterialApp with one that has routes
        // First, check if we need to restructure the MaterialApp
        _addRoutesToMaterialApp(
          mainFile: mainFile,
          content: content,
          pageName: pageName,
          snakeName: snakeName,
          importLine: importLine,
        );
        return;
      }
    }

    await mainFile.writeAsString(content);
  }

  /// Restructure MaterialApp to include routes when none exist yet.
  Future<void> _addRoutesToMaterialApp({
    required File mainFile,
    required String content,
    required String pageName,
    required String snakeName,
    required String importLine,
  }) async {
    // For a fresh flutter create project, replace the entire main.dart
    // with a routes-based MaterialApp
    final newContent = '''import 'package:flutter/material.dart';
$importLine

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VCR App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/$snakeName',
      routes: {
        '/$snakeName': (context) => const ${pageName}Page(),
      },
    );
  }
}
''';

    await mainFile.writeAsString(newContent);
  }

  /// Generate the initial main.dart for a fresh VCR project.
  ///
  /// This is used after `create project` to set up a clean main.dart
  /// with a routes-based MaterialApp.
  String generateMainDart({required String projectName}) {
    return '''import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '$projectName',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Welcome to $projectName'),
        ),
      ),
      routes: {},
    );
  }
}
''';
  }

  /// Insert a widget into the current page's Column children list.
  ///
  /// Finds the `children:` keyword in the page file, locates the closing `]`,
  /// and inserts the widget code just before it.
  ///
  /// Also removes `const` from `children: const []` if present,
  /// since runtime widgets cannot be const.
  Future<void> insertWidget({
    required String filePath,
    required String widgetCode,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw CodeGeneratorException(
        'Page file not found: $filePath',
        ErrorCode.fileError,
      );
    }

    var content = await file.readAsString();
    final lines = content.split('\n');

    // Find the last "children:" line
    int childrenLineIndex = -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].contains('children:')) {
        childrenLineIndex = i;
        break;
      }
    }

    if (childrenLineIndex == -1) {
      throw CodeGeneratorException(
        'Could not find "children:" in $filePath',
        ErrorCode.fileError,
      );
    }

    // Remove 'const' from children: const [] if present
    if (lines[childrenLineIndex].contains('const [')) {
      lines[childrenLineIndex] =
          lines[childrenLineIndex].replaceFirst('const [', '[');
    } else if (lines[childrenLineIndex].contains('const[]')) {
      lines[childrenLineIndex] =
          lines[childrenLineIndex].replaceFirst('const[]', '[]');
    }

    // Find the closing ']' after the children line
    int closingBracketIndex = -1;
    int bracketCount = 0;
    bool foundOpenBracket = false;

    for (int i = childrenLineIndex; i < lines.length; i++) {
      for (int j = 0; j < lines[i].length; j++) {
        if (lines[i][j] == '[') {
          bracketCount++;
          foundOpenBracket = true;
        } else if (lines[i][j] == ']') {
          bracketCount--;
          if (foundOpenBracket && bracketCount == 0) {
            closingBracketIndex = i;
            break;
          }
        }
      }
      if (closingBracketIndex != -1) break;
    }

    if (closingBracketIndex == -1) {
      throw CodeGeneratorException(
        'Could not find closing "]" for children list in $filePath',
        ErrorCode.fileError,
      );
    }

    // Determine indentation (use the indentation of the closing bracket + 2 spaces)
    final closingLine = lines[closingBracketIndex];
    final baseIndent =
        closingLine.substring(0, closingLine.length - closingLine.trimLeft().length);
    final widgetIndent = '$baseIndent  ';

    // Indent the widget code
    final indentedWidget = widgetCode
        .split('\n')
        .map((line) => line.isEmpty ? line : '$widgetIndent$line')
        .join('\n');

    // Insert the widget code before the closing bracket
    if (childrenLineIndex == closingBracketIndex) {
      // children: [] is on a single line - split it
      final line = lines[childrenLineIndex];
      final openBracketPos = line.indexOf('[');
      final closeBracketPos = line.lastIndexOf(']');

      final before = line.substring(0, openBracketPos + 1);
      final existingContent =
          line.substring(openBracketPos + 1, closeBracketPos).trim();
      final after = line.substring(closeBracketPos);

      final newLines = <String>[before];
      if (existingContent.isNotEmpty) {
        newLines.add('$widgetIndent$existingContent');
      }
      newLines.add(indentedWidget);
      newLines.add('$baseIndent${after.trimLeft()}');

      lines.removeAt(childrenLineIndex);
      lines.insertAll(childrenLineIndex, newLines);
    } else {
      // Multi-line children - insert before the closing bracket line
      lines.insert(closingBracketIndex, indentedWidget);
    }

    await file.writeAsString(lines.join('\n'));
  }

  /// Escape special characters for embedding in a Dart single-quoted string.
  ///
  /// Handles `\` -> `\\`, `'` -> `\'`, `$` -> `\$` to prevent
  /// code injection via user-supplied text or URLs.
  static String _escapeDartString(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$');
  }

  /// Generate ElevatedButton widget code for `add button` command.
  String generateButtonCode(String text) {
    final escaped = _escapeDartString(text);
    return '''ElevatedButton(
  onPressed: () {},
  child: Text('$escaped'),
),''';
  }

  /// Generate Text widget code for `add text` command.
  String generateTextCode(String text) {
    final escaped = _escapeDartString(text);
    return '''Text(
  '$escaped',
  style: const TextStyle(fontSize: 16),
),''';
  }

  /// Generate Image.network widget code for `add image` command.
  String generateImageCode(String url) {
    final escaped = _escapeDartString(url);
    return '''Image.network(
  '$escaped',
  width: 200,
  errorBuilder: (context, error, stackTrace) =>
    const Icon(Icons.broken_image, size: 48),
),''';
  }
}

/// Exception thrown by [CodeGenerator] operations.
class CodeGeneratorException implements Exception {
  final String message;
  final String errorCode;

  const CodeGeneratorException(this.message, this.errorCode);

  @override
  String toString() => 'CodeGeneratorException($errorCode): $message';
}
