import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:vcr_shared/vcr_shared.dart';

import 'package:vcr_agent/server/websocket_server.dart';
import 'package:vcr_agent/server/mdns_service.dart';
import 'package:vcr_agent/parser/command_parser.dart';
import 'package:vcr_agent/parser/command_types.dart';
import 'package:vcr_agent/flutter/flutter_controller.dart';
import 'package:vcr_agent/flutter/code_generator.dart';
import 'package:vcr_agent/flutter/project_manager.dart';
import 'package:vcr_agent/emulator/screen_capture.dart';
import 'package:vcr_agent/emulator/device_controller.dart';
import 'package:vcr_agent/shell/shell_manager.dart';

/// VCR Agent - The backend CLI that manages Flutter projects
/// and streams device screens to the VCR App.
///
/// Supports multiple Android and iOS devices simultaneously.
///
/// Usage:
///   dart run vcr_agent --port 9000 --project-dir /path/to/workspace
void main(List<String> args) async {
  // --- 1. CLI Argument Parsing ---
  final parser = ArgParser()
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: '${ConnectionDefaults.port}',
      help: 'WebSocket server port',
    )
    ..addOption(
      'project-dir',
      abbr: 'd',
      defaultsTo: Directory.current.path,
      help: 'Working directory for Flutter projects',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information',
    );

  final ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    _printBanner();
    print('Error: $e\n');
    print('Usage: dart run vcr_agent [options]\n');
    print(parser.usage);
    exit(1);
  }

  if (results.flag('help')) {
    _printBanner();
    print('Usage: dart run vcr_agent [options]\n');
    print(parser.usage);
    exit(0);
  }

  final port = int.tryParse(results.option('port')!) ?? ConnectionDefaults.port;
  final projectDir = results.option('project-dir')!;

  _printBanner();
  _log('Starting VCR Agent v${ConnectionDefaults.agentVersion}');
  _log('Working directory: $projectDir');
  _log('Port: $port');
  print('');

  // --- 2. Initialize Components ---
  final commandParser = CommandParser();
  final codeGenerator = CodeGenerator();
  final projectManager = ProjectManager();
  final flutterController = FlutterController();
  final deviceController = DeviceController();
  final webSocketServer = WebSocketServer(port: port);
  final mdnsService = MdnsService(port: port);
  final shellManager = ShellManager();

  // Current agent state
  var currentState = AgentState.idle;

  // Log collection for current command
  final commandLogs = <String>[];

  // --- Multi-device state ---
  /// Active screen captures: deviceId -> ScreenCapture
  final activeCaptures = <String, ScreenCapture>{};

  /// Current known device list
  var knownDevices = <DeviceInfo>[];

  /// Timer for periodic device re-scanning
  Timer? deviceScanTimer;

  // --- Wire up Flutter controller callbacks ---
  flutterController.onLog = (line) {
    commandLogs.add(line);
    _log('[Flutter] $line');
  };

  flutterController.onStateChange = (state, message) {
    currentState = state;
    _log('[State] ${state.value}: ${message ?? ""}');
    webSocketServer.broadcastStatus(state, message: message);
  };

  // --- Wire up ShellManager callbacks ---
  shellManager.onOutput = (output, stream) {
    webSocketServer.broadcast(
      ShellOutputData(output: output, stream: stream).toMessage(),
    );
  };
  shellManager.onExit = (exitCode) {
    webSocketServer.broadcast(
      ShellExitData(exitCode: exitCode).toMessage(),
    );
  };
  shellManager.onForegroundProcessChanged = (processName, isAiTool) {
    webSocketServer.broadcast(
      ForegroundProcessData(
        processName: processName,
        isAiTool: isAiTool,
      ).toMessage(),
    );
  };

  // --- Wire up WebSocket shell input callback ---
  webSocketServer.onShellInput = (input, clientId) {
    shellManager.writeInput(input);
  };

  // --- Wire up WebSocket shell resize callback ---
  webSocketServer.onShellResize = (columns, rows, clientId) {
    shellManager.resize(columns, rows);
  };

  // --- Helper: Create and start a ScreenCapture for a device ---
  Future<void> startCaptureForDevice(DeviceInfo device) async {
    if (activeCaptures.containsKey(device.id)) return;

    final capture = ScreenCapture(
      device: device,
      deviceController: deviceController,
    );

    capture.onFrame = (frame) {
      webSocketServer.broadcastFrame(frame);
    };

    capture.onPause = (reason) {
      _log('[ScreenCapture] $reason');
      webSocketServer.broadcastStatus(AgentState.error, message: reason);
    };

    activeCaptures[device.id] = capture;

    try {
      await capture.start();
      _log('[ScreenCapture] Started capture for ${device.name} (${device.id})');
    } catch (e) {
      _log('[ScreenCapture] Failed to start capture for ${device.name}: $e');
      activeCaptures.remove(device.id);
    }
  }

  // --- Helper: Stop capture for a device ---
  void stopCaptureForDevice(String deviceId) {
    final capture = activeCaptures.remove(deviceId);
    if (capture != null) {
      capture.dispose();
      _log('[ScreenCapture] Stopped capture for $deviceId');
    }
  }

  // --- Helper: Build device list with capture status ---
  List<DeviceInfo> buildDeviceList(List<DeviceInfo> devices) {
    return devices.map((d) {
      final isCapturing = activeCaptures[d.id]?.isCapturing ?? false;
      return d.copyWith(isCapturing: isCapturing);
    }).toList();
  }

  // --- Helper: Broadcast device list to all clients ---
  void broadcastDevices() {
    final deviceList = buildDeviceList(knownDevices);
    final message = DeviceListData(devices: deviceList).toMessage();
    webSocketServer.broadcast(message);
  }

  // --- Helper: Detect devices and update captures ---
  Future<void> scanAndUpdateDevices() async {
    final devices = await deviceController.getConnectedDevices();
    final newDeviceIds = devices.map((d) => d.id).toSet();
    final oldDeviceIds = knownDevices.map((d) => d.id).toSet();

    // Detect newly connected devices
    for (final device in devices) {
      if (!oldDeviceIds.contains(device.id)) {
        _log('[Devices] New device detected: ${device.name} '
            '(${device.id}, ${device.platform})');
        // Auto-start capture for new devices if clients are connected
        if (webSocketServer.clientCount > 0) {
          await startCaptureForDevice(device);
        }
      }
    }

    // Detect disconnected devices
    for (final oldDevice in knownDevices) {
      if (!newDeviceIds.contains(oldDevice.id)) {
        _log('[Devices] Device disconnected: ${oldDevice.name} (${oldDevice.id})');
        stopCaptureForDevice(oldDevice.id);
      }
    }

    final changed = !_deviceListsEqual(knownDevices, devices);
    knownDevices = devices;

    // Broadcast updated device list if changed
    if (changed) {
      broadcastDevices();
    }
  }

  // --- Welcome data provider ---
  webSocketServer.welcomeDataProvider = () {
    return WelcomeData(
      agentVersion: ConnectionDefaults.agentVersion,
      projectName: projectManager.projectName,
      projectPath: projectManager.projectPath,
      flutterVersion: 'pending',
      commands: VcrCommands.availableCommands,
      shellActive: shellManager.isActive,
    );
  };

  // Initialize flutter version asynchronously
  flutterController.getFlutterVersion().then((version) {
    webSocketServer.welcomeDataProvider = () {
      return WelcomeData(
        agentVersion: ConnectionDefaults.agentVersion,
        projectName: projectManager.projectName,
        projectPath: projectManager.projectPath,
        flutterVersion: version,
        commands: VcrCommands.availableCommands,
        shellActive: shellManager.isActive,
      );
    };
  });

  // --- Client lifecycle callbacks ---
  webSocketServer.onClientConnected = (clientId) async {
    _log('Client connected: $clientId');

    // Auto-start shell if not already active
    if (!shellManager.isActive) {
      _log('Auto-starting shell for client $clientId');
      await shellManager.start();
    } else {
      // Send buffered output to the newly connected client
      final buffered = shellManager.getBufferedOutput();
      if (buffered.isNotEmpty) {
        _log('Sending ${buffered.length} chars of shell history to $clientId');
        webSocketServer.sendToClient(
          clientId,
          ShellOutputData(
            output: buffered,
            stream: 'stdout',
            isHistory: true,
          ).toMessage(),
        );
      }
    }

    // Send device list to newly connected client
    final deviceList = buildDeviceList(knownDevices);
    final devicesMessage = DeviceListData(devices: deviceList).toMessage();
    webSocketServer.sendToClient(clientId, devicesMessage);

    // Start capture for all known devices if this is the first client
    if (webSocketServer.clientCount == 1) {
      for (final device in knownDevices) {
        await startCaptureForDevice(device);
      }
      // Broadcast updated device list (capture status may have changed)
      broadcastDevices();
    }
  };

  webSocketServer.onClientDisconnected = (clientId) {
    _log('Client disconnected: $clientId');
    // Stop all screen captures if no clients remain
    if (webSocketServer.clientCount == 0) {
      _log('No clients connected, pausing all screen captures');
      for (final deviceId in activeCaptures.keys.toList()) {
        stopCaptureForDevice(deviceId);
      }
    }
  };

  // --- 3. Command Handler ---
  webSocketServer.onCommand = (command, clientId) async {
    return await _handleCommand(
      rawCommand: command.raw,
      commandParser: commandParser,
      codeGenerator: codeGenerator,
      projectManager: projectManager,
      flutterController: flutterController,
      deviceController: deviceController,
      activeCaptures: activeCaptures,
      knownDevices: knownDevices,
      webSocketServer: webSocketServer,
      projectDir: projectDir,
      commandLogs: commandLogs,
      getCurrentState: () => currentState,
      startCaptureForDevice: startCaptureForDevice,
      shellManager: shellManager,
    );
  };

  // --- 4. Start Server ---
  try {
    await webSocketServer.start();
  } catch (e) {
    _log('Failed to start WebSocket server: $e');
    exit(1);
  }

  // --- 5. Register mDNS (optional - don't fail if unavailable) ---
  final mdnsRegistered = await mdnsService.register();
  if (mdnsRegistered) {
    _log('mDNS service registered: _vcr._tcp on port $port');
  } else {
    _log('mDNS registration skipped (clients can connect via IP:$port)');
  }

  // --- Check Flutter availability ---
  final flutterAvailable = await flutterController.isFlutterAvailable();
  if (!flutterAvailable) {
    _log('WARNING: Flutter SDK not found in PATH!');
    _log('  "create project" and "flutter run" commands will not work.');
  } else {
    final version = await flutterController.getFlutterVersion();
    _log('Flutter SDK detected: $version');
  }

  // --- Initial device detection ---
  _log('Scanning for connected devices...');
  await scanAndUpdateDevices();

  if (knownDevices.isEmpty) {
    _log('No devices found. Connect Android or iOS devices for screen capture.');
  } else {
    _log('Found ${knownDevices.length} device(s):');
    for (final device in knownDevices) {
      _log('  [${device.platform}] ${device.name} (${device.id})');
    }
  }

  // --- Start periodic device scanning (every 10 seconds) ---
  deviceScanTimer = Timer.periodic(
    const Duration(seconds: 10),
    (_) => scanAndUpdateDevices(),
  );

  print('');
  _log('VCR Agent is ready. Waiting for connections...');
  _log('Press Ctrl+C to stop.');

  // --- Graceful Shutdown ---
  ProcessSignal.sigint.watch().listen((_) async {
    print('');
    _log('Shutting down...');
    deviceScanTimer?.cancel();
    for (final capture in activeCaptures.values) {
      capture.dispose();
    }
    activeCaptures.clear();
    shellManager.dispose();
    await flutterController.dispose();
    await mdnsService.dispose();
    await webSocketServer.stop();
    _log('Goodbye!');
    exit(0);
  });

  // Keep the process alive
  await Completer<void>().future;
}

/// Handle a parsed VCR command and return the appropriate response.
Future<VcrResponse> _handleCommand({
  required String rawCommand,
  required CommandParser commandParser,
  required CodeGenerator codeGenerator,
  required ProjectManager projectManager,
  required FlutterController flutterController,
  required DeviceController deviceController,
  required Map<String, ScreenCapture> activeCaptures,
  required List<DeviceInfo> knownDevices,
  required WebSocketServer webSocketServer,
  required String projectDir,
  required List<String> commandLogs,
  required AgentState Function() getCurrentState,
  required Future<void> Function(DeviceInfo) startCaptureForDevice,
  required ShellManager shellManager,
}) async {
  commandLogs.clear();
  _log('Command received: $rawCommand');

  // Parse the command
  final parseResult = commandParser.parse(rawCommand);
  if (parseResult.isError) {
    return VcrResponse.error(
      message: parseResult.errorMessage!,
      errorCode: parseResult.errorCode!,
    );
  }

  final command = parseResult.command!;

  try {
    switch (command) {
      // --- CMD-001: create project <name> ---
      case CreateProjectCommand(:final name):
        return await _handleCreateProject(
          name: name,
          projectDir: projectDir,
          projectManager: projectManager,
          flutterController: flutterController,
          codeGenerator: codeGenerator,
          deviceController: deviceController,
          activeCaptures: activeCaptures,
          knownDevices: knownDevices,
          commandLogs: commandLogs,
          startCaptureForDevice: startCaptureForDevice,
        );

      // --- CMD-002: create page <Name> ---
      case CreatePageCommand(:final name):
        return await _handleCreatePage(
          name: name,
          projectManager: projectManager,
          codeGenerator: codeGenerator,
          flutterController: flutterController,
          commandLogs: commandLogs,
        );

      // --- CMD-003: add button "<text>" ---
      case AddButtonCommand(:final text):
        return await _handleAddWidget(
          widgetType: 'Button',
          text: text,
          projectManager: projectManager,
          codeGenerator: codeGenerator,
          flutterController: flutterController,
          commandLogs: commandLogs,
          generateCode: () => codeGenerator.generateButtonCode(text),
          successMessage: "Button '$text' added",
        );

      // --- CMD-004: add text "<text>" ---
      case AddTextCommand(:final text):
        return await _handleAddWidget(
          widgetType: 'Text',
          text: text,
          projectManager: projectManager,
          codeGenerator: codeGenerator,
          flutterController: flutterController,
          commandLogs: commandLogs,
          generateCode: () => codeGenerator.generateTextCode(text),
          successMessage: "Text '$text' added",
        );

      // --- CMD-005: add image <url> ---
      case AddImageCommand(:final url):
        return await _handleAddWidget(
          widgetType: 'Image',
          text: url,
          projectManager: projectManager,
          codeGenerator: codeGenerator,
          flutterController: flutterController,
          commandLogs: commandLogs,
          generateCode: () => codeGenerator.generateImageCode(url),
          successMessage: 'Image added',
        );

      // --- CMD-006: hot reload ---
      case HotReloadCommand():
        if (!flutterController.isRunning) {
          return VcrResponse.error(
            message: 'No Flutter project running',
            errorCode: ErrorCode.projectNotFound,
          );
        }
        await flutterController.hotReload();
        return VcrResponse.success(
          message: 'Hot reload complete',
          logs: List.from(commandLogs),
        );

      // --- CMD-007: restart ---
      case RestartCommand():
        if (!flutterController.isRunning) {
          return VcrResponse.error(
            message: 'No Flutter project running',
            errorCode: ErrorCode.projectNotFound,
          );
        }
        await flutterController.hotRestart();
        return VcrResponse.success(
          message: 'Hot restart complete',
          logs: List.from(commandLogs),
        );

      // --- CMD-008: status ---
      case StatusCommand():
        return await _handleStatus(
          projectManager: projectManager,
          flutterController: flutterController,
          activeCaptures: activeCaptures,
          knownDevices: knownDevices,
          webSocketServer: webSocketServer,
          deviceController: deviceController,
          getCurrentState: getCurrentState,
        );

      // --- CMD-009: help ---
      case HelpCommand():
        return _handleHelp();

      // --- CMD-010: shell ---
      case ShellCommand():
        if (shellManager.isActive) {
          return VcrResponse.warning(id: rawCommand, message: 'Shell is already running');
        }
        await shellManager.start();
        return VcrResponse.success(id: rawCommand, message: 'Shell started');

      // --- CMD-011: shell stop ---
      case ShellStopCommand():
        if (!shellManager.isActive) {
          return VcrResponse.warning(id: rawCommand, message: 'Shell is not running');
        }
        await shellManager.stop();
        return VcrResponse.success(id: rawCommand, message: 'Shell stopped');
    }
  } on FlutterControllerException catch (e) {
    return VcrResponse.error(
      message: e.message,
      errorCode: e.errorCode,
      logs: List.from(commandLogs),
    );
  } on CodeGeneratorException catch (e) {
    return VcrResponse.error(
      message: e.message,
      errorCode: e.errorCode,
      logs: List.from(commandLogs),
    );
  } catch (e) {
    return VcrResponse.error(
      message: 'Unexpected error: $e',
      errorCode: ErrorCode.parseError,
      logs: List.from(commandLogs),
    );
  }
}

/// Handle `create project <name>` command.
Future<VcrResponse> _handleCreateProject({
  required String name,
  required String projectDir,
  required ProjectManager projectManager,
  required FlutterController flutterController,
  required CodeGenerator codeGenerator,
  required DeviceController deviceController,
  required Map<String, ScreenCapture> activeCaptures,
  required List<DeviceInfo> knownDevices,
  required List<String> commandLogs,
  required Future<void> Function(DeviceInfo) startCaptureForDevice,
}) async {
  // Check if a project is already running
  if (flutterController.isRunning) {
    return VcrResponse.error(
      message: 'A project is already running. Stop it first.',
      errorCode: ErrorCode.projectAlreadyRunning,
    );
  }

  // Check if Flutter is available
  if (!await flutterController.isFlutterAvailable()) {
    return VcrResponse.error(
      message: 'Flutter SDK not found in PATH',
      errorCode: ErrorCode.flutterNotFound,
    );
  }

  commandLogs.add('Creating Flutter project "$name"...');

  // 1. Run flutter create
  final projectPath = await flutterController.createProject(
    name: name,
    workingDir: projectDir,
  );
  commandLogs.add('Project created at $projectPath');

  // 2. Overwrite main.dart with a clean routes-based template
  final mainDartContent = codeGenerator.generateMainDart(projectName: name);
  await File('$projectPath/lib/main.dart').writeAsString(mainDartContent);
  commandLogs.add('Initialized main.dart with route support');

  // 3. Set project in manager
  projectManager.setProject(name: name, path: projectPath);

  // 4. Run flutter run
  commandLogs.add('Starting flutter run...');
  await flutterController.runProject(projectPath: projectPath);

  // 5. Start screen capture for all connected devices
  if (knownDevices.isNotEmpty) {
    for (final device in knownDevices) {
      try {
        await startCaptureForDevice(device);
        commandLogs.add('Screen capture started for ${device.name}');
      } catch (e) {
        commandLogs.add('Screen capture unavailable for ${device.name}: $e');
      }
    }
  } else {
    commandLogs.add('No devices detected - screen capture skipped');
  }

  return VcrResponse.success(
    message: 'Project $name created and running',
    logs: List.from(commandLogs),
  );
}

/// Handle `create page <Name>` command.
Future<VcrResponse> _handleCreatePage({
  required String name,
  required ProjectManager projectManager,
  required CodeGenerator codeGenerator,
  required FlutterController flutterController,
  required List<String> commandLogs,
}) async {
  // Precondition: project must be active
  if (!projectManager.hasProject) {
    return VcrResponse.error(
      message: 'No project active. Run "create project <name>" first.',
      errorCode: ErrorCode.projectNotFound,
    );
  }

  final snakeName = CodeGenerator.toSnakeCase(name);

  // Check if page already exists
  if (projectManager.pageFileExists(snakeName)) {
    return VcrResponse.error(
      message: 'Page "$name" already exists',
      errorCode: ErrorCode.fileError,
    );
  }

  // 1. Create page file
  commandLogs.add('Creating lib/pages/${snakeName}_page.dart...');
  final filePath = await codeGenerator.createPageFile(
    projectPath: projectManager.projectPath!,
    pageName: name,
  );
  commandLogs.add('Page file created');

  // 2. Update main.dart routes
  commandLogs.add('Updating lib/main.dart routes...');
  await codeGenerator.updateMainDartRoutes(
    projectPath: projectManager.projectPath!,
    pageName: name,
  );
  commandLogs.add('Routes updated');

  // 3. Set as current page
  projectManager.setCurrentPage(name: name, filePath: filePath);
  commandLogs.add('Active page set to $name');

  // 4. Trigger hot reload if Flutter is running
  if (flutterController.isRunning) {
    commandLogs.add('Triggering hot reload...');
    await flutterController.hotReload();
    commandLogs.add('Hot reload triggered');
  }

  return VcrResponse.success(
    message: 'Page $name created',
    logs: List.from(commandLogs),
  );
}

/// Handle `add button/text/image` commands.
Future<VcrResponse> _handleAddWidget({
  required String widgetType,
  required String text,
  required ProjectManager projectManager,
  required CodeGenerator codeGenerator,
  required FlutterController flutterController,
  required List<String> commandLogs,
  required String Function() generateCode,
  required String successMessage,
}) async {
  // Precondition: project must be active with a current page
  if (!projectManager.hasProject) {
    return VcrResponse.error(
      message: 'No project active. Run "create project <name>" first.',
      errorCode: ErrorCode.projectNotFound,
    );
  }

  if (!projectManager.hasCurrentPage) {
    return VcrResponse.error(
      message: 'No active page. Run "create page <Name>" first.',
      errorCode: ErrorCode.fileError,
    );
  }

  final widgetCode = generateCode();
  final filePath = projectManager.currentPageFile!;

  commandLogs.add('Adding $widgetType to ${projectManager.currentPage}...');

  // Insert widget into page file
  await codeGenerator.insertWidget(
    filePath: filePath,
    widgetCode: widgetCode,
  );
  commandLogs.add('$widgetType added to page');

  // Trigger hot reload if Flutter is running
  if (flutterController.isRunning) {
    commandLogs.add('Triggering hot reload...');
    await flutterController.hotReload();
    commandLogs.add('Hot reload triggered');
  }

  return VcrResponse.success(
    message: successMessage,
    logs: List.from(commandLogs),
  );
}

/// Handle `status` command.
Future<VcrResponse> _handleStatus({
  required ProjectManager projectManager,
  required FlutterController flutterController,
  required Map<String, ScreenCapture> activeCaptures,
  required List<DeviceInfo> knownDevices,
  required WebSocketServer webSocketServer,
  required DeviceController deviceController,
  required AgentState Function() getCurrentState,
}) async {
  final statusInfo = projectManager.getStatusInfo();
  final state = getCurrentState();

  final lines = <String>[
    'Agent State: ${state.value}',
    'Project: ${statusInfo['project_name'] ?? 'None'}',
    'Project Path: ${statusInfo['project_path'] ?? 'N/A'}',
    'Flutter Running: ${flutterController.isRunning}',
    'Current Page: ${statusInfo['current_page'] ?? 'None'}',
    'Pages: ${(statusInfo['pages'] as List).join(', ')}',
    'Connected Clients: ${webSocketServer.clientCount}',
    'Devices (${knownDevices.length}):',
  ];

  for (final device in knownDevices) {
    final capture = activeCaptures[device.id];
    final captureStatus = capture != null && capture.isCapturing
        ? 'capturing (seq: ${capture.frameSeq})'
        : 'idle';
    lines.add(
      '  [${device.platform}] ${device.name} (${device.id}) - $captureStatus',
    );
  }

  if (knownDevices.isEmpty) {
    lines.add('  No devices connected');
  }

  return VcrResponse.success(
    message: 'Agent status',
    logs: lines,
  );
}

/// Handle `help` command.
VcrResponse _handleHelp() {
  final helpLines = <String>[
    'VCR Commands:',
    '',
    ...VcrCommands.helpText.values,
    '',
    'Examples:',
    '  create project my_app',
    '  create page Home',
    '  add button "Click Me"',
    '  add text "Hello World"',
    '  add image https://picsum.photos/200',
    '  hot reload',
    '  status',
  ];

  return VcrResponse.success(
    message: 'Available commands',
    logs: helpLines,
  );
}

/// Compare two device lists for equality (by id set).
bool _deviceListsEqual(List<DeviceInfo> a, List<DeviceInfo> b) {
  if (a.length != b.length) return false;
  final aIds = a.map((d) => d.id).toSet();
  final bIds = b.map((d) => d.id).toSet();
  return aIds.length == bIds.length && aIds.containsAll(bIds);
}

/// Print the VCR Agent ASCII banner.
void _printBanner() {
  print('''
 __     _______ ____
 \\ \\   / / ____|  _ \\
  \\ \\ / / |    | |_) |
   \\ V /| |    |  _ <
    \\ / | |____| |_) |
     \\/  \\_____|____/
  Vibe Code Runner - Agent v${ConnectionDefaults.agentVersion}
''');
}

/// Log with timestamp.
void _log(String message) {
  final timestamp = DateTime.now().toIso8601String().substring(11, 19);
  print('[$timestamp] $message');
}
