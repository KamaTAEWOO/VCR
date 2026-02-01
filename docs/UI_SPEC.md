# VCR UI/UX 설계 명세서

> Phase 1b 산출물 - `/fe-dev` 에이전트가 참조할 UI 스펙

---

## 1. 네비게이션 플로우

```
App Launch
    │
    ▼
┌──────────────────┐
│ Connection Screen │ ◄─── 재연결 5회 실패
│  (초기 연결)       │
└────────┬─────────┘
         │ WebSocket 연결 성공 + welcome 수신
         ▼
┌──────────────────┐
│ Terminal Screen   │ ◄─── 뒤로가기 (Preview)
│  (메인 화면)       │
└────────┬─────────┘
         │ 프리뷰 토글 버튼 탭
         ▼
┌──────────────────┐
│ Preview Screen    │
│  (전체화면 미리보기) │
└──────────────────┘
```

### 라우트 정의

| Route | Screen | 진입 조건 | 이탈 조건 |
|-------|--------|----------|----------|
| `/` | ConnectionScreen | 앱 시작, 재연결 실패 | 연결 성공 |
| `/terminal` | TerminalScreen | WebSocket 연결 성공 | 연결 끊김 (5회 실패), 프리뷰 전환 |
| `/preview` | PreviewScreen | 프리뷰 토글 탭 | 뒤로가기 |

---

## 2. 디자인 시스템

### 2.1 컬러 팔레트

#### 배경 계열
| Name | Hex | Flutter | Usage |
|------|-----|---------|-------|
| `bgPrimary` | `#0D1117` | `Color(0xFF0D1117)` | 메인 배경 (터미널) |
| `bgSecondary` | `#161B22` | `Color(0xFF161B22)` | 카드/패널 배경 |
| `bgTertiary` | `#21262D` | `Color(0xFF21262D)` | 입력창 배경 |
| `bgSurface` | `#1C2128` | `Color(0xFF1C2128)` | 서페이스 |

#### 텍스트 계열
| Name | Hex | Flutter | Usage |
|------|-----|---------|-------|
| `textPrimary` | `#E6EDF3` | `Color(0xFFE6EDF3)` | 기본 텍스트 |
| `textSecondary` | `#8B949E` | `Color(0xFF8B949E)` | 보조 텍스트, 로그 |
| `textMuted` | `#484F58` | `Color(0xFF484F58)` | 플레이스홀더 |

#### 시맨틱 계열
| Name | Hex | Flutter | Usage |
|------|-----|---------|-------|
| `success` | `#3FB950` | `Color(0xFF3FB950)` | 성공 메시지, Running 상태 |
| `error` | `#F85149` | `Color(0xFFF85149)` | 에러 메시지, Build Error |
| `warning` | `#D29922` | `Color(0xFFD29922)` | 경고, Building 상태 |
| `info` | `#58A6FF` | `Color(0xFF58A6FF)` | 정보, Reloading 상태 |
| `accent` | `#BC8CFF` | `Color(0xFFBC8CFF)` | 액센트 (VCR 브랜드) |

#### 상태 표시 전용
| Name | Hex | Usage |
|------|-----|-------|
| `stateIdle` | `#484F58` | Idle (회색) |
| `stateRunning` | `#3FB950` | Running (초록) |
| `stateReloading` | `#58A6FF` | Hot Reload/Restart (파랑) |
| `stateBuilding` | `#D29922` | Building (노랑) |
| `stateError` | `#F85149` | Build Error / Error (빨강) |
| `stateDisconnected` | `#484F58` | Disconnected (어두운 회색) |

### 2.2 타이포그래피

| Element | Font | Size | Weight | Letter Spacing |
|---------|------|------|--------|---------------|
| `headlineLarge` | System | 28sp | w700 | -0.5 |
| `headlineMedium` | System | 22sp | w600 | 0 |
| `titleLarge` | System | 18sp | w600 | 0 |
| `bodyLarge` | System | 16sp | w400 | 0 |
| `bodyMedium` | System | 14sp | w400 | 0 |
| `labelMedium` | System | 12sp | w500 | 0.5 |
| `terminalText` | `JetBrains Mono` / `Fira Code` / `monospace` fallback | 14sp | w400 | 0 |
| `terminalInput` | monospace | 16sp | w500 | 0 |
| `terminalPrompt` | monospace | 16sp | w700 | 0 |

> 터미널 영역은 모노스페이스 폰트 필수. Google Fonts의 `JetBrains Mono` 사용 권장 (무료). 불가 시 시스템 모노스페이스 폴백.

### 2.3 간격 규칙

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4dp | 아이콘-텍스트 간격 |
| `sm` | 8dp | 리스트 아이템 내부 패딩 |
| `md` | 16dp | 카드 패딩, 섹션 간격 |
| `lg` | 24dp | 화면 좌우 패딩 |
| `xl` | 32dp | 섹션 간 대간격 |
| `xxl` | 48dp | 화면 상단 여백 |

### 2.4 모서리 반경

| Token | Value | Usage |
|-------|-------|-------|
| `radiusSm` | 4dp | 뱃지, 작은 칩 |
| `radiusMd` | 8dp | 입력창, 카드 |
| `radiusLg` | 12dp | 패널, 바텀시트 |
| `radiusXl` | 16dp | 다이얼로그 |
| `radiusFull` | 999dp | 상태 인디케이터 (원형) |

### 2.5 아이콘 세트 (Material Icons)

| Usage | Icon | 코드 |
|-------|------|------|
| 탐색 중 | search | `Icons.search` |
| 서버 (발견됨) | computer | `Icons.computer` |
| 연결 | link | `Icons.link` |
| 연결 해제 | link_off | `Icons.link_off` |
| 전송 (커맨드) | send | `Icons.send` |
| 프리뷰 | phone_android | `Icons.phone_android` |
| 프리뷰 전체화면 | fullscreen | `Icons.fullscreen` |
| 프리뷰 축소 | fullscreen_exit | `Icons.fullscreen_exit` |
| 뒤로가기 | arrow_back | `Icons.arrow_back` |
| 성공 | check_circle | `Icons.check_circle` |
| 에러 | error | `Icons.error` |
| 경고 | warning | `Icons.warning` |
| 빌드 중 | build | `Icons.build` |
| 새로고침 (reload) | refresh | `Icons.refresh` |
| 히스토리 | history | `Icons.history` |

---

## 3. 화면 상세 설계

### 3.1 Connection Screen

#### 와이어프레임
```
┌──────────────────────────────────┐
│         SafeArea (top)           │
│                                  │
│         ┌──────────────┐         │
│         │    VCR ▶     │         │  accent 색상 로고
│         │ Vibe Code    │         │  headlineLarge
│         │   Runner     │         │  textSecondary
│         └──────────────┘         │
│                                  │
│  ┌────────────────────────────┐  │
│  │  Discovered Servers        │  │  titleLarge
│  │  ┌──────────────────────┐  │  │
│  │  │ 🖥  MacBook Pro      │  │  │  ServerListTile
│  │  │    192.168.0.5:8765  │  │  │  bodyMedium, textSecondary
│  │  └──────────────────────┘  │  │
│  │  ┌──────────────────────┐  │  │
│  │  │ 🖥  iMac             │  │  │  ServerListTile
│  │  │    192.168.0.10:8765 │  │  │
│  │  └──────────────────────┘  │  │
│  │                            │  │
│  │  🔍 Searching...           │  │  탐색 중이면 로딩 표시
│  └────────────────────────────┘  │
│                                  │
│  ── OR CONNECT MANUALLY ──────   │  Divider + 텍스트
│                                  │
│  ┌────────────────────────────┐  │
│  │  IP Address                │  │  TextField (bgTertiary)
│  │  [192.168.0.___________]   │  │
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │  Port                      │  │  TextField (bgTertiary)
│  │  [8765__________________ ] │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │        CONNECT              │  │  ElevatedButton (accent)
│  └────────────────────────────┘  │
│                                  │
│         SafeArea (bottom)        │
└──────────────────────────────────┘
```

#### 위젯 트리
```
ConnectionScreen (StatelessWidget)
├── Scaffold
│   └── SafeArea
│       └── SingleChildScrollView
│           └── Padding (lg)
│               └── Column
│                   ├── SizedBox (xxl) ← 상단 여백
│                   ├── _VcrLogo ← 로고 + 타이틀
│                   ├── SizedBox (xl)
│                   ├── _ServerDiscoverySection
│                   │   ├── Text ("Discovered Servers")
│                   │   ├── Consumer → ListView.builder
│                   │   │   └── ServerListTile (각 서버)
│                   │   └── _SearchingIndicator (탐색 중)
│                   ├── SizedBox (lg)
│                   ├── _ManualConnectDivider ← "OR CONNECT MANUALLY"
│                   ├── SizedBox (lg)
│                   ├── _ManualConnectForm
│                   │   ├── TextField (IP)
│                   │   ├── SizedBox (sm)
│                   │   ├── TextField (Port)
│                   │   └── SizedBox (md)
│                   └── SizedBox (md)
│                   └── _ConnectButton ← ElevatedButton
```

#### 상태별 UI 변화

| 상태 | UI |
|------|-----|
| 초기 (탐색 중) | 서버 목록 비어있음 + "Searching..." 로딩 |
| 서버 발견 | ServerListTile 항목 추가 (애니메이션) |
| 탐색 완료, 결과 없음 | "No servers found. Try manual connection." |
| 연결 시도 중 | CONNECT 버튼 → CircularProgressIndicator |
| 연결 실패 | SnackBar (error 색상) "Connection failed" |

### 3.2 Terminal Screen (메인)

#### 와이어프레임
```
┌──────────────────────────────────┐
│ ● Running    my_app     [📱]    │  ← StatusBar
├──────────────────────────────────┤
│                                  │
│ > create project my_app          │  ← 사용자 입력 (흰색)
│   Creating project...            │  ← 로그 (회색)
│   Running flutter run...         │
│ ✓ Project my_app created         │  ← 성공 (초록)
│                                  │
│ > create page Home               │
│   Creating lib/pages/home_page.. │
│ ✓ Page Home created              │
│                                  │
│ > add button "Login"             │
│ ✓ Button 'Login' added           │
│                                  │
│ > bad command                    │
│ ✗ Unknown command. Type 'help'   │  ← 에러 (빨강)
│                                  │
│                                  │
│                                  │
├──────────────────────────────────┤
│ > █                              │  ← 입력창 (커서 깜빡)
│                          [Send]  │
└──────────────────────────────────┘
```

#### 미니 프리뷰 모드 (토글 시)
```
┌──────────────────────────────────┐
│ ● Running    my_app     [📱]    │
├──────────────────────────────────┤
│                    ┌──────────┐  │
│ > create project   │          │  │  ← 미니 프리뷰
│ ✓ Project created  │ Emulator │  │     (화면 우측 1/3)
│                    │  Screen  │  │     탭하면 Preview Screen
│ > create page Home │          │  │
│ ✓ Page Home created│          │  │
│                    └──────────┘  │
│                                  │
│ > add button "Login"             │
│ ✓ Button 'Login' added           │
│                                  │
├──────────────────────────────────┤
│ > █                      [Send]  │
└──────────────────────────────────┘
```

#### 위젯 트리
```
TerminalScreen (StatelessWidget)
├── Scaffold
│   ├── body: Column
│   │   ├── StatusBar (custom)
│   │   │   ├── StatusIndicator (dot + text)
│   │   │   ├── Expanded → Text (project name)
│   │   │   └── IconButton (preview toggle)
│   │   ├── Expanded
│   │   │   └── Row (미니 프리뷰 모드 시)
│   │   │       ├── Expanded (flex: 2)
│   │   │       │   └── TerminalOutput
│   │   │       │       └── ListView.builder
│   │   │       │           └── CommandHistoryItem (각 항목)
│   │   │       └── Expanded (flex: 1) [미니 프리뷰 on일 때만]
│   │   │           └── GestureDetector → PreviewViewer (mini)
│   │   └── TerminalInput
│   │       └── Container (bgTertiary)
│   │           └── Row
│   │               ├── Text ("> ") ← 프롬프트
│   │               ├── Expanded → TextField
│   │               └── IconButton (send)
```

#### 상태별 UI 변화

| Agent 상태 | StatusBar | 터미널 영향 |
|-----------|-----------|-----------|
| `idle` | `⚪ Idle` stateIdle | 입력 가능 |
| `running` | `🟢 Running` stateRunning | 입력 가능, 프리뷰 활성 |
| `hot_reloading` | `🔄 Reloading...` stateReloading + 펄스 애니메이션 | 입력 가능 (큐잉) |
| `hot_restarting` | `🔄 Restarting...` stateReloading + 펄스 애니메이션 | 입력 가능 (큐잉) |
| `building` | `🔨 Building...` stateBuilding + 펄스 애니메이션 | 입력 가능 (큐잉) |
| `build_error` | `🔴 Build Error` stateError | 입력 가능 |
| `error` | `🔴 Error` stateError | 입력 가능 |
| 연결 끊김 | `⚫ Reconnecting...` stateDisconnected + 카운트다운 | 입력 비활성 |

### 3.3 Preview Screen (전체화면)

#### 와이어프레임
```
┌──────────────────────────────────┐
│                                  │
│                                  │
│       ┌──────────────────┐       │
│       │                  │       │
│       │                  │       │
│       │    Emulator      │       │  ← InteractiveViewer
│       │    Screen        │       │     (핀치 줌 가능)
│       │    Frame         │       │
│       │                  │       │
│       │                  │       │
│       └──────────────────┘       │
│                                  │
│  10 fps                    [←]   │  ← FPS + 뒤로가기
│                                  │
└──────────────────────────────────┘
```

#### 위젯 트리
```
PreviewScreen (StatelessWidget)
├── Scaffold
│   ├── backgroundColor: Colors.black
│   └── body: Stack
│       ├── Center
│       │   └── InteractiveViewer
│       │       └── Consumer → PreviewViewer
│       │           └── Image.memory (JPEG bytes)
│       └── Positioned (bottom, left/right)
│           └── SafeArea
│               └── Padding
│                   └── Row
│                       ├── _FpsCounter (Text, textSecondary)
│                       └── Spacer
│                       └── IconButton (arrow_back)
```

#### 상태별 UI 변화

| 상태 | UI |
|------|-----|
| 프레임 수신 중 | 이미지 실시간 갱신 |
| 프레임 없음 (Agent idle) | 중앙에 "No preview available" + 아이콘 |
| 프레임 일시 정지 | 마지막 프레임 유지 + "Paused" 오버레이 |

---

## 4. 커스텀 위젯 컴포넌트 명세

### 4.1 StatusIndicator

상태 표시 원형 인디케이터 + 텍스트

#### Props
| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `state` | `AgentState` | Y | - | Agent 상태 enum |
| `projectName` | `String?` | N | `null` | 프로젝트명 |

#### 내부 매핑
| AgentState | Color | Icon | Label | Animation |
|-----------|-------|------|-------|-----------|
| `idle` | stateIdle | `circle` | "Idle" | none |
| `running` | stateRunning | `circle` | "Running" | none |
| `hotReloading` | stateReloading | `refresh` | "Reloading..." | rotate |
| `hotRestarting` | stateReloading | `refresh` | "Restarting..." | rotate |
| `building` | stateBuilding | `build` | "Building..." | pulse |
| `buildError` | stateError | `error` | "Build Error" | none |
| `error` | stateError | `error` | "Error" | none |
| `disconnected` | stateDisconnected | `link_off` | "Disconnected" | none |

#### Widget 구조
```dart
Row(
  children: [
    AnimatedContainer(  // 상태 dot
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: stateColor,
        shape: BoxShape.circle,
      ),
    ),
    SizedBox(width: xs),
    Text(label, style: labelMedium.copyWith(color: stateColor)),
  ],
)
```

### 4.2 TerminalInput

CLI 스타일 명령 입력창

#### Props
| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `onSubmit` | `Function(String)` | Y | - | 커맨드 전송 콜백 |
| `enabled` | `bool` | N | `true` | 입력 가능 여부 |

#### States
| State | Type | Initial | Description |
|-------|------|---------|-------------|
| `controller` | `TextEditingController` | empty | 입력 텍스트 |
| `historyIndex` | `int` | -1 | 히스토리 탐색 위치 |

#### Widget 구조
```dart
Container(
  color: bgTertiary,
  padding: EdgeInsets.symmetric(horizontal: md, vertical: sm),
  child: Row(
    children: [
      Text('> ', style: terminalPrompt.copyWith(color: accent)),
      Expanded(
        child: TextField(
          controller: controller,
          style: terminalInput,
          decoration: InputDecoration.collapsed(
            hintText: 'Enter command...',
            hintStyle: TextStyle(color: textMuted),
          ),
          onSubmitted: _handleSubmit,
        ),
      ),
      IconButton(
        icon: Icon(Icons.send, color: accent),
        onPressed: _handleSend,
      ),
    ],
  ),
)
```

### 4.3 TerminalOutput

커맨드 실행 결과 표시 영역

#### Props
| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `entries` | `List<TerminalEntry>` | Y | - | 출력 항목 목록 |

#### TerminalEntry 모델
```dart
class TerminalEntry {
  final TerminalEntryType type;  // input, success, error, warning, log
  final String text;
  final DateTime timestamp;
}
```

#### 출력 스타일 매핑
| Type | Prefix | Color | Font Weight |
|------|--------|-------|-------------|
| `input` | `> ` | textPrimary | w500 |
| `success` | `✓ ` | success | w400 |
| `error` | `✗ ` | error | w400 |
| `warning` | `⚠ ` | warning | w400 |
| `log` | `  ` (indent) | textSecondary | w400 |

#### Widget 구조
```dart
ListView.builder(
  controller: scrollController,  // 자동 스크롤 (최하단)
  padding: EdgeInsets.all(md),
  itemCount: entries.length,
  itemBuilder: (context, index) {
    final entry = entries[index];
    return Padding(
      padding: EdgeInsets.only(bottom: xs),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: prefix, style: ...),
            TextSpan(text: entry.text, style: ...),
          ],
        ),
        style: terminalText,
      ),
    );
  },
)
```

### 4.4 PreviewViewer

에뮬레이터 화면 프레임 표시

#### Props
| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `frameBytes` | `Uint8List?` | N | `null` | 현재 JPEG 프레임 |
| `mini` | `bool` | N | `false` | 미니 프리뷰 모드 |

#### States
| State | Type | Initial | Description |
|-------|------|---------|-------------|
| `fps` | `int` | 0 | 현재 FPS |

#### Widget 구조
```dart
// 프레임 없을 때
if (frameBytes == null)
  Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.phone_android, size: 48, color: textMuted),
        SizedBox(height: sm),
        Text('No preview', style: bodyMedium.copyWith(color: textMuted)),
      ],
    ),
  )

// 프레임 있을 때
Image.memory(
  frameBytes!,
  fit: mini ? BoxFit.cover : BoxFit.contain,
  gaplessPlayback: true,  // 프레임 전환 시 깜빡임 방지
)
```

### 4.5 ServerListTile

발견된 VCR Agent 서버 항목

#### Props
| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `name` | `String` | Y | - | 서버 이름 |
| `host` | `String` | Y | - | IP 주소 |
| `port` | `int` | Y | - | 포트 |
| `onTap` | `VoidCallback` | Y | - | 탭 콜백 |

#### Widget 구조
```dart
Card(
  color: bgSecondary,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
  child: ListTile(
    leading: Icon(Icons.computer, color: accent),
    title: Text(name, style: bodyLarge),
    subtitle: Text('$host:$port', style: bodyMedium.copyWith(color: textSecondary)),
    trailing: Icon(Icons.chevron_right, color: textMuted),
    onTap: onTap,
  ),
)
```

### 4.6 CommandHistoryItem

(TerminalOutput 내부에서 사용 - 위 TerminalOutput에 통합)

---

## 5. 상태 표시 UI 상세

### 5.1 애니메이션 정의

| 애니메이션 | Duration | Curve | 적용 대상 |
|-----------|----------|-------|----------|
| `pulse` | 1500ms, repeat | easeInOut | Building 상태 dot 크기 변화 (8dp ↔ 12dp) |
| `rotate` | 1000ms, repeat | linear | Reloading 아이콘 360도 회전 |
| `fadeIn` | 300ms | easeOut | 새 터미널 항목 등장 |
| `slideUp` | 200ms | easeOut | SnackBar 등장 |

### 5.2 상태 전환 애니메이션

상태 변경 시 StatusIndicator의 색상은 `AnimatedContainer` (duration: 300ms)로 부드럽게 전환.

```
idle(회색) ─── 300ms ──→ running(초록) ─── 300ms ──→ hot_reloading(파랑)
                                                          │ 300ms
                                                          ▼
                                                     running(초록)
```

---

## 6. Flutter ThemeData 정의

```dart
ThemeData vcrDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Color(0xFF0D1117),  // bgPrimary
  colorScheme: ColorScheme.dark(
    primary: Color(0xFFBC8CFF),     // accent
    secondary: Color(0xFF58A6FF),   // info
    error: Color(0xFFF85149),       // error
    surface: Color(0xFF1C2128),     // bgSurface
  ),
  cardColor: Color(0xFF161B22),     // bgSecondary
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF161B22),
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    fillColor: Color(0xFF21262D),   // bgTertiary
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFFBC8CFF),
      foregroundColor: Color(0xFF0D1117),
      minimumSize: Size(double.infinity, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: Color(0xFF21262D),
    contentTextStyle: TextStyle(color: Color(0xFFE6EDF3)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    behavior: SnackBarBehavior.floating,
  ),
);
```

---

## 7. fe-dev 전달 요약

### 파일 생성 목록
| 파일 경로 | 내용 |
|----------|------|
| `lib/core/theme.dart` | `vcrDarkTheme` + 컬러 상수 + 타이포그래피 |
| `lib/core/constants.dart` | 간격, 반경, 애니메이션 duration 상수 |
| `lib/widgets/status_indicator.dart` | StatusIndicator 위젯 |
| `lib/widgets/terminal_input.dart` | TerminalInput 위젯 |
| `lib/widgets/terminal_output.dart` | TerminalOutput 위젯 + TerminalEntry 모델 |
| `lib/widgets/preview_viewer.dart` | PreviewViewer 위젯 |
| `lib/widgets/server_list_tile.dart` | ServerListTile 위젯 |
| `lib/screens/connection_screen.dart` | 위젯 트리 기준 구현 |
| `lib/screens/terminal_screen.dart` | 위젯 트리 기준 구현 |
| `lib/screens/preview_screen.dart` | 위젯 트리 기준 구현 |

### 핵심 구현 포인트
1. **모든 색상은 `theme.dart`의 상수 사용** - 하드코딩 금지
2. **터미널 영역은 모노스페이스 폰트** - `terminalText` 스타일
3. **자동 스크롤** - 새 항목 추가 시 ListView 최하단으로
4. **gaplessPlayback: true** - 프리뷰 프레임 전환 시 깜빡임 방지
5. **StatusIndicator 애니메이션** - Building/Reloading 시 pulse/rotate
