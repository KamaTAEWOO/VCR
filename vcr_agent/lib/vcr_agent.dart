/// VCR Agent - The backend CLI that runs on the development machine.
///
/// Responsibilities:
/// - WebSocket server for communication with VCR App
/// - VCR command parsing and execution
/// - Flutter project creation and management
/// - Code generation (pages, widgets)
/// - Flutter process control (run, hot reload, hot restart)
/// - Emulator screen capture and streaming
library vcr_agent;

export 'server/websocket_server.dart';
export 'server/mdns_service.dart';
export 'network/ddns_service.dart';
export 'parser/command_parser.dart';
export 'parser/command_types.dart';
export 'flutter/flutter_controller.dart';
export 'flutter/code_generator.dart';
export 'flutter/project_manager.dart';
export 'emulator/screen_capture.dart';
export 'emulator/emulator_controller.dart';
export 'emulator/device_controller.dart';
