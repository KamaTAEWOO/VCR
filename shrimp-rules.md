# VCR Development Guidelines

## Project Overview

- **Purpose**: VCR (Vibe Code Runner) - Phone-to-laptop Flutter development system
- **Architecture**: Smartphone App (Flutter) <-> WebSocket <-> Laptop Agent (Dart CLI)
- **Tech Stack**: Flutter 3.9+, Dart 3.9+, Provider 6.1, WebSocket, mDNS

## Project Architecture

### Monorepo Structure

| Directory | Package | Role |
|-----------|---------|------|
| `lib/` | VCR App | Flutter mobile app (smartphone) |
| `vcr_agent/` | VCR Agent | Dart CLI (laptop/notebook) |
| `shared/` | vcr_shared | Pure Dart shared models/protocol |

### App Directory Layout (`lib/`)

| Path | Purpose |
|------|---------|
| `lib/main.dart` | App entry point |
| `lib/app.dart` | MultiProvider + routes + theme |
| `lib/core/constants.dart` | Network/UI constants |
| `lib/core/theme.dart` | VcrColors, VcrTypography, vcrDarkTheme |
| `lib/models/` | App-specific data models |
| `lib/providers/` | ChangeNotifier providers |
| `lib/screens/` | Full-page screens |
| `lib/services/` | WebSocket + discovery services |
| `lib/widgets/` | Reusable UI components |

### Agent Directory Layout (`vcr_agent/`)

| Path | Purpose |
|------|---------|
| `bin/vcr_agent.dart` | CLI entry + command handler wiring |
| `lib/server/websocket_server.dart` | WebSocket server (shelf) |
| `lib/server/mdns_service.dart` | mDNS registration |
| `lib/parser/command_parser.dart` | Regex-based command parsing |
| `lib/parser/command_types.dart` | Sealed class command hierarchy |
| `lib/flutter/` | Flutter process control, code gen |
| `lib/emulator/` | ADB emulator + screen capture |

### Shared Package Layout (`shared/lib/`)

| Path | Purpose |
|------|---------|
| `protocol.dart` | MessageType, ResponseStatus, ErrorCode, ConnectionDefaults |
| `commands.dart` | VcrCommands (command constants + help text) |
| `models/vcr_message.dart` | VcrMessage (envelope for all messages) |
| `models/vcr_command.dart` | VcrCommand payload |
| `models/vcr_response.dart` | VcrResponse payload |
| `models/agent_state.dart` | AgentState enum |
| `models/frame_data.dart` | FrameData (JPEG base64) |
| `models/welcome_data.dart` | WelcomeData (handshake info) |

## Key File Interaction Rules

### Adding a New Message Type

1. Add constant to `shared/lib/protocol.dart` → `MessageType` class + `allTypes` list
2. Create payload model in `shared/lib/models/`
3. Update `lib/services/websocket_service.dart` → `_onMessage` handler
4. Update `vcr_agent/lib/server/websocket_server.dart` → `_handleMessage`

### Adding a New Command

1. Add constant to `shared/lib/commands.dart` → `VcrCommands` class + `helpText` + `availableCommands`
2. Add sealed class variant to `vcr_agent/lib/parser/command_types.dart`
3. Add regex pattern to `vcr_agent/lib/parser/command_parser.dart`
4. Add switch case to `vcr_agent/bin/vcr_agent.dart` → `_handleCommand`
5. Implement handler function in `vcr_agent/bin/vcr_agent.dart`

### Adding a New Screen

1. Create screen file in `lib/screens/`
2. Register route in `lib/app.dart` → `routes:` map
3. Add navigation calls from relevant screens

### Adding a New Provider

1. Create provider class extending `ChangeNotifier` in `lib/providers/`
2. Register in `lib/app.dart` → `MultiProvider.providers` list
3. Initialize in `_VcrAppState.initState()`
4. Dispose in `_VcrAppState.dispose()`
5. If WebSocketService needs it, add to constructor params in `lib/app.dart`

### Adding a New Widget

- Create in `lib/widgets/`
- Use `VcrColors` and `VcrTypography` for styling
- Consume providers via `context.watch<T>()` or `context.read<T>()`

## Code Standards

### Naming

- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables/methods**: `camelCase`
- **Constants**: `camelCase` (Dart convention)
- **Private members**: prefix with `_`

### State Management

- **Use Provider exclusively** - do NOT introduce Riverpod, Bloc, GetX, or other state management
- Providers extend `ChangeNotifier`
- Call `notifyListeners()` after state mutations
- Access in widgets: `context.watch<T>()` (rebuild) or `context.read<T>()` (one-time)

### Theme & Styling

- **Use `VcrColors.*`** for all colors - NEVER hardcode color values
- **Use `VcrTypography.*`** for text styles
- **Use `vcrDarkTheme`** as the only theme (dark mode only)
- Terminal text MUST use monospace font via `VcrTypography.terminalText`

### WebSocket Protocol

- All messages use `VcrMessage` envelope: `{ type, id?, payload }`
- Message types defined in `MessageType` class (shared)
- Response statuses: success, error, warning
- Error codes defined in `ErrorCode` class
- **Maintain backward compatibility** when changing protocol

## Prohibited Actions

- **DO NOT** add Flutter dependencies to `shared/` package (must remain pure Dart)
- **DO NOT** import `vcr_agent/` from `lib/` or vice versa (communicate only via WebSocket)
- **DO NOT** hardcode IP addresses or ports (use `ConnectionDefaults` from shared)
- **DO NOT** use `print()` for logging in the app (use TerminalProvider entries)
- **DO NOT** modify WebSocket message structure without updating both App and Agent handlers
- **DO NOT** add platform-specific code without conditional imports
- **DO NOT** bypass Provider for state management (no global variables or singletons)

## AI Decision Standards

### When adding new features:

1. Determine if it affects App, Agent, or both
2. If protocol change needed → update shared first, then both sides
3. If UI-only → modify App (lib/) only
4. If server-only → modify Agent (vcr_agent/) only

### When choosing where to put code:

- Shared types/constants → `shared/lib/`
- UI components → `lib/widgets/`
- Business logic → `lib/providers/` (App) or `vcr_agent/lib/` (Agent)
- WebSocket handling → `lib/services/` (App) or `vcr_agent/lib/server/` (Agent)

### Priority order for modifications:

1. `shared/` (protocol/models) → ensures both sides stay in sync
2. `vcr_agent/` (server logic) → backend first
3. `lib/` (app UI/logic) → frontend last
