# VCR - Vibe Code Runner

> **폰에서 터미널을 치면, 노트북에서 앱이 살아난다**

VCR은 스마트폰에서 터미널 명령을 입력하면 노트북에서 Flutter 앱을 실시간으로 생성/실행/미리보기 할 수 있는 **모바일 기반 바이브 코딩 컨트롤러**입니다. 코드를 몰라도 됩니다. 명령만 치면 앱이 만들어집니다.

---

## 📱 핵심 컨셉

```
┌────────────────────┐           WebSocket           ┌────────────────────┐
│   📱 스마트폰       │ <──────────────────────────> │   💻 노트북        │
│                    │                                │                    │
│  • 터미널 명령 입력 │                                │  • WebSocket 서버  │
│  • 실시간 프리뷰    │                                │  • 명령 파싱       │
│  • 상태 모니터링    │                                │  • Flutter 제어    │
│                    │                                │  • 화면 스트리밍   │
└────────────────────┘                                └────────────────────┘
```

| 역할 | 디바이스 |
|------|---------|
| 명령 입력 | 📱 스마트폰 (VCR App) |
| 코드 생성 & 실행 | 💻 노트북 (VCR Agent) |
| 결과 미리보기 | 📱 스마트폰 (실시간 화면) |
| 빌드 / 컴파일 | 💻 노트북 (Flutter SDK) |

**폰은 IDE가 아니라, IDE를 조종하는 리모컨입니다.**

---

## 🚀 빠른 시작

### 1. 사전 요구사항

| 항목 | 버전/조건 |
|------|-----------|
| Flutter SDK | 3.9 이상 |
| Dart SDK | 3.9 이상 |
| Android Emulator | 실행 가능 (개발용) |
| ADB | 설치 및 PATH 등록 |
| 네트워크 | 아래 둘 중 하나 선택 |

**네트워크 연결 방법:**

#### 🏠 옵션 1: 같은 Wi-Fi (가장 간단)
- 스마트폰과 노트북이 **같은 Wi-Fi 네트워크**에 연결
- mDNS 자동 탐색으로 Agent 자동 발견
- 설정 없이 바로 사용 가능

#### 🌐 옵션 2: 외부 네트워크 (LTE/5G)
데이터를 켜고 어디서든 사용하려면 **Tailscale** 설치 필요:

**노트북:**
```bash
# macOS
brew install tailscale
sudo tailscale up

# Linux
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

**스마트폰:**
1. App Store/Play Store에서 **Tailscale** 앱 설치
2. 노트북과 같은 계정으로 로그인
3. VCR App에서 Tailscale IP로 연결 (100.x.x.x 형태)

> 💡 **Tailscale이란?** 무료 VPN 서비스로, 어디서든 같은 가상 네트워크에 있는 것처럼 연결됩니다. 포트포워딩이나 복잡한 설정 없이 5분이면 완료!

자세한 내용은 [외부 접속 가이드](docs/remote-terminal-access-guide.md) 참고

---

### 2. 설치

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

### 3. 실행

#### Step 1: Android Emulator 실행 (노트북)

```bash
# 사용 가능한 에뮬레이터 목록
emulator -list-avds

# 에뮬레이터 실행
emulator -avd Pixel_7_API_34

# 확인
adb devices
# List of devices attached
# emulator-5554   device
```

#### Step 2: VCR Agent 실행 (노트북)

```bash
cd vcr_agent
dart run bin/vcr_agent.dart --port 8765
```

출력 예시:
```
 __     _______ ____
 \ \   / / ____|  _ \
  \ \ / / |    | |_) |
   \ V /| |    |  _ <
    \ / | |____| |_) |
     \/  \_____|____/
  Vibe Code Runner - Agent v0.1.0

[12:00:00] Starting VCR Agent v0.1.0
[12:00:00] WebSocket server: ws://192.168.0.10:8765
[12:00:00] mDNS service registered: vcr._tcp.local
[12:00:00] Ready to accept connections
```

#### Step 3: VCR App 실행 (스마트폰)

```bash
# 스마트폰을 USB로 연결하거나 무선 디버깅 설정 후
flutter run
```

#### Step 4: 연결

1. VCR App이 실행되면 **Connection Screen** 표시
2. **같은 Wi-Fi**: 자동으로 Agent가 목록에 표시됨 → 탭해서 연결
3. **Tailscale**: 수동 입력으로 Tailscale IP (100.x.x.x) 입력 → CONNECT
4. 연결되면 **Terminal Screen**으로 전환

---

## 📝 명령어 가이드

### 기본 명령어

| 명령어 | 설명 | 예시 |
|--------|------|------|
| `create project <name>` | Flutter 프로젝트 생성 및 실행 | `create project my_app` |
| `create page <Name>` | 새 페이지 생성 (PascalCase) | `create page Home` |
| `add button "<text>"` | 버튼 추가 | `add button "Login"` |
| `add text "<text>"` | 텍스트 추가 | `add text "Welcome"` |
| `add image <url>` | 네트워크 이미지 추가 | `add image https://picsum.photos/200` |
| `hot reload` | Hot reload 실행 | `hot reload` |
| `restart` | Hot restart 실행 | `restart` |
| `status` | 현재 상태 확인 | `status` |
| `help` | 도움말 표시 | `help` |

### 사용 예시

```bash
# 1. 프로젝트 생성
> create project hello_world
✓ Project hello_world created and running

# 2. 홈 페이지 생성
> create page Home
✓ Page Home created

# 3. UI 요소 추가
> add text "Welcome to VCR"
✓ Text 'Welcome to VCR' added

> add button "Get Started"
✓ Button 'Get Started' added

> add image https://picsum.photos/300/200
✓ Image added

# 4. 변경사항 반영
> hot reload
✓ Hot reload complete

# 5. 상태 확인
> status
  Project: hello_world
  Status: running
  Active Page: Home
  Emulator: connected (emulator-5554)
  Pages: [Home]
```

화면은 VCR App의 **Preview** 영역에서 실시간으로 확인됩니다!

---

## 📂 프로젝트 구조

```
vcr/
├── lib/                              # 📱 VCR App (Flutter 모바일 앱)
│   ├── main.dart                     # 앱 진입점
│   ├── app.dart                      # 앱 설정 (테마, 라우팅, Provider)
│   ├── core/                         # 핵심 설정
│   │   ├── constants.dart
│   │   └── theme.dart
│   ├── models/                       # 데이터 모델
│   │   ├── agent_state.dart          # Agent 상태
│   │   ├── frame_data.dart           # 화면 프레임
│   │   ├── terminal_entry.dart       # 터미널 항목
│   │   ├── vcr_message.dart          # WebSocket 메시지
│   │   └── vcr_response.dart         # 응답
│   ├── providers/                    # 상태 관리 (Provider)
│   │   ├── connection_provider.dart  # 연결 상태
│   │   ├── preview_provider.dart     # 프리뷰 상태
│   │   └── terminal_provider.dart    # 터미널 상태
│   ├── screens/                      # 화면
│   │   ├── connection_screen.dart    # 연결 화면
│   │   ├── terminal_screen.dart      # 터미널 화면 (메인)
│   │   └── preview_screen.dart       # 프리뷰 전체화면
│   ├── services/                     # 서비스 로직
│   │   ├── websocket_service.dart    # WebSocket 통신
│   │   ├── discovery_service.dart    # mDNS 자동 탐색
│   │   └── server_storage_service.dart # 서버 저장
│   └── widgets/                      # 재사용 위젯
│       ├── terminal_input.dart
│       ├── terminal_output.dart
│       ├── preview_viewer.dart
│       ├── status_indicator.dart
│       └── server_list_tile.dart
│
├── vcr_agent/                        # 💻 VCR Agent (Dart CLI)
│   ├── bin/
│   │   └── vcr_agent.dart            # Agent 진입점
│   ├── lib/
│   │   ├── vcr_agent.dart            # 메인 로직
│   │   ├── server/                   # 서버
│   │   │   ├── websocket_server.dart # WebSocket 서버
│   │   │   └── mdns_service.dart     # mDNS 서비스
│   │   ├── parser/                   # 명령 파서
│   │   │   ├── command_parser.dart
│   │   │   └── command_types.dart
│   │   ├── flutter/                  # Flutter 제어
│   │   │   ├── flutter_controller.dart
│   │   │   ├── code_generator.dart
│   │   │   └── project_manager.dart
│   │   ├── emulator/                 # 에뮬레이터
│   │   │   ├── emulator_controller.dart
│   │   │   ├── device_controller.dart
│   │   │   └── screen_capture.dart
│   │   ├── network/                  # 네트워크
│   │   │   └── ddns_service.dart
│   │   └── shell/                    # 셸 관리
│   │       └── shell_manager.dart
│   └── pubspec.yaml
│
├── shared/                           # 🔗 공유 패키지 (vcr_shared)
│   └── lib/
│       ├── vcr_shared.dart           # 라이브러리 진입점
│       ├── protocol.dart             # 프로토콜 상수
│       ├── commands.dart             # 커맨드 상수
│       └── models/                   # 공유 모델
│           ├── vcr_message.dart
│           ├── vcr_command.dart
│           ├── vcr_response.dart
│           ├── frame_data.dart
│           ├── agent_state.dart
│           └── welcome_data.dart
│
├── docs/                             # 📄 문서
│   ├── PRD.md                        # 제품 요구사항 문서
│   ├── PROTOCOL.md                   # WebSocket 프로토콜
│   ├── FEATURE_SPEC.md               # 기능 명세서
│   ├── DEVELOPMENT_PLAN.md           # 개발 계획
│   ├── UI_SPEC.md                    # UI 설계 명세서
│   ├── EXTERNAL_ACCESS_GUIDE.md      # 외부 접속 가이드 (DDNS)
│   ├── remote-terminal-access-guide.md # 터미널 원격 접속 (Tailscale)
│   └── ADR-*.md                      # Architecture Decision Records
│
├── android/                          # Android 네이티브
├── ios/                              # iOS 네이티브
├── test/                             # 테스트
└── pubspec.yaml                      # App 패키지 설정
```

---

## 🛠 기술 스택

| 분류 | 기술 | 용도 |
|------|------|------|
| **프레임워크** | Flutter / Dart | App(모바일) + Agent(CLI) 모두 Dart |
| **통신** | WebSocket | App ↔ Agent 실시간 양방향 통신 |
| **서버** | shelf + shelf_web_socket | Agent 측 WebSocket 서버 |
| **클라이언트** | web_socket_channel | App 측 WebSocket 클라이언트 |
| **상태 관리** | Provider | App 상태 관리 (연결, 터미널, 프리뷰) |
| **서비스 탐색** | mDNS (nsd) | 같은 네트워크에서 Agent 자동 탐색 |
| **로컬 저장** | shared_preferences | 서버 목록 로컬 저장 |
| **화면 캡쳐** | ADB (screencap) | 에뮬레이터 화면 JPEG 캡쳐 |
| **이미지 처리** | image (dart) | 화면 캡쳐 이미지 JPEG 변환 |
| **CLI 파싱** | args | Agent 실행 시 인자 파싱 |
| **터미널 UI** | xterm | 터미널 인터페이스 렌더링 |

모든 의존성은 **무료/오픈소스**입니다.

---

## 🌐 네트워크 연결 상세 가이드

### 📡 옵션 1: 같은 Wi-Fi (로컬 네트워크)

**장점:**
- ✅ 설정 없음 (mDNS 자동 탐색)
- ✅ 빠른 속도
- ✅ 안전 (외부 노출 없음)

**작동 방식:**
1. VCR Agent가 mDNS 서비스 등록 (`_vcr._tcp.local`)
2. VCR App이 같은 네트워크에서 자동 검색
3. 서버 목록에 자동 표시

**사용 시나리오:**
- 집/사무실에서 작업할 때
- 가장 안전하고 빠른 방법

---

### 🌍 옵션 2: Tailscale (외부 네트워크)

**장점:**
- ✅ 어디서든 연결 가능 (LTE/5G)
- ✅ 포트포워딩 불필요
- ✅ 자동 암호화 (WireGuard)
- ✅ 완전 무료 (개인용)
- ✅ 5분 설정

**설정 방법:**

#### 노트북 설정

```bash
# macOS
brew install tailscale
sudo tailscale up

# Linux
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Windows
# https://tailscale.com/download/windows 에서 설치

# Tailscale IP 확인
tailscale ip -4
# 출력 예: 100.64.0.1
```

#### 스마트폰 설정

1. **App Store (iOS)** 또는 **Play Store (Android)**에서 **Tailscale** 검색
2. 앱 설치 후 노트북과 같은 계정으로 로그인
3. VCR App 실행
4. Connection Screen에서 **수동 입력**:
   - IP Address: `100.64.0.1` (노트북의 Tailscale IP)
   - Port: `8765`
5. **CONNECT** 탭

#### VCR Agent 실행 (Tailscale 사용 시)

```bash
cd vcr_agent
dart run bin/vcr_agent.dart --port 8765
```

> 💡 **Tailscale이 켜져 있으면** Agent가 Tailscale IP (100.x.x.x)를 자동 감지합니다!

**사용 시나리오:**
- 외출 중에 집 노트북에 연결
- 카페에서 사무실 노트북 제어
- 다른 네트워크에 있는 기기끼리 연결

**자세한 가이드:** [docs/remote-terminal-access-guide.md](docs/remote-terminal-access-guide.md)

---

### 🔒 옵션 3: DDNS + 포트포워딩 (고급)

**장점:**
- ✅ 도메인 기반 접속 (예: `myvcr.duckdns.org`)
- ✅ 무료 (Duck DNS)

**단점:**
- ❌ 공유기 설정 필요
- ❌ 보안 주의 필요

**설정 방법:**

1. Duck DNS 가입 및 도메인 생성 (https://www.duckdns.org)
2. 공유기에서 포트포워딩 설정 (8765 → 노트북 IP)
3. VCR Agent 실행 (DDNS 자동 업데이트):

```bash
dart run vcr_agent \
  --ddns-domain myvcr.duckdns.org \
  --ddns-token YOUR_DUCK_DNS_TOKEN
```

4. VCR App에서 `myvcr.duckdns.org:8765`로 연결

**사용 시나리오:**
- 외부에서 고정 도메인으로 접속하고 싶을 때
- Tailscale을 사용할 수 없는 환경

**자세한 가이드:** [docs/EXTERNAL_ACCESS_GUIDE.md](docs/EXTERNAL_ACCESS_GUIDE.md)

---

### 🤔 어떤 방법을 선택해야 하나요?

| 상황 | 추천 방법 |
|------|----------|
| 집/사무실에서만 사용 | **같은 Wi-Fi** (가장 간단) |
| 외출 중에도 사용하고 싶음 | **Tailscale** (가장 추천) |
| 도메인으로 접속하고 싶음 | **DDNS + 포트포워딩** |

**대부분의 경우 Tailscale을 추천합니다!** 설정이 간단하고 안전하며 무료입니다.

---

## 📚 문서

`docs/` 폴더에 프로젝트의 상세 설계 문서가 있습니다.

| 문서 | 설명 |
|------|------|
| [PRD.md](docs/PRD.md) | 제품 요구사항 문서 (프로젝트 목표, 핵심 컨셉) |
| [PROTOCOL.md](docs/PROTOCOL.md) | WebSocket 프로토콜 스키마 (메시지 포맷) |
| [FEATURE_SPEC.md](docs/FEATURE_SPEC.md) | 기능 명세서 (커맨드 상세 스펙) |
| [UI_SPEC.md](docs/UI_SPEC.md) | UI 설계 명세서 (화면 레이아웃) |
| [DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) | 개발 계획 (Phase별 작업) |
| [EXTERNAL_ACCESS_GUIDE.md](docs/EXTERNAL_ACCESS_GUIDE.md) | 외부 접속 가이드 (DDNS, 포트포워딩) |
| [remote-terminal-access-guide.md](docs/remote-terminal-access-guide.md) | 터미널 원격 접속 가이드 (Tailscale, SSH) |
| [ADR-*.md](docs/) | Architecture Decision Records |

---

## 🔧 고급 사용법

### 저장된 서버 관리

VCR App은 연결에 성공한 서버를 자동으로 저장합니다:

- **Connection Screen** 상단에 **Saved Servers** 표시
- 다음 실행 시 저장된 서버를 탭하면 바로 연결
- 길게 눌러서 삭제 가능

### Agent 옵션

```bash
# 포트 변경
dart run vcr_agent --port 9000

# DDNS 자동 업데이트 (Duck DNS)
dart run vcr_agent \
  --ddns-domain myvcr.duckdns.org \
  --ddns-token YOUR_TOKEN

# 도움말
dart run vcr_agent --help
```

### 디버깅

```bash
# Agent 로그 확인
dart run vcr_agent --verbose

# App 로그 확인 (터미널)
flutter run --verbose
```

---

## ❓ 문제 해결

### 연결이 안 될 때

| 문제 | 해결 방법 |
|------|----------|
| Agent가 목록에 안 보임 (같은 Wi-Fi) | 1. 노트북과 스마트폰이 **정말** 같은 Wi-Fi인지 확인<br>2. Agent가 실행 중인지 확인<br>3. 방화벽 체크 |
| "Connection refused" | 1. Agent가 실행 중인지 확인<br>2. 포트 번호 확인 (기본 8765)<br>3. 방화벽에서 포트 열기 |
| Tailscale 연결 안 됨 | 1. 노트북과 스마트폰 **모두** Tailscale 실행 중인지 확인<br>2. 같은 계정으로 로그인했는지 확인<br>3. `tailscale status`로 상태 확인 |
| 화면이 안 보임 | 1. Android Emulator가 실행 중인지 확인<br>2. `adb devices`로 에뮬레이터 연결 확인 |

### 방화벽 설정

**macOS:**
```bash
# 시스템 설정 > 네트워크 > 방화벽 > 옵션
# VCR Agent 또는 Dart 허용
```

**Windows:**
```bash
# Windows Defender 방화벽 > 앱 허용
# Dart 또는 VCR Agent 허용
```

**Linux:**
```bash
sudo ufw allow 8765/tcp
```

---

## 🎯 로드맵

### ✅ 완료
- [x] WebSocket 기반 실시간 통신
- [x] 기본 명령어 (`create project`, `create page`, `add button/text/image`)
- [x] 에뮬레이터 화면 스트리밍
- [x] mDNS 자동 탐색
- [x] 저장된 서버 관리
- [x] Tailscale 지원
- [x] DDNS 자동 업데이트

---

### 오픈소스 라이선스

이 프로젝트는 다음 오픈소스 패키지를 사용합니다:

| 패키지 | 라이선스 | 용도 |
|--------|---------|------|
| Flutter / Dart | BSD-3-Clause | 프레임워크 |
| provider | MIT | 상태 관리 |
| web_socket_channel | BSD-3-Clause | WebSocket 통신 |
| shelf | BSD-3-Clause | HTTP 서버 |
| shelf_web_socket | BSD-3-Clause | WebSocket 서버 |
| shared_preferences | BSD-3-Clause | 로컬 저장소 |
| nsd | MIT | mDNS 서비스 탐색 |
| xterm | MIT | 터미널 UI |
| cupertino_icons | MIT | iOS 스타일 아이콘 |
| image | MIT | 이미지 처리 |
| http | BSD-3-Clause | HTTP 클라이언트 |
| args | BSD-3-Clause | CLI 인자 파싱 |

---

## 🙏 크레딧

**VCR**은 개발을 **행위**가 아니라 **리듬(Vibe)**으로 만들자는 철학으로 시작되었습니다.

Made with ❤️ using Flutter & Dart

---

## 📞 지원

문제가 발생하거나 질문이 있으신가요?

1. [Issues](../../issues)에서 기존 이슈 검색
2. 새 이슈 생성 (버그 리포트/기능 요청)
3. [docs/](docs/) 폴더의 상세 문서 참고

---

## ⚠️ 면책 조항

**본 프로젝트(VCR - Vibe Code Runner)는 교육 및 개발 목적으로 제공됩니다.**

- 본 소프트웨어를 사용함으로써 발생하는 **모든 결과 및 책임은 사용자 본인에게 있습니다**.
- 개발자는 본 소프트웨어의 사용으로 인해 발생하는 어떠한 직접적, 간접적, 우발적, 특수한 또는 결과적 손해에 대해 책임을 지지 않습니다.
- 네트워크 연결 시 보안을 고려하여 사용하시기 바라며, 외부 네트워크 노출 시 발생할 수 있는 보안 문제는 사용자의 책임입니다.
- 본 프로젝트는 "있는 그대로(AS-IS)" 제공되며, 명시적 또는 묵시적 보증 없이 제공됩니다.

**USE AT YOUR OWN RISK.**

---

**Happy Vibing! 🎵**
