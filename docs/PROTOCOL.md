# VCR WebSocket 프로토콜 스키마

> VCR App(클라이언트) ↔ VCR Agent(서버) 간 통신 규격

---

## 1. 연결 정보

| 항목 | 값 |
|------|-----|
| 프로토콜 | WebSocket (ws://) |
| 기본 포트 | 8765 |
| 서비스 탐색 | mDNS `_vcr._tcp` |
| 메시지 포맷 | JSON (UTF-8 text frame) |

---

## 2. 메시지 구조

모든 메시지는 다음 기본 구조를 따른다:

```json
{
  "type": "<message_type>",
  "id": "<optional_request_id>",
  "payload": { ... }
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `type` | string | Y | 메시지 타입 식별자 |
| `id` | string | N | 요청-응답 매칭용 ID (UUID) |
| `payload` | object | Y | 타입별 데이터 |

---

## 3. 메시지 타입

### 3.1 Client → Server

#### `command` - 커맨드 실행 요청
```json
{
  "type": "command",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "payload": {
    "raw": "create page Home"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `payload.raw` | string | 사용자가 입력한 커맨드 원문 |

#### `ping` - 연결 확인
```json
{
  "type": "ping",
  "payload": {}
}
```

### 3.2 Server → Client

#### `response` - 커맨드 실행 결과
```json
{
  "type": "response",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "payload": {
    "status": "success",
    "message": "Page Home created and hot reload triggered",
    "logs": [
      "Creating lib/pages/home_page.dart...",
      "Updating lib/main.dart routes...",
      "Hot reload triggered"
    ]
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `payload.status` | string | `success` \| `error` \| `warning` |
| `payload.message` | string | 사용자에게 보여줄 요약 메시지 |
| `payload.logs` | string[] | 상세 실행 로그 |

#### `frame` - 에뮬레이터 화면 프레임
```json
{
  "type": "frame",
  "payload": {
    "data": "<base64 encoded JPEG>",
    "width": 1080,
    "height": 1920,
    "seq": 42
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `payload.data` | string | Base64 인코딩된 JPEG 이미지 |
| `payload.width` | int | 이미지 너비 (px) |
| `payload.height` | int | 이미지 높이 (px) |
| `payload.seq` | int | 프레임 시퀀스 번호 (순서 보장/드롭 판단) |

#### `status` - Agent 상태 변경
```json
{
  "type": "status",
  "payload": {
    "state": "hot_reloading",
    "message": "Performing hot reload..."
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `payload.state` | string | 상태 enum (아래 참조) |
| `payload.message` | string | 선택적 상세 메시지 |

**상태 enum 값:**
| 값 | 설명 |
|----|------|
| `idle` | Agent 실행 중, 프로젝트 미실행 |
| `running` | Flutter 앱 실행 중 (정상) |
| `hot_reloading` | Hot reload 진행 중 |
| `hot_restarting` | Hot restart 진행 중 |
| `building` | 빌드 진행 중 |
| `build_error` | 빌드 에러 발생 |
| `error` | 일반 에러 |

#### `pong` - ping 응답
```json
{
  "type": "pong",
  "payload": {}
}
```

#### `welcome` - 연결 직후 서버 정보
```json
{
  "type": "welcome",
  "payload": {
    "agent_version": "0.1.0",
    "project_name": "my_app",
    "project_path": "/Users/dev/projects/my_app",
    "flutter_version": "3.24.0",
    "commands": ["create project", "create page", "add button", "add text", "hot reload", "restart", "status", "help"]
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `payload.agent_version` | string | Agent 버전 |
| `payload.project_name` | string? | 현재 프로젝트명 (없으면 null) |
| `payload.project_path` | string? | 현재 프로젝트 경로 |
| `payload.flutter_version` | string | Flutter 버전 |
| `payload.commands` | string[] | 사용 가능한 커맨드 목록 |

---

## 4. VCR 커맨드 상세 스펙

### 4.1 `create project <name>`
- **파라미터**: name (영문, 소문자, 언더스코어 허용)
- **동작**: `flutter create <name>` 실행 + `flutter run`
- **성공 응답**: `"Project <name> created and running"`
- **에러**: 이미 프로젝트가 실행 중인 경우

### 4.2 `create page <Name>`
- **파라미터**: Name (PascalCase)
- **동작**: `lib/pages/<name>_page.dart` 생성 + 라우트 등록 + hot reload
- **생성 코드**:
```dart
import 'package:flutter/material.dart';

class <Name>Page extends StatelessWidget {
  const <Name>Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('<Name>')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [],
        ),
      ),
    );
  }
}
```

### 4.3 `add button "<text>"`
- **파라미터**: text (따옴표로 감싼 문자열)
- **동작**: 현재 활성 페이지의 Column children에 ElevatedButton 추가 + hot reload
- **생성 코드**:
```dart
ElevatedButton(
  onPressed: () {},
  child: Text('<text>'),
),
```

### 4.4 `add text "<text>"`
- **파라미터**: text (따옴표로 감싼 문자열)
- **동작**: 현재 활성 페이지의 Column children에 Text 추가 + hot reload
- **생성 코드**:
```dart
Text('<text>'),
```

### 4.5 `add image <url>`
- **파라미터**: url (이미지 URL)
- **동작**: Column children에 Image.network 추가 + hot reload
- **생성 코드**:
```dart
Image.network('<url>'),
```

### 4.6 `hot reload`
- **동작**: flutter 프로세스 stdin에 'r' 전송
- **성공 응답**: `"Hot reload complete"`

### 4.7 `restart`
- **동작**: flutter 프로세스 stdin에 'R' 전송
- **성공 응답**: `"Hot restart complete"`

### 4.8 `status`
- **동작**: 현재 Agent 상태 반환
- **응답**: 프로젝트명, 실행 상태, 활성 페이지, 에뮬레이터 상태

### 4.9 `help`
- **동작**: 사용 가능한 커맨드 목록 반환

---

## 5. 에러 코드

| 코드 | 설명 |
|------|------|
| `PARSE_ERROR` | 커맨드 파싱 실패 |
| `PROJECT_NOT_FOUND` | 프로젝트가 없음 |
| `PROJECT_ALREADY_RUNNING` | 이미 실행 중 |
| `FLUTTER_NOT_FOUND` | Flutter SDK 없음 |
| `ADB_NOT_FOUND` | ADB 없음 |
| `EMULATOR_NOT_RUNNING` | 에뮬레이터 미실행 |
| `BUILD_FAILED` | 빌드 실패 |
| `FILE_ERROR` | 파일 생성/수정 실패 |
| `UNKNOWN_COMMAND` | 알 수 없는 커맨드 |

에러 응답 형태:
```json
{
  "type": "response",
  "id": "...",
  "payload": {
    "status": "error",
    "message": "Unknown command: foo bar",
    "error_code": "UNKNOWN_COMMAND",
    "logs": []
  }
}
```

---

## 6. 연결 수명 주기

```
Client                          Server
  |                                |
  |--- WebSocket Connect -------->|
  |<-- welcome -------------------|
  |                                |
  |--- command ------------------->|
  |<-- status (building) ---------|
  |<-- response -------------------|
  |<-- status (running) ----------|
  |<-- frame ----------------------|
  |<-- frame ----------------------|
  |<-- frame ----------------------|
  |    ...                         |
  |                                |
  |--- ping ---------------------->|
  |<-- pong -----------------------|
  |                                |
  |--- WebSocket Close ---------->|
```

### 연결 규칙
1. 클라이언트 연결 시 서버는 즉시 `welcome` 메시지 전송
2. 프레임 스트리밍은 Flutter 앱이 실행 중일 때만 전송
3. 클라이언트는 30초마다 `ping` 전송 (keepalive)
4. 서버가 60초간 ping을 못 받으면 연결 종료
5. 클라이언트는 연결 끊김 시 5초 후 자동 재연결 시도

---

## 7. mDNS 서비스 등록

| 항목 | 값 |
|------|-----|
| 서비스 타입 | `_vcr._tcp` |
| 포트 | 8765 (기본) |
| TXT 레코드 | `version=0.1.0` |

클라이언트는 `_vcr._tcp` 서비스를 탐색하여 Agent IP:Port를 자동으로 발견한다.
