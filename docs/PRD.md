# VCR - Vibe Code Runner

> 폰에서 터미널을 치면, 노트북에서 앱이 살아난다

---

## 1. Elevator Pitch

VCR은 스마트폰에서 터미널 명령을 입력하면, 같은 Wi-Fi의 노트북에서 Flutter 앱을 실시간으로 실행/미리보기 할 수 있는 **모바일 기반 바이브 코딩 컨트롤러**다.

---

## 2. 문제 정의

### 기존 환경의 불편함
- 개발은 항상 노트북 앞에서만 가능
- 아이디어가 떠올라도 자리로 돌아가서 IDE 열고 빌드 기다려야 함
- "가볍게 만들어보는 감성"이 없음

### VCR이 해결하는 것
- 폰 = 터미널 (명령 입력)
- 노트북 = 실행 엔진 (코드 생성 & 빌드)
- 명령 -> 즉시 실행 결과 확인

> 개발을 행위가 아니라 **리듬(Vibe)**으로 만든다

---

## 3. 핵심 컨셉

### 역할 분리

| 역할 | 디바이스 |
|------|---------|
| 명령 입력 | 스마트폰 |
| 코드 생성 & 실행 | 노트북 |
| 결과 미리보기 | 스마트폰 |
| 빌드 / 컴파일 | 노트북 |

- 폰은 IDE가 아니다
- IDE를 **조종하는 리모컨**이다

---

## 4. 타겟 사용자

### 1차 타겟
- Flutter 개발자
- 사이드 프로젝트 많은 개발자
- 바이브 코딩 / AI 코딩에 관심 많은 사람

### 2차 확장
- 디자이너 + 개발 협업
- 발표 / 데모 상황
- 교육용 (코딩 시연)

---

## 5. MVP 기능 정의

### 5.1 VCR App (모바일 - Flutter)

#### 5.1.1 터미널 UI
- CLI 스타일 입력창
- 커맨드 히스토리 (위/아래 스크롤)
- 명령 결과 표시 (성공/실패/로그)

#### 5.1.2 Live Preview
- 노트북 Android Emulator 화면 스트리밍
- JPEG 프레임 수신 및 표시
- 전체 화면 전환 가능

#### 5.1.3 상태 표시
- `Connected` - 연결됨
- `Hot Reloading` - 리로딩 중
- `Build Error` - 빌드 에러
- `Disconnected` - 연결 끊김

#### 5.1.4 연결 관리
- 같은 Wi-Fi 내 VCR Agent 자동 탐색 (mDNS)
- 수동 IP 입력 지원
- 연결 상태 실시간 표시

### 5.2 VCR Agent (노트북 - Dart CLI)

#### 5.2.1 로컬 WebSocket 서버
- WebSocket 서버 실행 (기본 포트: 8765)
- JSON 메시지 포맷
- mDNS 서비스 등록 (자동 탐색용)

#### 5.2.2 Flutter 프로젝트 제어
- `flutter create` 래핑
- 코드 파일 생성/수정
- `flutter run` 실행
- hot reload / hot restart 트리거

#### 5.2.3 Emulator 화면 캡쳐
- `adb exec-out screencap -p` 실행
- JPEG 변환 후 WebSocket으로 전송
- 10~20fps 타겟

#### 5.2.4 VCR 커맨드 파서
- 커맨드 문자열 -> Flutter 코드 변환
- 코드 생성 후 파일 쓰기 -> hot reload

---

## 6. 기술 아키텍처

```
[스마트폰 - VCR App]          [노트북 - VCR Agent]
      |                              |
      | <-- WebSocket (JSON) -->     |
      |                              |
   터미널 UI                    WebSocket Server
   Live Preview                 Command Parser
   상태 표시                    Flutter Controller
                                Emulator Controller
                                Screen Capture
```

### 통신 프로토콜 (WebSocket JSON)

#### 클라이언트 -> 서버 (Command)
```json
{
  "type": "command",
  "payload": {
    "raw": "create page Home",
    "timestamp": 1706700000
  }
}
```

#### 서버 -> 클라이언트 (Response)
```json
{
  "type": "response",
  "payload": {
    "status": "success",
    "message": "Page Home created",
    "logs": ["Creating lib/pages/home.dart...", "Running hot reload..."]
  }
}
```

#### 서버 -> 클라이언트 (Screen Frame)
```json
{
  "type": "frame",
  "payload": {
    "data": "<base64 JPEG>",
    "width": 1080,
    "height": 1920,
    "timestamp": 1706700001
  }
}
```

#### 서버 -> 클라이언트 (Status Update)
```json
{
  "type": "status",
  "payload": {
    "state": "connected|hot_reloading|build_error|disconnected",
    "message": "optional detail"
  }
}
```

---

## 7. VCR 커맨드 언어 (MVP 스펙)

| 커맨드 | 설명 | 예시 |
|--------|------|------|
| `create project <name>` | Flutter 프로젝트 생성 | `create project my_app` |
| `create page <Name>` | 새 페이지 생성 | `create page Home` |
| `add button "<text>"` | 현재 페이지에 버튼 추가 | `add button "Login"` |
| `add text "<text>"` | 현재 페이지에 텍스트 추가 | `add text "Welcome"` |
| `add image <url>` | 이미지 위젯 추가 | `add image https://...` |
| `hot reload` | Hot reload 실행 | `hot reload` |
| `restart` | Hot restart 실행 | `restart` |
| `status` | 현재 상태 확인 | `status` |
| `help` | 사용 가능한 커맨드 목록 | `help` |

> 내부적으로 Flutter 코드로 변환됨. 사용자는 코드를 몰라도 됨.

---

## 8. UX 플로우

1. 노트북에서 `vcr-agent` 실행
2. 폰에서 VCR App 실행
3. 같은 Wi-Fi 자동 연결 (또는 IP 수동 입력)
4. 폰에서 터미널 명령 입력
5. 노트북에서 코드 생성 & Flutter 실행
6. 에뮬레이터 화면이 폰에 실시간 표시

> **"쳤다 -> 보인다"**

---

## 9. MVP에서 제외한 것

- APK / IPA 빌드 배포
- 전체 노트북 화면 미러링
- 실 디바이스 연결 (에뮬레이터만)
- 코드 에디터 기능
- 터치 입력 전달
- AI 코드 생성 (2차)
- 자동완성 (2차)

---

## 10. 프로젝트 구조 (목표)

```
vcr/
├── docs/
│   ├── PRD.md                    # 이 문서
│   └── DEVELOPMENT_PLAN.md       # 개발 플랜
├── lib/                          # VCR App (모바일)
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants.dart
│   │   ├── theme.dart
│   │   └── router.dart
│   ├── models/
│   │   ├── vcr_command.dart
│   │   ├── vcr_response.dart
│   │   └── connection_state.dart
│   ├── services/
│   │   ├── websocket_service.dart
│   │   ├── discovery_service.dart
│   │   └── command_service.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── terminal_screen.dart
│   │   ├── preview_screen.dart
│   │   └── connection_screen.dart
│   └── widgets/
│       ├── terminal_input.dart
│       ├── terminal_output.dart
│       ├── preview_viewer.dart
│       ├── status_indicator.dart
│       └── command_history.dart
├── vcr_agent/                    # VCR Agent (노트북 CLI)
│   ├── bin/
│   │   └── vcr_agent.dart
│   ├── lib/
│   │   ├── server/
│   │   │   ├── websocket_server.dart
│   │   │   └── mdns_service.dart
│   │   ├── parser/
│   │   │   ├── command_parser.dart
│   │   │   └── command_types.dart
│   │   ├── flutter/
│   │   │   ├── flutter_controller.dart
│   │   │   ├── code_generator.dart
│   │   │   └── project_manager.dart
│   │   └── emulator/
│   │       ├── emulator_controller.dart
│   │       └── screen_capture.dart
│   ├── pubspec.yaml
│   └── test/
├── pubspec.yaml
├── android/
├── ios/
└── test/
```

---

## 11. 정체성

> **VCR은 개발 도구가 아니라, 개발을 '리듬'으로 만드는 도구다.**
