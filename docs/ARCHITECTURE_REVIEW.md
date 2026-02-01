# VCR Architecture Review

> Tech Lead Review - Phase 4b
> Reviewed: 2026-01-31

---

## 1. Executive Summary

VCR (Vibe Code Runner) is a well-structured MVP with clear separation between the Flutter mobile app (lib/), the Dart CLI agent (vcr_agent/), and the shared protocol package (shared/). The overall architecture follows sound principles: unidirectional dependency flow, JSON-only WebSocket protocol, and ChangeNotifier-based state management.

**Overall Assessment: Good for MVP, with targeted improvements needed before Phase 2 features.**

| Category | Rating | Notes |
|----------|--------|-------|
| Dependency Direction | PASS | App -> shared, Agent -> shared. No cycles. |
| Shared Package Design | PARTIAL | Well-designed, but App does NOT use it yet. |
| Agent Module Separation | PASS | Clean 4-module split (server, parser, flutter, emulator). |
| Error Recovery | PARTIAL | WebSocket reconnect is solid; screen capture needs work. |
| Extensibility | GOOD | Command pattern and widget generation are extensible. |
| ADR Compliance | PARTIAL | ADR-001, ADR-003 followed; ADR-002 followed with minor delta. |
| Test Coverage | CRITICAL | Essentially zero meaningful test coverage. |

---

## 2. Dependency Analysis

### 2.1 Module Dependency Graph

```
vcr (Flutter App)
  |-- flutter SDK
  |-- provider ^6.1.0
  |-- web_socket_channel ^3.0.0
  |-- nsd ^2.2.0
  |-- vcr_shared (path: ./shared)      <-- declared but NOT imported in lib/

vcr_agent (Dart CLI)
  |-- shelf ^1.4.0
  |-- shelf_web_socket ^3.0.0
  |-- web_socket_channel ^3.0.0
  |-- args ^2.5.0
  |-- image ^4.2.0
  |-- vcr_shared (path: ../shared)     <-- actively imported in 7 files

vcr_shared (Pure Dart)
  |-- (no runtime dependencies)
```

### 2.2 Dependency Direction Verdict

**PASS** -- The intended dependency direction (App -> shared <- Agent) is correctly declared in both pubspec.yaml files. There are no circular dependencies between the three packages. The shared package has zero runtime dependencies, which is ideal.

### 2.3 Critical Finding: App Does NOT Import shared

The App's `pubspec.yaml` declares `vcr_shared` as a dependency (line 38-39), but **zero files under `lib/` import `package:vcr_shared/vcr_shared.dart`**. Instead, the App maintains its own local model copies:

| shared model | App local copy | Status |
|---|---|---|
| `shared/lib/models/agent_state.dart` | `lib/models/agent_state.dart` | DUPLICATED -- different implementation |
| `shared/lib/models/vcr_message.dart` | `lib/models/vcr_message.dart` | DUPLICATED -- different API surface |
| `shared/lib/models/vcr_response.dart` | `lib/models/vcr_response.dart` | DUPLICATED -- different factory methods |
| `shared/lib/models/frame_data.dart` | `lib/models/frame_data.dart` | DUPLICATED -- different field (bytes vs data) |
| `shared/lib/models/welcome_data.dart` | _(not present)_ | App parses welcome inline in WebSocketService |
| `shared/lib/protocol.dart` | `lib/core/constants.dart` (partial) | DUPLICATED -- values match but different class names |
| `shared/lib/commands.dart` | _(not present)_ | App does not reference command constants |

Each local copy has the comment: _"When shared package is ready, replace this with shared's definition."_ This migration was never completed. The Development Plan Phase 3 checklist confirms this: "App internal models <-> shared models compatibility confirmed (compatible)" is checked, but the actual integration tasks (WebSocket service <-> Terminal Screen, Frame decoding pipeline, etc.) remain unchecked.

**Impact**: Any protocol change must be duplicated in two places, defeating the purpose of the shared package. This is the highest priority item to address.

### 2.4 Specific Duplication Risks

**AgentState enum divergence:**
- `shared/lib/models/agent_state.dart` -- Uses enhanced enum with `value` field: `idle('idle')`. Has 7 states. No `disconnected` state.
- `lib/models/agent_state.dart` -- Uses plain enum with `fromString`/`toWireString` switch statements. Has 8 states including `disconnected`. Includes `label` and `isAnimating` getters.

The App's version has a `disconnected` state that does not exist in the shared model. This is a client-only state (valid design), but the divergent implementation pattern means the shared model cannot simply replace the App model without adding these UI-specific extensions.

**FrameData divergence:**
- `shared/lib/models/frame_data.dart` -- `data` field is `String` (base64).
- `lib/models/frame_data.dart` -- `bytes` field is `Uint8List` (decoded).

These represent different stages of the data pipeline (wire format vs. decoded). The App model is purpose-built for rendering. This is a legitimate design difference, but it means the shared model alone is insufficient for the App. The App needs either: (a) an extension/wrapper around the shared model, or (b) a separate presentation model that transforms from the shared model.

**VcrMessage divergence:**
- `shared/lib/models/vcr_message.dart` -- Basic `fromJson`/`toJson`.
- `lib/models/vcr_message.dart` -- Adds `fromRawJson`, `toRawJson`, `VcrMessage.command()`, `VcrMessage.ping()` factory constructors.

The App version has a richer API. These factory methods should ideally live in the shared model.

---

## 3. Extensibility Evaluation

### 3.1 Adding New Commands

**Verdict: EASY**

The command system is well-designed for extension:

1. `shared/lib/commands.dart` -- Add constant + help text + available commands entry.
2. `vcr_agent/lib/parser/command_types.dart` -- Add new `sealed class` subtype.
3. `vcr_agent/lib/parser/command_parser.dart` -- Add regex pattern + match case.
4. `vcr_agent/bin/vcr_agent.dart` -- Add `case NewCommand():` in the switch.

The use of Dart 3 sealed classes with pattern matching (`switch (command) { case CreateProjectCommand(:final name): ... }`) is excellent. The compiler enforces exhaustiveness, so adding a new sealed subtype will produce compile errors at every unhandled switch, guiding the developer to all necessary changes.

**Risk**: The `_handleCommand` function in `bin/vcr_agent.dart` (lines 221-374) is a 150-line top-level function. As commands grow, this should be refactored into a command handler registry or strategy pattern.

### 3.2 Adding New Widget Types

**Verdict: EASY**

The `add <widget>` pattern is generalized via `_handleAddWidget()` which accepts a `generateCode` callback:

```dart
case AddButtonCommand(:final text):
  return await _handleAddWidget(
    widgetType: 'Button',
    generateCode: () => codeGenerator.generateButtonCode(text),
    successMessage: "Button '$text' added",
    ...
  );
```

To add `add checkbox`, `add slider`, etc., one would:
1. Add a new command type and parser pattern.
2. Add a new `generateXxxCode()` method in `CodeGenerator`.
3. Add a new case in `_handleCommand` calling `_handleAddWidget` with the new generator.

The `insertWidget()` algorithm in `CodeGenerator` (lines 250-357) is widget-agnostic -- it simply inserts any Dart code string into the `children: []` list. This is a good abstraction.

**Risk**: The `insertWidget()` method uses a character-by-character bracket-counting algorithm to find the insertion point. This is fragile and could break with nested `children:` arrays or complex widget trees. For Phase 2, consider using the Dart `analyzer` package for AST-based code modification.

### 3.3 AI Code Generation (Phase 2)

**Verdict: MODERATE -- Requires new abstraction layer**

Currently, `CodeGenerator` produces hardcoded template strings. To support AI-generated code:

1. The `CodeGenerator` class would need a new strategy -- either a `generateFromPrompt()` method that calls an LLM API, or a separate `AiCodeGenerator` class.
2. The `_handleAddWidget` pattern already accepts any `String Function()` for code generation, so the insertion pipeline is reusable.
3. The `insertWidget()` method works with any Dart code string, so AI-generated code can be inserted with the same mechanism.

**Gap**: There is no abstraction layer for code generation strategies. The `CodeGenerator` class mixes template generation with file I/O operations (`createPageFile`, `updateMainDartRoutes`, `insertWidget`). Splitting these into a `CodeGenerationStrategy` (what to generate) and a `FileManager` (where to write) would make AI integration cleaner.

### 3.4 Multi-Project Support (Phase 2)

**Verdict: MODERATE -- Requires `ProjectManager` refactoring**

`ProjectManager` currently holds a single project state (one `_projectPath`, one `_currentPage`). Multi-project would require:

1. A map of project name -> project state.
2. A `switchProject(name)` command.
3. `FlutterController` would need to manage multiple flutter processes.

The current design does not prevent this, but `ProjectManager` and `FlutterController` would need significant refactoring. The monolithic `_handleCommand` function passes a single `projectManager` and `flutterController` -- these would need to become indexed by project ID.

### 3.5 Autocomplete (Phase 2)

**Verdict: EASY**

A new message type `autocomplete` (client -> server) with the partial input, and `autocomplete_response` (server -> client) with suggestions, could be added to the protocol without affecting existing message types. The `VcrCommands.availableCommands` list already provides the base data for autocomplete.

---

## 4. Error Recovery Evaluation

### 4.1 WebSocket Connection Loss Recovery

**Verdict: GOOD**

The App's `WebSocketService` implements a complete reconnection lifecycle:

```
Connection Lost
  -> _handleDisconnect()
  -> _stopPingTimer()
  -> _subscription.cancel()
  -> previewProvider.setAgentState(disconnected)
  -> connectionProvider.setDisconnected()
  -> _scheduleReconnect()
     -> Check attempts < maxReconnectAttempts (5)
     -> incrementReconnectAttempts()
     -> Wait reconnectDelay (5s)
     -> connect(host, port)
```

**Strengths:**
- Intentional disconnect (`_intentionalDisconnect` flag) correctly suppresses reconnection.
- Terminal shows reconnection progress: "Connection lost. Reconnecting in 5s (2/5)..."
- After max attempts, navigates back to ConnectionScreen (in `_VcrAppState._onConnectionChanged`).
- Cleanup is thorough: ping timer, reconnect timer, subscription, channel all cleaned up.

**Weakness:**
- After successful reconnect, the `welcome` message resets the state, but terminal history is preserved (good). However, there is no mechanism to resync the agent's current state (e.g., which project is running, which page is active). The App relies solely on the `welcome` message's `project_name` field, which may be stale.
- The `_onConnectionChanged` listener uses `pushNamedAndRemoveUntil('/')` which clears the navigation stack, but does not reset `TerminalProvider` entries. On re-connection, old terminal entries will be visible alongside new ones. This could be confusing.

### 4.2 Flutter Process Crash Recovery

**Verdict: PARTIAL**

In `FlutterController`:

```dart
_flutterProcess!.exitCode.then((exitCode) {
  onLog?.call('Flutter process exited with code $exitCode');
  _cleanup();
  if (exitCode != 0) {
    onStateChange?.call(AgentState.error, 'Flutter process exited with code $exitCode');
  } else {
    onStateChange?.call(AgentState.idle, 'Flutter process stopped');
  }
});
```

**Strengths:**
- Process exit is detected and state transitions to `error` or `idle`.
- Cleanup cancels stdout/stderr subscriptions and nulls the process reference.
- State change is broadcast to all connected clients via `webSocketServer.broadcastStatus`.

**Weaknesses:**
- **No automatic restart**: If `flutter run` crashes, the agent transitions to `error` state and stays there. The user must manually run `create project` again. There should be at minimum a `restart` path that re-runs `flutter run` in the existing project directory.
- **No process zombie protection**: The `stop()` method sends 'q', waits 2s, sends SIGTERM, waits 1s, then sends SIGKILL. However, `createProject` calls `flutterController.runProject()` which would throw `FlutterControllerException('Flutter is already running')` if `_flutterProcess` is not null. If the cleanup from a crash does not fire before a new `create project` command arrives, the agent could enter an inconsistent state. The `_cleanup()` method sets `_flutterProcess = null`, but the `exitCode.then` callback is asynchronous.
- **Screen capture is not stopped on crash**: In `bin/vcr_agent.dart`, `screenCapture` is stopped when the last client disconnects, but not when the Flutter process crashes. The screen capture will continue running (capturing the emulator home screen or error screen) until 3 consecutive failures pause it.

### 4.3 Screen Capture Failure Recovery

**Verdict: ADEQUATE for MVP**

In `ScreenCapture`:

```dart
void _handleFailure(String reason) {
  _failureCount++;
  if (_failureCount >= _maxConsecutiveFailures) {  // 3
    stop();
  }
}
```

**Strengths:**
- 3-failure threshold prevents continuous ADB hammering.
- Each successful capture resets the failure counter.
- `stop()` cleanly cancels the timer.

**Weaknesses:**
- **No automatic recovery**: Once paused, screen capture does not restart automatically. There is no periodic check to see if the emulator has come back. The user must send a command that triggers screen capture restart (currently only `create project` does this).
- **No failure notification to client**: When capture is paused due to failures, no `status` message is broadcast. The client simply stops receiving frames without explanation. The FPS counter drops to 0, but no error message appears in the terminal.
- **Silent failure logging**: `_handleFailure` does not call `_log()` or any callback. Failures are completely silent. This makes debugging difficult.

### 4.4 Agent-Side WebSocket Error Handling

**Verdict: GOOD**

The `WebSocketServer` handles client errors gracefully:
- Parse errors send an error response back to the client.
- Send failures trigger client removal via `_removeClient`.
- The `broadcast()` method collects failed sends and removes dead clients afterward, avoiding concurrent modification.

---

## 5. Improvement Recommendations (Priority Order)

### P0 -- CRITICAL (Block release)

#### 5.1 Migrate App to Use shared Package Models

**Files affected:** All files under `lib/models/`, `lib/services/websocket_service.dart`, `lib/providers/`

The App declares `vcr_shared` as a dependency but never imports it. The five duplicated model files (`agent_state.dart`, `vcr_message.dart`, `vcr_response.dart`, `frame_data.dart`, `terminal_entry.dart`) must be consolidated.

**Recommended approach:**
1. Extend `shared/lib/models/agent_state.dart` AgentState enum with a `disconnected` value (client-only state, harmless for Agent).
2. Move `fromRawJson`, `toRawJson`, `VcrMessage.command()`, `VcrMessage.ping()` from App's VcrMessage into the shared VcrMessage.
3. Keep `lib/models/frame_data.dart` as a **presentation model** that wraps/transforms `FrameData` from shared (Base64 string -> Uint8List bytes). Rename it to `DecodedFrame` to avoid confusion.
4. Keep `lib/models/terminal_entry.dart` in the App only (UI-specific, not shared).
5. Remove `lib/models/agent_state.dart`, `lib/models/vcr_message.dart`, `lib/models/vcr_response.dart`.
6. Update all imports in providers, services, and widgets.

**Effort estimate:** 2-4 hours.

#### 5.2 Add Core Unit Tests

**Files affected:** New test files in `vcr_agent/test/` and `test/`

The agent test directory is empty. The app has a single smoke test. For an MVP, at minimum:

- `vcr_agent/test/command_parser_test.dart` -- All 9 command patterns + error cases. This is pure logic, easy to test.
- `vcr_agent/test/code_generator_test.dart` -- Template generation + snake_case conversion.
- `shared/test/models_test.dart` -- Serialization round-trip for all models.

**Effort estimate:** 4-6 hours.

### P1 -- HIGH (Before Phase 2)

#### 5.3 Extract Command Handler from bin/vcr_agent.dart

The `_handleCommand` function (150+ lines) and all the `_handle*` helper functions (another 250+ lines) should be extracted into a `CommandHandler` class in `lib/`. The `bin/vcr_agent.dart` entry point should only contain initialization, wiring, and the event loop.

**Current problem:** The entry point file is 625 lines, mixing CLI argument parsing, component wiring, command routing, and individual command implementations. This makes unit testing impossible since `_handleCommand` and all helpers are private top-level functions.

**Recommended structure:**
```
vcr_agent/lib/
  command_handler.dart   <-- NEW: routes commands to handlers
  handlers/              <-- NEW: individual command handler classes
    create_project_handler.dart
    create_page_handler.dart
    add_widget_handler.dart
    ...
```

#### 5.4 Add Screen Capture Failure Notification

When `ScreenCapture` pauses due to consecutive failures, it should:
1. Log the failure reason.
2. Broadcast a `status` message with state `error` and a descriptive message.
3. Optionally, attempt to restart after a configurable delay.

#### 5.5 Add Flutter Process Crash Recovery

When `FlutterController` detects process exit:
1. If the project path is still known (`ProjectManager.hasProject`), offer automatic restart.
2. At minimum, broadcast a clear error status with instructions to the user.
3. Stop screen capture when Flutter process exits.

### P2 -- MEDIUM (Phase 2 preparation)

#### 5.6 Separate Code Generation Strategy from File I/O

Split `CodeGenerator` into:
- `WidgetTemplates` (pure functions returning code strings)
- `ProjectFileManager` (file read/write, route updates, widget insertion)

This separation enables AI code generation to plug in as an alternative `WidgetTemplates` implementation.

#### 5.7 Add Protocol Versioning

The `welcome` message includes `agent_version` but no `protocol_version`. As the protocol evolves (Phase 2 features), the client needs to know if it is compatible with the server's protocol version. Add a `protocol_version` field to the welcome message and shared constants.

#### 5.8 Consider Binary WebSocket Frames for Frames

ADR-002 correctly chose Base64 for MVP simplicity. However, the data path is:
```
PNG bytes -> decode -> JPEG encode -> Base64 string -> JSON serialize ->
WebSocket text frame -> JSON parse -> Base64 decode -> Image.memory render
```

This involves 4 transformations that could be reduced to 2 with binary frames:
```
PNG bytes -> decode -> JPEG encode ->
WebSocket binary frame -> Image.memory render
```

For Phase 2, this would significantly reduce CPU usage and latency, especially at higher frame rates.

### P3 -- LOW (Nice to have)

#### 5.9 NetworkConstants Duplication

`lib/core/constants.dart` defines `NetworkConstants` with values that duplicate `shared/lib/protocol.dart`'s `ConnectionDefaults`:

| App (NetworkConstants) | Shared (ConnectionDefaults) | Match? |
|---|---|---|
| `defaultPort = 8765` | `port = 8765` | Yes |
| `mdnsServiceType = '_vcr._tcp'` | `mdnsServiceType = '_vcr._tcp'` | Yes |
| `pingInterval = 30s` | `pingIntervalSeconds = 30` | Yes |
| `reconnectDelay = 5s` | `reconnectDelaySeconds = 5` | Yes |
| `maxReconnectAttempts = 5` | `maxReconnectAttempts = 5` | Yes |
| `mdnsTimeout = 10s` | _(not defined)_ | N/A |

Values are consistent, but this should reference the shared constants once P0 model migration is complete.

#### 5.10 AnimatedBuilder Conflicts with Flutter SDK

`lib/widgets/status_indicator.dart` defines a custom `AnimatedBuilder` class (lines 161-176) that shadows Flutter's built-in `AnimatedBuilder`. While this works because the file does not import Flutter's `AnimatedBuilder` explicitly, it is a naming collision that could cause confusion. Rename to `VcrAnimatedBuilder` or use Flutter's built-in `AnimatedBuilder` directly.

#### 5.11 Logging Standardization

The Agent uses multiple ad-hoc logging patterns:
- `_log()` in `bin/vcr_agent.dart` (timestamp + message)
- `_log()` in `WebSocketServer` (timestamp + [WS] + message)
- `_log()` in `MdnsService` (timestamp + [mDNS] + message)
- `debugPrint()` in App's `DiscoveryService`

Consider a unified logger (e.g., `package:logging`) with configurable log levels.

---

## 6. ADR Compliance

### ADR-001: Project Structure (Monorepo) -- COMPLIANT

| Decision | Implementation | Status |
|----------|---------------|--------|
| Monorepo with `lib/`, `vcr_agent/`, `shared/` | Exactly as specified | PASS |
| shared as path dependency | Both pubspec.yaml files reference shared via path | PASS |
| Agent runs via `dart run` (no Flutter SDK) | Agent uses `shelf`, `args`, `image` -- pure Dart packages | PASS |
| App is Flutter project with root pubspec | `pubspec.yaml` at root, `lib/` contains Flutter app | PASS |

**Note:** The ADR states the shared package would be named `shared` in path dependencies. The actual package name is `vcr_shared`, referenced as `vcr_shared: path: ./shared`. This is actually better than the ADR example (avoids generic name collision). Minor deviation, not a compliance issue.

### ADR-002: Screen Transfer (JPEG Base64 in JSON) -- COMPLIANT with minor delta

| Decision | Implementation | Status |
|----------|---------------|--------|
| JPEG + Base64 encoded in JSON payload | `ScreenCapture._captureFrame()` does PNG -> JPEG -> Base64 -> FrameData JSON | PASS |
| Capture via `adb exec-out screencap -p` | `ScreenCapture._captureFrame()` line 114 | PASS |
| JPEG quality 40 | `ConnectionDefaults.jpegQuality = 40`, used as default | PASS |
| Capture interval 100ms (10fps) | `ConnectionDefaults.captureIntervalMs = 100`, used as default | PASS |
| No resize (MVP) | No resize logic present | PASS |

**Minor delta:** ADR-002 specifies "PNG output" from screencap, then "PNG -> JPEG (quality 40)". The implementation uses the `image` package to decode the PNG and re-encode as JPEG. The ADR does not specify how the conversion should happen, only that it should happen. The implementation is faithful to the intent.

**Protocol compliance:** The frame message structure exactly matches PROTOCOL.md section 3.2:
```json
{ "type": "frame", "payload": { "data": "<base64>", "width": 1080, "height": 1920, "seq": 42 } }
```

### ADR-003: State Management (Provider) -- COMPLIANT

| Decision | Implementation | Status |
|----------|---------------|--------|
| Provider package ^6.1.0 | `pubspec.yaml` line 36 | PASS |
| 3 ChangeNotifiers | ConnectionProvider, TerminalProvider, PreviewProvider | PASS |
| ConnectionProvider: WebSocket state, server info, mDNS | Implemented with all specified fields | PASS |
| TerminalProvider: command history, output log | Implemented with entries list and command history | PASS |
| PreviewProvider: frame image, FPS, Agent state | Implemented with currentFrame, fps, agentState | PASS |
| No build_runner or code generation | No `build_runner` in dev_dependencies | PASS |

**Additional observation:** The ADR envisioned PreviewProvider holding "Agent state", which it does. However, some agent state information (project name, available commands) is in ConnectionProvider. This split is reasonable since connection-level metadata naturally belongs with the connection provider, while runtime state (idle/running/building) belongs with the preview provider.

**MultiProvider wiring in app.dart:** The 3 ChangeNotifierProviders plus 1 Provider<WebSocketService> are correctly registered at the root widget level, matching the ADR's design. The WebSocketService receives all 3 providers via constructor injection (not via context lookup), which is a good pattern for testability.

---

## 7. Additional Observations

### 7.1 Security Considerations

- **No authentication**: Any device on the same network can connect to the WebSocket server. For an MVP on a local development machine, this is acceptable. For any production use, add at minimum a shared secret or token-based authentication.
- **Command injection**: The `CommandParser` uses strict regex patterns, preventing arbitrary command injection. The `CodeGenerator` inserts user-provided text into Dart string literals, but does not escape single quotes. Inputting `add button "it's"` or `add text "'; malicious_code(); //"` could produce invalid Dart code or (theoretically) code injection. The risk is low since the generated code runs in the user's own project, but input sanitization should be added.

### 7.2 Memory Management

- The `PreviewProvider.updateFrame()` replaces `_currentFrame` with each new frame. The old `Uint8List` becomes eligible for GC. Since frames arrive at 10fps and are ~50-80KB each, this generates ~500-800KB/s of garbage. For a mobile app, this is within acceptable limits, but monitoring memory usage under sustained streaming is recommended.
- The `TerminalProvider.entries` list grows unboundedly. There is `TerminalConstants.maxHistorySize = 100` for command history, but no limit on terminal output entries. A long session could accumulate thousands of entries. Add a maximum entry count (e.g., 500) with FIFO eviction.

### 7.3 Concurrency

- `ScreenCapture._captureFrame()` spawns a `Process.run` on each timer tick. If a capture takes longer than 100ms (the timer interval), captures will overlap, potentially spawning multiple `adb` processes simultaneously. Add a guard (`_isProcessing` flag) to skip a tick if the previous capture is still in progress.

### 7.4 Agent Entry Point Architecture

The `bin/vcr_agent.dart` file (625 lines) contains both the application bootstrap and all business logic. This is the largest single file in the project and the most complex. It uses top-level functions (`_handleCommand`, `_handleCreateProject`, etc.) rather than class methods, which prevents unit testing without refactoring.

---

## 8. Summary of Action Items

| Priority | Item | Effort | Section |
|----------|------|--------|---------|
| P0 | Migrate App models to use shared package | 2-4h | 5.1 |
| P0 | Add core unit tests (parser, codegen, models) | 4-6h | 5.2 |
| P1 | Extract CommandHandler class from bin/vcr_agent.dart | 2-3h | 5.3 |
| P1 | Add screen capture failure notification | 1h | 5.4 |
| P1 | Add Flutter process crash recovery | 2h | 5.5 |
| P2 | Separate code generation strategy from file I/O | 2h | 5.6 |
| P2 | Add protocol versioning to welcome message | 1h | 5.7 |
| P2 | Evaluate binary WebSocket frames for Phase 2 | 2h | 5.8 |
| P3 | Remove NetworkConstants duplication | 0.5h | 5.9 |
| P3 | Rename custom AnimatedBuilder | 0.5h | 5.10 |
| P3 | Standardize logging | 1h | 5.11 |

**Total estimated effort for P0+P1: 11-16 hours.**
