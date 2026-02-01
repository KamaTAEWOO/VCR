# VCR UI/UX 재설계 명세서 V2

> **Pivot**: 터미널 리모트 컨트롤러 UI - xterm 중심 레이아웃

---

## 1. 네비게이션 플로우 (변경 없음)

```
App Launch
    │
    ▼
┌──────────────────┐
│ Connection Screen │ ◄─── 재연결 5회 실패
│  (초기 연결)       │
└────────┬─────────┘
         │ WebSocket 연결 성공 + welcome 수신
         │ (셸 자동 시작)
         ▼
┌──────────────────┐
│ Terminal Screen   │ ◄─── 뒤로가기 (Preview)
│  (메인: xterm)    │      셸이 자동 활성화된 상태
└────────┬─────────┘
         │ 프리뷰 버튼 탭 (선택적)
         ▼
┌──────────────────┐
│ Preview Screen    │
│  (전체화면 미리보기) │
└──────────────────┘
```

### 변경점
- Terminal Screen 진입 시 **셸이 자동 활성화** (수동 토글 불필요)
- xterm TerminalView가 **메인 출력 영역** (TerminalOutput 리스트 대체)

---

## 2. 디자인 시스템 (유지)

기존 `UI_SPEC.md` 섹션 2의 디자인 시스템을 그대로 유지한다.
- 컬러 팔레트: VcrColors (변경 없음)
- 타이포그래피: VcrTypography (변경 없음)
- 간격/반경: Spacing, Radii (변경 없음)

### 추가 아이콘

| Usage | Icon | 코드 |
|-------|------|------|
| 셸 활성 | terminal | `Icons.terminal` |
| 셸 재시작 | restart_alt | `Icons.restart_alt` |
| 호스트 정보 | dns | `Icons.dns` |

---

## 3. Terminal Screen 재설계 (핵심)

### 3.1 와이어프레임 (변경 후)

```
┌──────────────────────────────────┐
│ 🟢 Connected    192.168.0.5  [📱]│  ← StatusBar (간소화)
├──────────────────────────────────┤
│                                  │
│  user@macbook:~ $ ls -la         │
│  total 42                        │
│  drwxr-xr-x  12 user staff  384 │  ← xterm TerminalView
│  -rw-r--r--   1 user staff  256 │     (메인 영역, flex: 1)
│  ...                             │
│  user@macbook:~ $ █              │
│                                  │
│                                  │
│                                  │
│                                  │
├──────────────────────────────────┤
│ $ [셸 명령어 입력________] [Send] │  ← ShellInput ($ 고정)
└──────────────────────────────────┘
```

### 3.2 셸 에러/종료 상태

```
┌──────────────────────────────────┐
│ ⚫ Shell Exited   192.168.0.5    │  ← 에러 상태
├──────────────────────────────────┤
│                                  │
│                                  │
│          ┌──────────────┐        │
│          │   Terminal    │        │  ← 셸 종료 오버레이
│          │   ⚠ Shell     │        │
│          │   exited      │        │
│          │   (code: 0)   │        │
│          │               │        │
│          │ [🔄 Restart]  │        │  ← 재시작 버튼
│          └──────────────┘        │
│                                  │
├──────────────────────────────────┤
│ $ [입력 비활성___________] [Send] │  ← 비활성 상태
└──────────────────────────────────┘
```

### 3.3 위젯 트리 (변경 후)

```
TerminalScreen (StatelessWidget)
├── Scaffold
│   └── SafeArea (bottom: false)
│       └── Column
│           ├── _StatusBar (간소화)
│           │   ├── StatusIndicator (연결 상태)
│           │   ├── Expanded → Text (호스트 IP)
│           │   └── IconButton (프리뷰, 선택적)
│           ├── Divider
│           ├── Expanded ← 메인 영역
│           │   └── Stack
│           │       ├── _ShellTerminalView ← xterm (항상 표시)
│           │       │   └── TerminalView (xterm 패키지)
│           │       └── _ShellExitOverlay ← 셸 종료 시 오버레이
│           │           └── Center → Column
│           │               ├── Icon (warning)
│           │               ├── Text ("Shell exited")
│           │               └── ElevatedButton ("Restart")
│           ├── Divider
│           └── _ShellInputSection ← 입력창 (항상 셸 모드)
│               └── TerminalInput (promptText: '$ ')
```

### 3.4 V1 대비 제거되는 위젯/요소

| 제거 대상 | 위치 | 이유 |
|----------|------|------|
| 셸 토글 버튼 (`IconButton terminal`) | _StatusBar | 항상 셸 모드이므로 불필요 |
| 셸 라벨 (`Text 'Shell'`) | _StatusBar | 항상 셸이므로 불필요 |
| 프로젝트명 (`Text projectName`) | _StatusBar | 호스트 IP로 대체 |
| 디바이스 수 뱃지 (`Container count`) | _StatusBar | 불필요 |
| `TerminalOutput` 위젯 | _TerminalOutputSection | xterm이 대체 |
| `_TerminalOutputSection` 조건분기 | 메인 영역 | 항상 xterm |
| `Consumer<TerminalProvider>` 분기 로직 | _TerminalOutputSection | 조건 제거 |

### 3.5 V1 대비 유지되는 위젯/요소

| 유지 대상 | 위치 | 비고 |
|----------|------|------|
| `StatusIndicator` | _StatusBar | 연결 상태 표시용 |
| 프리뷰 버튼 (`IconButton`) | _StatusBar | Preview Screen 접근 |
| `TerminalInput` 위젯 | _ShellInputSection | Props 변경만 필요 |
| `_MiniPreviewPanel` | 메인 영역 (선택적) | 프리뷰 토글 시 사용 |
| `TerminalView` (xterm) | 메인 영역 | 기존 셸 모드 뷰 재활용 |

---

## 4. 컴포넌트 상세 명세

### 4.1 _StatusBar (변경)

**변경 전:**
```
[StatusIndicator] [프로젝트명___] [디바이스수] [셸토글] [프리뷰토글] [전체화면]
```

**변경 후:**
```
[StatusIndicator] [호스트 IP__________________________] [프리뷰 버튼]
```

#### Props/State 변화

| 항목 | Before | After |
|------|--------|-------|
| 중앙 텍스트 | `connProvider.projectName` | `connProvider.host` (IP) |
| 디바이스 수 | Consumer → Container 뱃지 | **제거** |
| 셸 토글 | Consumer → IconButton | **제거** |
| 프리뷰 버튼 | 전체화면 + 미니프리뷰 토글 | 단일 프리뷰 버튼으로 통합 (선택적) |

#### 위젯 구조 (변경 후)

```dart
Container(
  color: VcrColors.bgSecondary,
  padding: EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
  child: Row(
    children: [
      // 1. 연결 상태 인디케이터
      StatusIndicator(state: connectionState),
      SizedBox(width: Spacing.md),
      // 2. 호스트 IP (또는 "Disconnected")
      Expanded(
        child: Text(
          host ?? 'Disconnected',
          style: VcrTypography.bodyMedium.copyWith(
            color: VcrColors.textSecondary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // 3. 프리뷰 버튼 (선택적, 디바이스 연결 시)
      if (hasDevices)
        IconButton(
          icon: Icon(Icons.phone_android, color: VcrColors.accent),
          onPressed: () => navigateToPreview(),
        ),
    ],
  ),
)
```

### 4.2 _ShellTerminalView (신규)

xterm TerminalView를 항상 표시하는 래퍼 위젯.

#### Props
| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| - | - | - | - | Provider에서 직접 구독 |

#### 내부 동작
- `TerminalProvider.shellTerminal`이 null이 아니면 → `TerminalView` 렌더링
- null이면 → 로딩/대기 상태 표시 ("Connecting to shell...")
- `terminal.onResize`에서 `wsService.sendShellResize()` 호출
- `readOnly: true` (입력은 하단 입력창에서 처리)

#### 위젯 구조

```dart
Consumer<TerminalProvider>(
  builder: (context, terminalProvider, _) {
    final terminal = terminalProvider.shellTerminal;
    if (terminal == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: VcrColors.accent),
            SizedBox(height: Spacing.md),
            Text('Connecting to shell...',
              style: VcrTypography.bodyMedium.copyWith(
                color: VcrColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    terminal.onResize = (w, h, pw, ph) {
      wsService.sendShellResize(w, h);
    };
    return TerminalView(
      terminal,
      readOnly: true,
      keyboardAppearance: Brightness.dark,
      textStyle: TerminalStyle(fontSize: 11, height: 1.2),
      theme: _vcrTerminalTheme,  // 기존 테마 상수 추출
    );
  },
)
```

### 4.3 _ShellExitOverlay (신규)

셸 프로세스 종료 시 표시되는 오버레이.

#### Props
| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `exitCode` | `int?` | N | null | 셸 종료 코드 |
| `onRestart` | `VoidCallback` | Y | - | 재시작 버튼 콜백 |

#### States
| State | Type | Initial | Description |
|-------|------|---------|-------------|
| `visible` | bool | false | 셸 종료 시 true |

#### Variants
- **Normal Exit** (code 0): 회색 아이콘, "Shell session ended"
- **Error Exit** (code != 0): 빨간 아이콘, "Shell exited with error (code: N)"

#### 위젯 구조

```dart
Container(
  color: VcrColors.bgPrimary.withOpacity(0.85),
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          exitCode == 0 ? Icons.check_circle : Icons.warning,
          size: 48,
          color: exitCode == 0 ? VcrColors.textSecondary : VcrColors.warning,
        ),
        SizedBox(height: Spacing.md),
        Text(
          exitCode == 0
            ? 'Shell session ended'
            : 'Shell exited with error (code: $exitCode)',
          style: VcrTypography.bodyLarge.copyWith(
            color: VcrColors.textPrimary,
          ),
        ),
        SizedBox(height: Spacing.lg),
        ElevatedButton.icon(
          onPressed: onRestart,
          icon: Icon(Icons.restart_alt),
          label: Text('Restart Shell'),
          style: ElevatedButton.styleFrom(
            backgroundColor: VcrColors.accent,
            foregroundColor: VcrColors.bgPrimary,
          ),
        ),
      ],
    ),
  ),
)
```

### 4.4 _ShellInputSection (변경)

**변경 전 (`_TerminalInputSection`):**
- `isShellActive`에 따라 promptText와 전송 방식 분기
- 셸: `sendShellInput('$command\n')`, VCR: `sendCommand(command)`

**변경 후 (`_ShellInputSection`):**
- 항상 `promptText: '\$ '` 고정
- 항상 `sendShellInput('$command\n')`으로 전송
- `:vcr` 접두사 감지 시 → VCR 명령어로 분기

#### 입력 처리 로직

```
onSubmit(command):
  if command.startsWith(':vcr '):
    vcrCommand = command.substring(5)  // ':vcr ' 제거
    wsService.sendCommand(vcrCommand)
  else:
    wsService.sendShellInput(command + '\n')
```

#### 위젯 구조 (변경 후)

```dart
// _ShellInputSection
Widget build(BuildContext context) {
  final connProvider = context.watch<ConnectionProvider>();
  final wsService = context.read<WebSocketService>();
  final isConnected = connProvider.isConnected;

  return TerminalInput(
    enabled: isConnected,
    commandHistory: terminalProvider.commandHistory,
    hintText: 'Shell command...',
    promptText: '\$ ',
    onSubmit: (command) {
      if (command.startsWith(':vcr ')) {
        // VCR 명령어 모드 (secondary)
        wsService.sendCommand(command.substring(5));
      } else {
        // 셸 패스스루 (primary)
        wsService.sendShellInput('$command\n');
      }
    },
  );
}
```

### 4.5 TerminalInput 위젯 (변경 최소화)

기존 `TerminalInput` 위젯은 구조 변경 없이, 부모에서 전달하는 Props만 변경.

| Prop | Before | After |
|------|--------|-------|
| `promptText` | `'> '` 또는 `'\$ '` (분기) | `'\$ '` (고정) |
| `hintText` | `'Enter command...'` 또는 `'Shell command...'` | `'Shell command...'` (고정) |
| `onSubmit` | shellActive 분기 로직 | 항상 셸 + `:vcr` 감지 |

---

## 5. 상태별 UI 변화

### 5.1 연결 상태

| 상태 | StatusBar | 메인 영역 | 입력창 |
|------|----------|----------|--------|
| Connecting | 🔵 `Connecting...` | 빈 화면 | 비활성 |
| Connected (셸 준비 중) | 🟢 `Connected` + IP | "Connecting to shell..." 로딩 | 비활성 |
| Connected (셸 활성) | 🟢 `Connected` + IP | xterm TerminalView | 활성 |
| Shell Exited | ⚫ `Shell Exited` | ShellExitOverlay | 비활성 |
| Disconnected | ⚫ `Reconnecting...` | 마지막 xterm 상태 유지 | 비활성 |

### 5.2 StatusIndicator 상태 매핑 (변경)

V2에서는 Agent 상태 대신 **연결+셸 상태**를 표시한다.

| 상태 | Color | Label | Icon |
|------|-------|-------|------|
| `connected` + shell active | stateRunning (초록) | "Connected" | circle |
| `connected` + shell inactive | stateIdle (회색) | "No Shell" | circle |
| `connecting` | stateReloading (파랑) | "Connecting..." | refresh (rotate) |
| `disconnected` | stateDisconnected (회색) | "Disconnected" | link_off |
| `shellExited` | stateError (빨강) | "Shell Exited" | warning |

---

## 6. xterm TerminalView 테마 상수

기존 `terminal_screen.dart`에 인라인으로 정의된 xterm 테마를 **상수로 추출**한다.

### 위치: `lib/core/theme.dart`에 추가

```dart
/// xterm terminal theme matching VCR dark design system
const TerminalTheme vcrTerminalTheme = TerminalTheme(
  cursor: VcrColors.accent,           // #BC8CFF
  selection: Color(0x40BC8CFF),       // accent 25% opacity
  foreground: VcrColors.textPrimary,  // #E6EDF3
  background: VcrColors.bgPrimary,    // #0D1117
  black: Color(0xFF484F58),
  red: Color(0xFFF85149),
  green: Color(0xFF3FB950),
  yellow: Color(0xFFD29922),
  blue: Color(0xFF58A6FF),
  magenta: Color(0xFFBC8CFF),
  cyan: Color(0xFF76E3EA),
  white: Color(0xFFE6EDF3),
  brightBlack: Color(0xFF6E7681),
  brightRed: Color(0xFFFFA198),
  brightGreen: Color(0xFF56D364),
  brightYellow: Color(0xFFE3B341),
  brightBlue: Color(0xFF79C0FF),
  brightMagenta: Color(0xFFD2A8FF),
  brightCyan: Color(0xFFA5D6FF),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFFD29922),
  searchHitBackgroundCurrent: Color(0xFFF85149),
  searchHitForeground: Color(0xFF0D1117),
);

/// xterm terminal text style
const TerminalStyle vcrTerminalStyle = TerminalStyle(
  fontSize: 11,
  height: 1.2,
);
```

---

## 7. 인터랙션 패턴

### 7.1 셸 명령어 입력 플로우

```
사용자 → 입력창 탭 → 키보드 표시
  → 명령어 입력 (예: "ls -la")
  → Enter 또는 Send 버튼 탭
  → sendShellInput("ls -la\n")
  → xterm에 결과 표시 (실시간 스트리밍)
  → 입력창 클리어 + 포커스 유지
```

### 7.2 히스토리 네비게이션

```
입력창 포커스 상태에서:
  ↑ (ArrowUp): 이전 명령어 불러오기
  ↓ (ArrowDown): 다음 명령어 또는 클리어
  동작: 기존 TerminalInput 로직 그대로 유지
```

### 7.3 VCR 명령어 접근

```
사용자 → 입력창에 ":vcr " 입력
  → 이후 VCR 명령어 입력 (예: ":vcr status")
  → Enter
  → ":vcr " 접두사 제거
  → sendCommand("status")
  → response 수신 → xterm에 결과 텍스트 출력
```

### 7.4 셸 재시작

```
셸 종료 → ShellExitOverlay 표시
  → "Restart Shell" 버튼 탭
  → sendCommand("shell")
  → Agent가 ShellManager.start()
  → shell_output 스트리밍 재개
  → 오버레이 제거, xterm 활성화
```

---

## 8. 애니메이션

| 애니메이션 | Duration | Curve | 적용 대상 |
|-----------|----------|-------|----------|
| StatusIndicator 색상 전환 | 300ms | easeInOut | 상태 변경 시 |
| ShellExitOverlay 페이드인 | 200ms | easeOut | 셸 종료 시 |
| ShellExitOverlay 페이드아웃 | 150ms | easeIn | 셸 재시작 시 |
| Connecting 로딩 | 1500ms, repeat | linear | CircularProgressIndicator |

---

## 9. fe-dev 전달 요약

### 수정 대상 파일

| 파일 | 변경 내용 | 복잡도 |
|------|----------|--------|
| `lib/screens/terminal_screen.dart` | 전체 재구성: StatusBar 간소화, xterm 메인 뷰, 셸 토글 제거, ShellExitOverlay 추가 | **L** |
| `lib/widgets/terminal_input.dart` | 변경 없음 (Props만 부모에서 변경) | **-** |
| `lib/core/theme.dart` | `vcrTerminalTheme`, `vcrTerminalStyle` 상수 추가 | **S** |
| `lib/providers/terminal_provider.dart` | 셸 자동 활성화, shellExited 상태 추가 | **M** |
| `lib/services/websocket_service.dart` | welcome 셸 상태 처리 | **S** |

### 제거 대상

| 파일/위젯 | 제거 항목 |
|----------|----------|
| `terminal_screen.dart` | 셸 토글 버튼, 디바이스 수 뱃지, 프로젝트명 표시, `_TerminalOutputSection` 조건분기 |
| `terminal_output.dart` | 위젯 자체는 유지하되 Terminal Screen에서 사용하지 않음 (`:vcr` 응답에 활용 가능) |

### 핵심 구현 포인트

1. **`_StatusBar` 간소화** - 프로젝트명 → 호스트 IP, 셸 토글/디바이스 수 제거
2. **메인 영역 = xterm 고정** - `_TerminalOutputSection`의 조건분기 제거, 항상 `TerminalView`
3. **`_ShellInputSection`** - 항상 `$ ` 프롬프트, 항상 `sendShellInput`, `:vcr` 분기만 추가
4. **`_ShellExitOverlay`** - Stack으로 xterm 위에 오버레이, 재시작 버튼 포함
5. **xterm 테마 상수화** - 인라인 → `theme.dart`의 `vcrTerminalTheme`으로 추출
6. **기존 디자인 시스템 유지** - VcrColors, VcrTypography, Spacing, Radii 그대로 사용
