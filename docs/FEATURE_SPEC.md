# VCR 기능 명세서 (Feature Specification)

> Phase 1 산출물 - 개발 에이전트가 참조할 상세 스펙

---

## 1. 기능 요구사항 목록

### 핵심 기능 (P0 - MVP 필수)

| ID | 기능명 | 설명 | 담당 |
|----|--------|------|------|
| FR-001 | WebSocket 서버 | Agent가 포트 8765에서 WS 서버 실행 | `/be-dev` |
| FR-002 | WebSocket 클라이언트 | App이 Agent에 WS 연결 | `/fe-dev` |
| FR-003 | 커맨드 파서 | 사용자 입력을 구조화된 커맨드로 파싱 | `/be-dev` |
| FR-004 | 코드 생성기 | 커맨드를 Flutter 코드로 변환/삽입 | `/be-dev` |
| FR-005 | Flutter 프로세스 제어 | flutter run / hot reload / restart | `/be-dev` |
| FR-006 | 화면 캡쳐 & 전송 | 에뮬레이터 스크린을 JPEG로 캡쳐해 전송 | `/be-dev` |
| FR-007 | 터미널 UI | CLI 스타일 명령 입력 & 결과 표시 | `/fe-dev` |
| FR-008 | 라이브 프리뷰 | 수신된 프레임을 실시간 이미지로 표시 | `/fe-dev` |
| FR-009 | 상태 표시 | 연결/빌드/에러 상태 표시 | `/fe-dev` |
| FR-010 | mDNS 서비스 등록 | Agent가 `_vcr._tcp`로 자신을 등록 | `/be-dev` |
| FR-011 | mDNS 탐색 | App이 LAN에서 Agent를 자동 발견 | `/fe-dev` |

### 보조 기능 (P1 - MVP 포함하되 단순 구현)

| ID | 기능명 | 설명 | 담당 |
|----|--------|------|------|
| FR-012 | 수동 IP 연결 | mDNS 실패 시 IP:Port 직접 입력 | `/fe-dev` |
| FR-013 | 커맨드 히스토리 | 이전 입력 명령 목록 표시 | `/fe-dev` |
| FR-014 | 자동 재연결 | 연결 끊김 시 5초 후 재시도 | `/fe-dev` |
| FR-015 | Keepalive | 30초마다 ping/pong | `/fe-dev` |

---

## 2. VCR 커맨드 언어 상세 스펙

### 2.1 커맨드 파싱 규칙

각 커맨드는 공백으로 토큰 분리. 따옴표로 감싼 문자열은 하나의 토큰으로 처리.

```
<verb> [<noun>] [<argument>]
```

### 2.2 커맨드별 상세

#### CMD-001: `create project <name>`

| 항목 | 값 |
|------|-----|
| 정규식 | `^create\s+project\s+([a-z][a-z0-9_]*)$` |
| 파라미터 | `name`: 영문 소문자 시작, 소문자+숫자+언더스코어 |
| 전제 조건 | 프로젝트가 실행 중이지 않을 것 |
| 동작 순서 | 1. 작업 디렉토리에 `flutter create <name>` 실행 |
| | 2. 생성된 디렉토리로 이동 |
| | 3. `flutter run` 실행 |
| | 4. 빌드 완료 대기 |
| | 5. 화면 캡쳐 시작 |
| 성공 응답 | `"Project <name> created and running"` |
| 에러 케이스 | `PROJECT_ALREADY_RUNNING` - 이미 실행 중 |
| | `FLUTTER_NOT_FOUND` - Flutter SDK 없음 |
| | `PARSE_ERROR` - 이름 형식 불일치 |
| 활성 페이지 변경 | `main` (기본 홈 페이지) |

#### CMD-002: `create page <Name>`

| 항목 | 값 |
|------|-----|
| 정규식 | `^create\s+page\s+([A-Z][a-zA-Z0-9]*)$` |
| 파라미터 | `Name`: PascalCase (대문자 시작) |
| 전제 조건 | 프로젝트가 실행 중일 것 |
| 동작 순서 | 1. `lib/pages/<name_snake>_page.dart` 파일 생성 |
| | 2. 페이지 클래스 코드 작성 (템플릿) |
| | 3. `lib/main.dart`의 라우트 테이블에 등록 |
| | 4. 활성 페이지를 새 페이지로 변경 |
| | 5. hot reload 트리거 |
| 파일 생성 경로 | `lib/pages/<snake_case_name>_page.dart` |
| 이름 변환 | `Home` → `home`, `LoginForm` → `login_form` |
| 성공 응답 | `"Page <Name> created"` |
| 에러 케이스 | `PROJECT_NOT_FOUND` - 프로젝트 미실행 |
| | `FILE_ERROR` - 동일 이름 페이지 존재 |
| | `PARSE_ERROR` - 이름 형식 불일치 |
| 활성 페이지 변경 | 새로 생성된 페이지로 전환 |

**생성 코드 템플릿:**
```dart
import 'package:flutter/material.dart';

class <Name>Page extends StatelessWidget {
  const <Name>Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('<Name>')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [],
        ),
      ),
    );
  }
}
```

**라우트 등록 코드 (main.dart에 삽입):**
```dart
// routes 맵에 추가
'/<snake_name>': (context) => const <Name>Page(),
```

#### CMD-003: `add button "<text>"`

| 항목 | 값 |
|------|-----|
| 정규식 | `^add\s+button\s+"([^"]*)"$` |
| 파라미터 | `text`: 따옴표 내부 문자열 (빈 문자열 허용) |
| 전제 조건 | 프로젝트 실행 중 + 활성 페이지 존재 |
| 동작 순서 | 1. 활성 페이지 파일 읽기 |
| | 2. Column의 children 리스트에 위젯 추가 |
| | 3. 파일 저장 |
| | 4. hot reload 트리거 |
| 코드 삽입 위치 | 활성 페이지의 `children: [` 다음, 마지막 `]` 이전 |
| 성공 응답 | `"Button '<text>' added"` |
| 에러 케이스 | `PROJECT_NOT_FOUND` - 프로젝트 미실행 |
| | `FILE_ERROR` - 페이지 파일 수정 실패 |

**삽입 코드:**
```dart
ElevatedButton(
  onPressed: () {},
  child: Text('<text>'),
),
```

#### CMD-004: `add text "<text>"`

| 항목 | 값 |
|------|-----|
| 정규식 | `^add\s+text\s+"([^"]*)"$` |
| 파라미터 | `text`: 따옴표 내부 문자열 |
| 전제 조건 | 프로젝트 실행 중 + 활성 페이지 존재 |
| 동작 순서 | (CMD-003과 동일, 삽입 코드만 다름) |
| 성공 응답 | `"Text '<text>' added"` |
| 에러 케이스 | (CMD-003과 동일) |

**삽입 코드:**
```dart
Text(
  '<text>',
  style: Theme.of(context).textTheme.bodyLarge,
),
```

#### CMD-005: `add image <url>`

| 항목 | 값 |
|------|-----|
| 정규식 | `^add\s+image\s+(https?://\S+)$` |
| 파라미터 | `url`: http 또는 https URL |
| 전제 조건 | 프로젝트 실행 중 + 활성 페이지 존재 |
| 동작 순서 | (CMD-003과 동일, 삽입 코드만 다름) |
| 성공 응답 | `"Image added"` |
| 에러 케이스 | (CMD-003과 동일) + `PARSE_ERROR` (유효하지 않은 URL) |

**삽입 코드:**
```dart
Image.network(
  '<url>',
  width: 200,
  errorBuilder: (context, error, stackTrace) =>
    const Icon(Icons.broken_image, size: 48),
),
```

#### CMD-006: `hot reload`

| 항목 | 값 |
|------|-----|
| 정규식 | `^hot\s+reload$` |
| 파라미터 | 없음 |
| 전제 조건 | Flutter 프로세스가 실행 중일 것 |
| 동작 | flutter 프로세스의 stdin에 `r` 문자 전송 |
| 성공 응답 | `"Hot reload complete"` |
| 에러 케이스 | `PROJECT_NOT_FOUND` - 프로세스 미실행 |

#### CMD-007: `restart`

| 항목 | 값 |
|------|-----|
| 정규식 | `^restart$` |
| 파라미터 | 없음 |
| 전제 조건 | Flutter 프로세스가 실행 중일 것 |
| 동작 | flutter 프로세스의 stdin에 `R` 문자 전송 |
| 성공 응답 | `"Hot restart complete"` |
| 에러 케이스 | `PROJECT_NOT_FOUND` - 프로세스 미실행 |

#### CMD-008: `status`

| 항목 | 값 |
|------|-----|
| 정규식 | `^status$` |
| 파라미터 | 없음 |
| 동작 | 현재 Agent 상태 정보 조합하여 응답 |
| 응답 내용 | 프로젝트명, 실행 상태, 활성 페이지, 에뮬레이터 상태, 연결 클라이언트 수 |

#### CMD-009: `help`

| 항목 | 값 |
|------|-----|
| 정규식 | `^help$` |
| 파라미터 | 없음 |
| 동작 | 사용 가능한 커맨드 목록과 설명 반환 |

### 2.3 활성 페이지 추적 방식

Agent는 **현재 활성 페이지(current page)** 상태를 유지한다.

```
Agent State:
  currentProject: String?      // 현재 프로젝트 경로
  currentPage: String?         // 현재 활성 페이지 이름 (PascalCase)
  currentPageFile: String?     // 현재 활성 페이지 파일 경로
  flutterProcess: Process?     // flutter run 프로세스
  pages: List<String>          // 생성된 페이지 목록
```

**활성 페이지 변경 규칙:**
1. `create project` 실행 시 → 기본 홈 페이지가 활성
2. `create page X` 실행 시 → X가 활성 페이지로 전환
3. `add *` 커맨드는 항상 활성 페이지에 적용
4. 활성 페이지가 없으면 `add *` 커맨드는 에러 반환

### 2.4 코드 삽입 알고리즘

`add` 계열 커맨드가 실행될 때 코드 삽입 위치를 결정하는 방법:

```
1. 활성 페이지 파일 읽기
2. "children:" 키워드를 포함한 줄 찾기 (마지막 것)
3. 해당 줄 이후의 닫는 "]" 직전 위치 찾기
4. 그 위치에 새 위젯 코드 삽입
5. 파일 저장
```

**구체적 탐색 패턴:**
```
// 이 패턴을 찾아서:
children: const [
  <기존 위젯들>
],

// 닫는 ] 직전에 새 위젯 삽입:
children: const [
  <기존 위젯들>
  <새 위젯>,   ← 여기
],
```

참고: `const` 키워드는 add 커맨드 최초 실행 시 제거해야 함 (런타임 위젯이 들어가므로).

---

## 3. 에러 핸들링 시나리오

### 3.1 네트워크 에러

| 시나리오 | App 동작 | Agent 동작 |
|----------|---------|-----------|
| Wi-Fi 끊김 | 상태를 `Disconnected`로 변경, 5초 후 재연결 시도 | 클라이언트 연결 해제 감지, 프레임 전송 중단 |
| Agent 종료 | WebSocket 에러 감지 → `Disconnected` → 재연결 시도 | N/A |
| App 종료 | N/A | 클라이언트 제거, 프레임 전송 중단 (다른 클라이언트 없으면) |
| 재연결 성공 | `welcome` 수신 → `Connected` → 터미널 화면 복구 | `welcome` 메시지 재전송 |
| 재연결 5회 실패 | 재연결 중단, "연결할 수 없습니다" 표시, Connection Screen으로 이동 | N/A |

### 3.2 빌드 에러

| 시나리오 | App 동작 | Agent 동작 |
|----------|---------|-----------|
| Flutter 빌드 실패 | 상태 `Build Error` 표시, 에러 로그를 터미널에 출력 | `status: build_error` + 에러 메시지 전송 |
| Hot reload 실패 | 에러 메시지 터미널 출력, 상태 유지 | `response: error` + 에러 내용 전송 |
| 코드 생성 에러 | 에러 메시지 터미널 출력 | `response: error` + `FILE_ERROR` |

### 3.3 에뮬레이터 에러

| 시나리오 | App 동작 | Agent 동작 |
|----------|---------|-----------|
| 에뮬레이터 미실행 | "에뮬레이터를 실행해주세요" 메시지 표시 | `EMULATOR_NOT_RUNNING` 에러 반환 |
| ADB 미설치 | 에러 메시지 표시 | `ADB_NOT_FOUND` 에러 반환 |
| 화면 캡쳐 실패 | 마지막 성공 프레임 유지, 프리뷰 일시정지 표시 | 캡쳐 재시도 (3회), 실패 시 캡쳐 일시 중단 |

### 3.4 잘못된 커맨드

| 시나리오 | 처리 |
|----------|------|
| 빈 입력 | 무시 (아무 동작 안 함) |
| 알 수 없는 커맨드 | `UNKNOWN_COMMAND` 에러 + "help를 입력해보세요" 안내 |
| 파라미터 누락 | `PARSE_ERROR` + 올바른 사용법 안내 |
| 잘못된 파라미터 형식 | `PARSE_ERROR` + 형식 설명 (예: "페이지 이름은 대문자로 시작") |

---

## 4. UX 플로우 상세

### 4.1 화면 전이 다이어그램

```
앱 실행
  │
  ▼
[Connection Screen]
  │
  ├─ mDNS 탐색 성공 → 서버 목록 표시
  │   └─ 서버 선택 & 연결 성공 ──────────────────┐
  │                                               │
  ├─ mDNS 탐색 실패 → 수동 IP 입력              │
  │   └─ 연결 성공 ──────────────────────────────┤
  │                                               │
  │                                               ▼
  │                                      [Terminal Screen]
  │                                          │        │
  │   연결 끊김 (재연결 5회 실패)             │        │
  │ ◄─────────────────────────────────────────┘        │
  │                                                    │
  │                                    프리뷰 탭/전환   │
  │                                                    ▼
  │                                           [Preview Screen]
  │                                                    │
  │                                        뒤로가기     │
  │                                           ┌────────┘
  │                                           ▼
  │                                      [Terminal Screen]
  │
```

### 4.2 Connection Screen

**진입 조건:** 앱 최초 실행, 또는 재연결 실패

**화면 구성:**
```
┌─────────────────────────┐
│        VCR              │
│   Vibe Code Runner      │
│                         │
│  ┌───────────────────┐  │
│  │ 🔍 탐색 중...     │  │
│  │                   │  │
│  │  🖥 MacBook (192. │  │
│  │     168.0.5:8765) │  │
│  │                   │  │
│  └───────────────────┘  │
│                         │
│  ─── 또는 직접 입력 ─── │
│                         │
│  IP: [192.168.0.____ ]  │
│  Port: [8765________ ]  │
│                         │
│    [ 연결하기 ]          │
│                         │
└─────────────────────────┘
```

**상태 전이:**
| 이벤트 | 동작 |
|--------|------|
| 화면 진입 | mDNS 탐색 시작 |
| 서버 발견 | 목록에 추가 |
| 서버 탭 | 해당 서버로 연결 시도 |
| 연결하기 탭 | 입력된 IP:Port로 연결 시도 |
| 연결 중 | 로딩 인디케이터 표시 |
| 연결 성공 | Terminal Screen으로 이동 |
| 연결 실패 | 에러 메시지 스낵바 표시 |

**이탈 조건:** WebSocket 연결 성공 + `welcome` 메시지 수신

### 4.3 Terminal Screen (메인)

**진입 조건:** WebSocket 연결 성공

**화면 구성:**
```
┌─────────────────────────┐
│ 🟢 Connected   [📱]     │  ← 상태바 + 프리뷰 토글
├─────────────────────────┤
│                         │
│ > create project my_app │  ← 출력 영역
│ ✓ Project my_app created│
│                         │
│ > create page Home      │
│ ✓ Page Home created     │
│                         │
│ > add button "Login"    │
│ ✓ Button 'Login' added  │
│                         │
│                         │
│                         │
├─────────────────────────┤
│ > _                     │  ← 입력창
└─────────────────────────┘
```

**상태바 UI 변화:**
| Agent 상태 | 표시 |
|-----------|------|
| `idle` | `⚪ Idle` (회색) |
| `running` | `🟢 Running` (초록) |
| `hot_reloading` | `🔄 Reloading...` (파랑, 애니메이션) |
| `hot_restarting` | `🔄 Restarting...` (파랑, 애니메이션) |
| `building` | `🔨 Building...` (노랑, 애니메이션) |
| `build_error` | `🔴 Build Error` (빨강) |
| `error` | `🔴 Error` (빨강) |
| 연결 끊김 | `⚫ Disconnected` (검정) |

**출력 영역 스타일:**
| 타입 | 스타일 |
|------|--------|
| 사용자 입력 | `> ` 접두사, 흰색 |
| 성공 응답 | `✓ ` 접두사, 초록색 |
| 에러 응답 | `✗ ` 접두사, 빨간색 |
| 경고 | `⚠ ` 접두사, 노란색 |
| 로그 | `  ` 접두사 (들여쓰기), 회색 |

**이탈 조건:**
- 프리뷰 토글/탭 → Preview Screen
- 연결 끊김 + 재연결 5회 실패 → Connection Screen

### 4.4 Preview Screen (전체화면)

**진입 조건:** Terminal Screen에서 프리뷰 영역 탭 또는 토글 버튼

**화면 구성:**
```
┌─────────────────────────┐
│                         │
│                         │
│    ┌───────────────┐    │
│    │               │    │
│    │   에뮬레이터   │    │
│    │   화면 프레임  │    │
│    │               │    │
│    │               │    │
│    └───────────────┘    │
│                         │
│              10 fps     │  ← FPS 표시 (디버그)
│                  [ ← ]  │  ← 뒤로가기
└─────────────────────────┘
```

**기능:**
- 핀치 줌 (확대/축소)
- FPS 카운터 (디버그용, 좌측 하단)
- 뒤로가기 → Terminal Screen

**이탈 조건:** 뒤로가기 버튼 또는 시스템 백버튼

---

## 5. 비기능 요구사항

### 5.1 성능

| 항목 | 목표값 |
|------|--------|
| 화면 프레임 전송 | 10fps (100ms 간격) |
| JPEG 품질 | Q40 (품질/크기 균형) |
| 프레임 크기 | ~50-80KB (1080x1920, Q40) |
| 커맨드 응답 지연 | < 500ms (hot reload 제외) |
| Hot reload 지연 | < 3s |
| WebSocket 메시지 크기 제한 | 없음 (프레임은 ~100KB) |
| 메모리: 프레임 버퍼 | 최대 2프레임 (현재 + 이전) |

### 5.2 네트워크

| 항목 | 목표값 |
|------|--------|
| 프로토콜 | WebSocket (ws://) |
| Keepalive 간격 | 30초 (ping) |
| 서버 타임아웃 | 60초 (ping 없으면 연결 종료) |
| 재연결 간격 | 5초 |
| 재연결 최대 시도 | 5회 |
| mDNS 탐색 타임아웃 | 10초 |

### 5.3 저장/캐시

| 항목 | 목표값 |
|------|--------|
| 커맨드 히스토리 | 최대 100개 (메모리, 앱 종료 시 삭제) |
| 마지막 연결 서버 | SharedPreferences에 저장 (IP:Port) |
| 프레임 캐시 | 없음 (현재 프레임만 유지) |

### 5.4 호환성

| 항목 | 대상 |
|------|------|
| App (Android) | Android 5.0+ (API 21+) |
| App (iOS) | iOS 12.0+ |
| Agent (macOS) | macOS 12+ |
| Agent (Linux) | Ubuntu 20.04+ |
| Agent (Windows) | Windows 10+ |
| Flutter SDK | 3.9.x |
| Dart SDK | 3.9.x |

---

## 6. 작업 분해표 (WBS)

### Track A: VCR Agent (`/be-dev`)

| Task ID | 작업명 | 의존성 | 복잡도 |
|---------|--------|--------|--------|
| BE-001 | shared 패키지 초기화 (모델, 프로토콜 상수) | - | S |
| BE-002 | vcr_agent 프로젝트 초기화 (pubspec, CLI 엔트리) | BE-001 | S |
| BE-003 | WebSocket 서버 구현 | BE-002 | M |
| BE-004 | mDNS 서비스 등록 | BE-002 | S |
| BE-005 | 커맨드 파서 구현 (전체 9개 커맨드) | BE-001 | M |
| BE-006 | Flutter 프로세스 컨트롤러 | BE-002 | L |
| BE-007 | 코드 생성기 (페이지 + 위젯 삽입) | BE-005 | L |
| BE-008 | 에뮬레이터 화면 캡쳐 & 전송 | BE-003 | M |
| BE-009 | 전체 파이프라인 통합 (커맨드→파서→코드생성→hot reload→캡쳐) | BE-003~008 | M |

### Track B: VCR App (`/fe-dev`)

| Task ID | 작업명 | 의존성 | 복잡도 |
|---------|--------|--------|--------|
| FE-001 | 프로젝트 구조 셋업 (디렉토리, 테마, 라우팅) | - | S |
| FE-002 | shared 패키지 연동 (모델 참조) | BE-001 | S |
| FE-003 | Provider 셋업 (3개 Provider 정의) | FE-001 | S |
| FE-004 | WebSocket 서비스 구현 | FE-002 | M |
| FE-005 | mDNS 탐색 서비스 구현 | FE-001 | S |
| FE-006 | Connection Screen 구현 | FE-003, FE-005 | M |
| FE-007 | Terminal Screen 구현 (입력 + 출력 + 상태바) | FE-003 | L |
| FE-008 | Preview Screen 구현 (프레임 표시 + 핀치 줌) | FE-003 | M |
| FE-009 | 전체 플로우 통합 (Connection → Terminal → Preview) | FE-004~008 | M |

### Track C: 통합 & 테스트

| Task ID | 작업명 | 의존성 | 복잡도 |
|---------|--------|--------|--------|
| INT-001 | App ↔ Agent WebSocket 연동 테스트 | BE-009, FE-009 | M |
| INT-002 | 커맨드 전송 → 코드 생성 → hot reload E2E | INT-001 | M |
| INT-003 | 화면 캡쳐 → 프리뷰 표시 E2E | INT-001 | M |
| TEST-001 | 커맨드 파서 단위 테스트 | BE-005 | S |
| TEST-002 | 코드 생성기 단위 테스트 | BE-007 | M |
| TEST-003 | WebSocket 메시지 직렬화 테스트 | BE-001 | S |

### 병렬 처리 가능 식별

```
[병렬 Phase 2]
  Track A (BE-001 ~ BE-009): /be-dev
  Track B (FE-001 ~ FE-009): /fe-dev
  * BE-001(shared)이 완료되면 양쪽 동시 진행 가능

[순차 Phase 3]
  INT-001 → INT-002, INT-003 (통합)
  TEST-001 ~ TEST-003 (테스트, 통합과 병렬 가능)

[병렬 Phase 4]
  /reviewer (코드 리뷰)
  /tech-lead (아키텍처 리뷰)
```

---

## 7. 디자이너 전달 사항

`/designer`에게 전달할 핵심 정보:

1. **화면 3개**: Connection Screen, Terminal Screen, Preview Screen
2. **다크 테마 기본** (터미널 감성)
3. **터미널 출력 스타일**: 성공(초록), 에러(빨강), 경고(노랑), 로그(회색)
4. **상태 표시**: 7가지 상태 enum (아이콘 + 색상 + 텍스트)
5. **Terminal Screen이 메인**: 사용 시간의 90%를 여기서 보냄
6. **프리뷰는 보조**: 미니 프리뷰(토글) + 전체화면 옵션
