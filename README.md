# VCR - Vibe Code Runner

> **폰에서 터미널을 치면, 노트북에서 앱이 살아난다**

VCR은 스마트폰에서 터미널 명령을 입력하면, 같은 Wi-Fi의 노트북에서 Flutter 앱을 실시간으로 생성/실행/미리보기 할 수 있는 **모바일 기반 바이브 코딩 컨트롤러**입니다. 코드를 몰라도 됩니다. 명령만 치면 앱이 만들어집니다.

---

## 구조 설명

VCR은 세 가지 구성요소로 이루어져 있습니다.


```
+---------------------------+          WebSocket (JSON)          +---------------------------+
|     VCR App (스마트폰)      | <-----------------------------> |    VCR Agent (노트북)       |
|                           |                                   |                           |
|  - 터미널 UI (명령 입력)    |                                   |  - WebSocket 서버          |
|  - 라이브 프리뷰           |                                   |  - 커맨드 파서              |
|  - 상태 표시               |                                   |  - Flutter 프로세스 제어     |
+---------------------------+                                   |  - 에뮬레이터 화면 캡쳐      |
                                                                +---------------------------+
```

| 구성요소 | 위치 | 설명 |
|----------|------|------|
| **VCR App** | `/lib` | Flutter 모바일 앱. 스마트폰에서 터미널 명령을 입력하고, 에뮬레이터 화면을 실시간으로 받아봅니다. |
| **VCR Agent** | `/vcr_agent` | Dart CLI 프로그램. 노트북에서 실행되며 커맨드를 받아 Flutter 프로젝트를 생성/수정하고, 에뮬레이터 화면을 스트리밍합니다. |
| **shared** | `/shared` | 공유 패키지. App과 Agent가 함께 사용하는 프로토콜 상수, 메시지 모델을 정의합니다. |

---

## 사전 요구사항

| 항목 | 버전/조건 |
|------|-----------|
| Flutter SDK | 3.9 이상 |
| Dart SDK | 3.9 이상 |
| Android Emulator | 실행 중이어야 함 |
| ADB (Android Debug Bridge) | 설치 및 PATH 등록 |
| 네트워크 | 스마트폰과 노트북이 **같은 Wi-Fi**에 연결 |

---

## 설치 방법

```bash
# 1. 프로젝트 클론
git clone <repository-url>
cd vcr

# 2. App 의존성 설치
flutter pub get

# 3. Agent 의존성 설치
cd vcr_agent && dart pub get && cd ..
```

---

## 실행 방법

### Step 1: Android Emulator 실행

Android Studio 또는 커맨드라인으로 에뮬레이터를 먼저 실행합니다.

```bash
# 사용 가능한 에뮬레이터 목록 확인
emulator -list-avds

# 에뮬레이터 실행 (예시)
emulator -avd Pixel_7_API_34
```

에뮬레이터가 정상적으로 실행되었는지 확인합니다.

```bash
adb devices
# List of devices attached
# emulator-5554   device
```

### Step 2: 노트북에서 VCR Agent 실행

```bash
cd vcr_agent
dart run bin/vcr_agent.dart --port 8765
```

Agent가 실행되면 WebSocket 서버가 포트 8765에서 대기하며, 같은 네트워크에서 mDNS(`_vcr._tcp`)로 자동 탐색 가능 상태가 됩니다.

### Step 3: 스마트폰에서 VCR App 실행

실제 스마트폰 또는 별도의 에뮬레이터에서 VCR App을 실행합니다.

```bash
flutter run
```

### Step 4: 앱에서 Agent에 연결

1. VCR App이 실행되면 **Connection Screen**이 표시됩니다.
2. 같은 Wi-Fi라면 mDNS 자동 탐색으로 Agent가 목록에 나타납니다.
3. 목록에서 Agent를 탭하거나, 수동으로 IP와 포트(기본 8765)를 입력합니다.
4. 연결되면 **Terminal Screen**으로 전환되며, 커맨드 입력이 가능합니다.

---

## VCR 커맨드 목록

| 커맨드 | 설명 | 예시 |
|--------|------|------|
| `create project <name>` | Flutter 프로젝트를 생성하고 실행합니다. 이름은 영문 소문자, 숫자, 언더스코어만 허용됩니다. | `create project my_app` |
| `create page <Name>` | 새 페이지를 생성합니다. PascalCase 이름을 사용합니다. 생성 후 해당 페이지가 활성 페이지로 전환됩니다. | `create page Home` |
| `add button "<text>"` | 현재 활성 페이지에 버튼을 추가합니다. | `add button "Login"` |
| `add text "<text>"` | 현재 활성 페이지에 텍스트를 추가합니다. | `add text "Welcome"` |
| `add image <url>` | 현재 활성 페이지에 네트워크 이미지를 추가합니다. | `add image https://example.com/logo.png` |
| `hot reload` | Hot reload를 실행합니다. 코드 변경 사항을 즉시 반영합니다. | `hot reload` |
| `restart` | Hot restart를 실행합니다. 앱 상태를 초기화하고 다시 시작합니다. | `restart` |
| `status` | 현재 Agent 상태를 확인합니다. 프로젝트명, 실행 상태, 활성 페이지, 에뮬레이터 상태 등을 표시합니다. | `status` |
| `help` | 사용 가능한 커맨드 목록과 설명을 표시합니다. | `help` |

---

## 사용 예시 시나리오

아래는 VCR App의 터미널에서 프로젝트를 생성하고 페이지를 꾸미는 전체 흐름입니다.

```
> create project my_app
  Creating Flutter project...
  Running flutter run...
  Build complete
✓ Project my_app created and running

> create page Home
  Creating lib/pages/home_page.dart...
  Updating routes...
  Hot reload triggered
✓ Page Home created

> add button "Login"
  Adding button to Home page...
  Hot reload triggered
✓ Button 'Login' added

> add text "Welcome to VCR"
  Adding text to Home page...
  Hot reload triggered
✓ Text 'Welcome to VCR' added

> add image https://picsum.photos/200
  Adding image to Home page...
  Hot reload triggered
✓ Image added

> hot reload
✓ Hot reload complete

> status
  Project: my_app
  Status: running
  Active Page: Home
  Emulator: connected
  Pages: [Home]

> help
  Available commands:
    create project <name>  - Create a new Flutter project
    create page <Name>     - Create a new page
    add button "<text>"    - Add a button
    add text "<text>"      - Add a text widget
    add image <url>        - Add a network image
    hot reload             - Trigger hot reload
    restart                - Trigger hot restart
    status                 - Show current status
    help                   - Show this help
```

에뮬레이터 화면은 VCR App의 **Preview** 영역에서 실시간으로 확인할 수 있습니다. 전체화면 프리뷰도 지원됩니다.

---

## 프로젝트 구조

```
vcr/
├── lib/                              # VCR App (모바일 앱)
│   ├── main.dart                     #   앱 진입점
│   ├── app.dart                      #   앱 설정 (테마, 라우팅, Provider)
│   ├── core/
│   │   ├── constants.dart            #   상수 정의
│   │   └── theme.dart                #   다크 테마 설정
│   ├── models/
│   │   ├── agent_state.dart          #   Agent 상태 모델
│   │   ├── frame_data.dart           #   화면 프레임 데이터
│   │   ├── terminal_entry.dart       #   터미널 항목 모델
│   │   ├── vcr_message.dart          #   WebSocket 메시지 모델
│   │   └── vcr_response.dart         #   커맨드 응답 모델
│   ├── providers/
│   │   ├── connection_provider.dart   #   연결 상태 관리
│   │   ├── preview_provider.dart      #   프리뷰 상태 관리
│   │   └── terminal_provider.dart     #   터미널 상태 관리
│   ├── screens/
│   │   ├── connection_screen.dart     #   연결 화면 (mDNS 탐색 + 수동 입력)
│   │   ├── terminal_screen.dart       #   터미널 화면 (메인)
│   │   └── preview_screen.dart        #   프리뷰 전체화면
│   ├── services/
│   │   ├── websocket_service.dart     #   WebSocket 통신 서비스
│   │   └── discovery_service.dart     #   mDNS 자동 탐색 서비스
│   └── widgets/
│       ├── terminal_input.dart        #   터미널 입력 위젯
│       ├── terminal_output.dart       #   터미널 출력 위젯
│       ├── preview_viewer.dart        #   프리뷰 뷰어 위젯
│       ├── status_indicator.dart      #   상태 인디케이터 위젯
│       └── server_list_tile.dart      #   서버 목록 타일 위젯
│
├── vcr_agent/                         # VCR Agent (노트북 CLI)
│   ├── bin/
│   │   └── vcr_agent.dart             #   Agent 진입점
│   ├── lib/
│   │   ├── vcr_agent.dart             #   Agent 메인 로직
│   │   ├── server/
│   │   │   ├── websocket_server.dart  #   WebSocket 서버
│   │   │   └── mdns_service.dart      #   mDNS 서비스 등록
│   │   ├── parser/
│   │   │   ├── command_parser.dart    #   커맨드 파서
│   │   │   └── command_types.dart     #   커맨드 타입 정의
│   │   ├── flutter/
│   │   │   ├── flutter_controller.dart#   Flutter 프로세스 제어
│   │   │   ├── code_generator.dart    #   코드 생성기
│   │   │   └── project_manager.dart   #   프로젝트 관리
│   │   └── emulator/
│   │       ├── emulator_controller.dart#  에뮬레이터 제어
│   │       └── screen_capture.dart    #   화면 캡쳐 (ADB)
│   └── pubspec.yaml
│
├── shared/                            # 공유 패키지 (vcr_shared)
│   └── lib/
│       ├── vcr_shared.dart            #   라이브러리 진입점
│       ├── protocol.dart              #   프로토콜 상수
│       ├── commands.dart              #   커맨드 타입 상수
│       └── models/
│           ├── vcr_message.dart       #   메시지 래퍼 모델
│           ├── vcr_command.dart        #   커맨드 모델
│           ├── vcr_response.dart      #   응답 모델
│           ├── frame_data.dart        #   프레임 데이터 모델
│           ├── agent_state.dart       #   Agent 상태 모델
│           └── welcome_data.dart      #   연결 환영 데이터 모델
│
├── docs/                              # 문서
├── test/                              # 테스트
├── android/                           # Android 네이티브
├── ios/                               # iOS 네이티브
└── pubspec.yaml                       # App 패키지 설정
```

---

## 기술 스택

| 분류 | 기술 | 용도 |
|------|------|------|
| 프레임워크 | Flutter / Dart | App(모바일) + Agent(CLI) 모두 Dart로 작성 |
| 통신 | WebSocket | App과 Agent 간 실시간 양방향 통신 |
| 서버 | shelf + shelf_web_socket | Agent 측 WebSocket 서버 구현 |
| 클라이언트 | web_socket_channel | App 측 WebSocket 클라이언트 구현 |
| 상태 관리 | Provider | App 내 상태 관리 (연결, 터미널, 프리뷰) |
| 서비스 탐색 | mDNS (nsd) | 같은 네트워크에서 Agent 자동 탐색 |
| 화면 캡쳐 | ADB (screencap) | 에뮬레이터 화면을 JPEG로 캡쳐하여 전송 |
| 이미지 처리 | image (dart) | 화면 캡쳐 이미지의 JPEG 변환 |
| CLI 파싱 | args | Agent 실행 시 커맨드라인 인자 파싱 |

모든 의존성은 무료/오픈소스입니다.

---

## 문서 목록

`docs/` 폴더에 프로젝트의 상세 설계 문서가 포함되어 있습니다.

| 문서 | 설명 |
|------|------|
| [PRD.md](docs/PRD.md) | 제품 요구사항 문서 (기획서). 프로젝트의 목표, 핵심 컨셉, MVP 기능 정의, 기술 아키텍처를 담고 있습니다. |
| [PROTOCOL.md](docs/PROTOCOL.md) | WebSocket 프로토콜 스키마. App과 Agent 사이의 모든 메시지 타입, JSON 포맷, 연결 수명 주기를 정의합니다. |
| [FEATURE_SPEC.md](docs/FEATURE_SPEC.md) | 기능 명세서. 각 커맨드의 상세 스펙(정규식, 동작 순서, 에러 케이스), UX 플로우, 비기능 요구사항을 포함합니다. |
| [DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) | 개발 계획. Phase별 작업 분해와 일정을 정리합니다. |
| [UI_SPEC.md](docs/UI_SPEC.md) | UI 설계 명세서. 각 화면의 레이아웃, 상태 전이, 디자인 가이드라인을 포함합니다. |
| [ARCHITECTURE_REVIEW.md](docs/ARCHITECTURE_REVIEW.md) | 아키텍처 리뷰 문서. 프로젝트 구조와 설계 결정에 대한 리뷰 내용을 담고 있습니다. |
| [REVIEW_REPORT.md](docs/REVIEW_REPORT.md) | 코드 리뷰 리포트. 구현 코드에 대한 리뷰 결과와 개선 사항을 정리합니다. |
| [ADR-001-project-structure.md](docs/ADR-001-project-structure.md) | Architecture Decision Record. 모노레포 프로젝트 구조 결정 배경을 기록합니다. |
| [ADR-002-screen-transfer.md](docs/ADR-002-screen-transfer.md) | Architecture Decision Record. 화면 전송 방식(JPEG over WebSocket) 결정 배경을 기록합니다. |
| [ADR-003-state-management.md](docs/ADR-003-state-management.md) | Architecture Decision Record. 상태 관리 방식(Provider) 선택 배경을 기록합니다. |

---

## 라이선스

이 프로젝트는 비공개 프로젝트입니다.
