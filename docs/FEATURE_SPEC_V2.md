# VCR 기능 재정의 명세서 V2

> **Pivot**: VCR 명령어 중심 → 순수 터미널 리모트 컨트롤러

---

## 1. 개요

### 목적
VCR 앱을 **노트북 터미널의 원격 제어기**로 재정의한다. 폰에서 노트북의 시스템 셸을 직접 제어하고, 실시간으로 터미널 출력을 확인한다.

### 핵심 변경
| 항목 | Before (V1) | After (V2) |
|------|-------------|------------|
| 메인 기능 | VCR 9개 명령어 (create, add 등) | 노트북 셸 원격 제어 |
| 터미널 UI | 명령어 출력 리스트 (TerminalOutput) | xterm 풀 터미널 뷰 |
| 입력 처리 | VCR 파서 → 코드 생성 | 셸 패스스루 (입력 그대로 전달) |
| 셸 모드 | 수동 토글 (부가 기능) | 자동 시작 (기본 모드) |
| 연결 후 동작 | welcome 메시지 표시 | 즉시 터미널 화면 + 셸 출력 |

### 대상 사용자
- 노트북에서 작업 중인 개발자가 폰으로 터미널 접근이 필요할 때
- 자리를 비운 상태에서도 노트북 작업 상태를 확인하고 명령을 실행하고 싶을 때
- 코딩 중 보조 터미널이 필요할 때 (빌드, 로그 확인 등)

### 기대 효과
- 노트북 앞에 앉지 않아도 터미널 명령 실행 가능
- 이미 실행 중인 터미널 세션을 폰에서 이어서 확인
- "쳤다 → 실행된다"의 직관적 경험

---

## 2. 기능 요구사항

### 핵심 기능 (P0 - 필수)

| ID | 기능명 | 설명 | 우선순위 |
|----|--------|------|----------|
| FR-V2-001 | 자동 셸 시작 | Agent 연결 시 노트북에 시스템 셸 자동 시작 | P0 |
| FR-V2-002 | 셸 세션 유지 | 이미 실행 중인 셸이 있으면 재시작하지 않고 유지 | P0 |
| FR-V2-003 | 셸 출력 버퍼링 | 셸 출력을 버퍼에 저장하여 새 클라이언트에 전달 | P0 |
| FR-V2-004 | xterm 메인 뷰 | 연결 즉시 xterm TerminalView를 메인 화면에 표시 | P0 |
| FR-V2-005 | 셸 명령어 패스스루 | 입력창 텍스트를 셸로 직접 전달 (Enter 포함) | P0 |
| FR-V2-006 | 실시간 출력 스트리밍 | 셸 stdout/stderr를 실시간으로 xterm에 표시 | P0 |

### 보조 기능 (P1 - MVP 포함)

| ID | 기능명 | 설명 | 우선순위 |
|----|--------|------|----------|
| FR-V2-007 | VCR 명령어 (secondary) | `:vcr <command>` 접두사로 기존 VCR 명령어 접근 | P1 |
| FR-V2-008 | 셸 상태 표시 | 상태바에 셸 활성/비활성 상태 표시 | P1 |
| FR-V2-009 | 명령어 히스토리 | 입력한 셸 명령어 히스토리 (로컬) | P1 |

### 비기능 요구사항

| 항목 | 목표값 |
|------|--------|
| 셸 출력 지연 | < 100ms (LAN 환경) |
| 출력 버퍼 크기 | 최대 50KB |
| xterm 최대 라인 | 10,000 라인 |
| 재연결 시 세션 복원 | 즉시 (버퍼 내용 전송) |

---

## 3. 사용자 흐름

### 3.1 메인 플로우: 연결 → 터미널 사용

```
1. 폰에서 VCR 앱 실행
2. Connection Screen에서 Agent 자동 탐색 (mDNS)
3. Agent 선택 → WebSocket 연결
4. Agent가 welcome 메시지 전송 (shellActive: true/false)
5. Agent가 셸 미실행 시 → 자동으로 ShellManager.start()
6. Agent가 셸 실행 중이면 → 출력 버퍼를 클라이언트에 전송
7. 앱이 Terminal Screen으로 전환 → xterm TerminalView 표시
8. 셸 출력이 실시간 스트리밍 (shell_output → xterm)
9. 사용자가 입력창에 "ls -la" 입력 → Enter
10. shell_input 메시지로 "ls -la\n" 전송
11. Agent의 셸에서 ls -la 실행
12. 결과가 shell_output으로 앱에 전달 → xterm에 표시
```

### 3.2 재연결 플로우: 세션 복원

```
1. 앱이 연결 끊김 감지
2. 5초 후 자동 재연결 시도
3. 재연결 성공 → welcome 메시지 수신 (shellActive: true)
4. Agent가 기존 셸 세션의 출력 버퍼를 전송 (isHistory: true)
5. 앱이 버퍼 내용을 xterm에 기록 → 이전 화면 복원
6. 이후 실시간 셸 출력 계속 수신
```

### 3.3 VCR 명령어 접근 (secondary)

```
1. 입력창에 ":vcr create project my_app" 입력
2. 앱이 ":vcr " 접두사 감지
3. "create project my_app"을 command 타입 메시지로 전송
4. Agent가 기존 VCR 명령어 파서로 처리
5. 응답(response)을 xterm에 표시 (또는 별도 알림)
```

---

## 4. 프로토콜 변경사항

### 4.1 welcome 메시지 확장

**변경 전:**
```json
{
  "type": "welcome",
  "payload": {
    "agent_version": "0.1.0",
    "project_name": "my_app",
    "project_path": "/Users/dev/projects/my_app",
    "flutter_version": "3.24.0",
    "commands": ["create project", ...]
  }
}
```

**변경 후:**
```json
{
  "type": "welcome",
  "payload": {
    "agent_version": "0.2.0",
    "project_name": "my_app",
    "project_path": "/Users/dev/projects/my_app",
    "flutter_version": "3.24.0",
    "commands": ["create project", ...],
    "shell_active": true
  }
}
```

| 새 필드 | 타입 | 기본값 | 설명 |
|---------|------|--------|------|
| `shell_active` | bool | false | 셸 프로세스 활성 여부 |

### 4.2 shell_output 메시지 확장

**변경 전:**
```json
{
  "type": "shell_output",
  "payload": {
    "output": "total 42\ndrwxr-xr-x ...",
    "stream": "stdout"
  }
}
```

**변경 후:**
```json
{
  "type": "shell_output",
  "payload": {
    "output": "total 42\ndrwxr-xr-x ...",
    "stream": "stdout",
    "is_history": false
  }
}
```

| 새 필드 | 타입 | 기본값 | 설명 |
|---------|------|--------|------|
| `is_history` | bool | false | 버퍼에서 복원된 출력인지 여부 |

### 4.3 기존 프로토콜 유지 (변경 없음)

| 메시지 타입 | 변경 | 비고 |
|-------------|------|------|
| `shell_input` | 없음 | 그대로 사용 |
| `shell_exit` | 없음 | 셸 종료 시 앱에 알림 |
| `command` | 없음 | `:vcr` 명령어에서 사용 |
| `response` | 없음 | VCR 명령어 응답에 사용 |
| `ping`/`pong` | 없음 | keepalive 유지 |
| `frame` | 없음 | 프리뷰 기능에서 사용 (선택적) |
| `status` | 없음 | Agent 상태 알림 |
| `devices` | 없음 | 디바이스 목록 |

---

## 5. 컴포넌트별 변경 사항

### 5.1 Agent (vcr_agent)

#### ShellManager 변경

| 항목 | 현재 | 변경 |
|------|------|------|
| 시작 방식 | `shell` 명령어 수신 시 수동 start() | 클라이언트 연결 시 자동 start() |
| 출력 버퍼 | 없음 | 최대 50KB 링 버퍼 추가 |
| 세션 유지 | 클라이언트 끊기면 상태 불확실 | 클라이언트 끊겨도 셸 유지 |
| 버퍼 전송 | 없음 | 신규 클라이언트에 버퍼 unicast |

#### WebSocket Server 변경

| 항목 | 현재 | 변경 |
|------|------|------|
| 클라이언트 연결 시 | welcome만 전송 | welcome + 셸 자동 시작 + 버퍼 전송 |
| 메시지 전송 | broadcast만 | broadcast + unicast(특정 클라이언트) 추가 |

#### vcr_agent.dart 메인 로직 변경

```
연결 이벤트 핸들러:
1. welcome 메시지 전송 (shellActive 포함)
2. shellManager.isActive 확인
3. false → shellManager.start() → 셸 시작
4. true → shellManager.getBufferedOutput() → 버퍼 전송 (unicast)
```

### 5.2 App (Flutter)

#### TerminalScreen 변경

| 항목 | 현재 | 변경 |
|------|------|------|
| 메인 영역 | shellActive에 따라 xterm/리스트 분기 | 항상 xterm TerminalView |
| 상태바 | 프로젝트명, 디바이스수, 셸 토글 버튼 | 연결 상태 + 호스트명만 |
| 셸 토글 버튼 | 있음 (수동 전환) | 제거 (항상 셸 모드) |

#### TerminalInput 변경

| 항목 | 현재 | 변경 |
|------|------|------|
| 프롬프트 | `>` (명령 모드) / `$` (셸 모드) | `$` 고정 |
| 전송 방식 | shellActive에 따라 분기 | 항상 sendShellInput(input + '\n') |
| 특수 처리 | VCR 명령어 파싱 | `:vcr` 접두사 감지 → command로 전송 |

#### TerminalProvider 변경

| 항목 | 현재 | 변경 |
|------|------|------|
| 셸 활성화 | setShellActive(true) 수동 호출 | welcome 수신 시 자동 활성화 |
| Terminal 생성 | shellActive 변경 시 lazy 생성 | 연결 시 즉시 생성 |
| 버퍼 처리 | 없음 | isHistory=true 출력을 xterm에 기록 |

#### WebSocketService 변경

| 항목 | 현재 | 변경 |
|------|------|------|
| welcome 처리 | 연결 상태 + 프로젝트 정보 업데이트 | + shellActive 확인 → 셸 자동 활성화 |
| shell_output 처리 | writeToShell(data) | 동일 (isHistory 구분은 선택적) |

### 5.3 Shared 패키지

| 파일 | 변경 |
|------|------|
| `welcome_data.dart` | `shellActive` 필드 추가 |
| `shell_output_data.dart` | `isHistory` 필드 추가 |
| `protocol.dart` | 변경 없음 |
| `shell_input_data.dart` | 변경 없음 |
| `shell_exit_data.dart` | 변경 없음 |

---

## 6. 입력 처리 규칙

### 6.1 기본: 셸 패스스루

모든 입력은 기본적으로 셸로 직접 전달된다.

```
사용자 입력: "ls -la"
→ sendShellInput("ls -la\n")
→ Agent ShellManager.writeInput("ls -la\n")
→ 셸에서 ls -la 실행
→ 결과가 shell_output으로 스트리밍
```

### 6.2 VCR 명령어 접근: `:vcr` 접두사

```
사용자 입력: ":vcr create project my_app"
→ ":vcr " 접두사 감지
→ "create project my_app"을 command 타입으로 전송
→ Agent VCR 파서가 처리
→ response 메시지로 결과 수신
```

### 6.3 빈 입력 처리

```
사용자가 빈 입력으로 Enter:
→ sendShellInput("\n")
→ 셸에 빈 줄 입력 (프롬프트 재표시)
```

---

## 7. 예외 처리

| 상황 | Agent 동작 | App 동작 |
|------|-----------|---------|
| 셸 시작 실패 | welcome에 shellActive: false | 에러 메시지 표시, 재시도 버튼 |
| 셸 프로세스 종료 | shell_exit 전송, 자동 재시작 시도 | "셸이 종료되었습니다" 표시, 재시작 요청 |
| 연결 끊김 | 셸 프로세스 유지 | 재연결 시도, 성공 시 세션 복원 |
| 버퍼 오버플로우 | 오래된 출력 제거 (링 버퍼) | 최근 50KB만 표시 |
| `:vcr` 명령어 실패 | response(error) 전송 | 에러 메시지를 xterm에 표시 |

---

## 8. UI 변경 요약

### Terminal Screen (변경 후)

```
┌─────────────────────────┐
│ 🟢 Connected  192.168.0.5│  ← 상태바 (간소화)
├─────────────────────────┤
│                          │
│  user@macbook:~ $ ls     │  ← xterm TerminalView
│  Desktop  Documents  ... │     (메인 영역, 전체)
│  user@macbook:~ $ _      │
│                          │
│                          │
│                          │
│                          │
│                          │
├─────────────────────────┤
│ $ [입력창____________] ▶ │  ← 셸 입력 ($ 고정)
└─────────────────────────┘
```

### 제거되는 UI 요소
- 셸 토글 버튼 (항상 셸 모드)
- VCR 명령어 출력 리스트 (TerminalOutput 위젯)
- 디바이스 수 표시 (상태바)
- 프로젝트명 표시 (상태바) → 호스트 IP로 대체

### 유지되는 UI 요소
- Connection Screen (연결 관리)
- Preview Screen (에뮬레이터 프리뷰, 선택적)
- 명령어 히스토리 (방향키 네비게이션)

---

## 9. 작업 분해표 (WBS)

### Track A: Shared 패키지 (선행)

| Task ID | 작업명 | 담당 | 의존성 | 복잡도 |
|---------|--------|------|--------|--------|
| SH-001 | WelcomeData에 shellActive 필드 추가 | /be-dev | - | S |
| SH-002 | ShellOutputData에 isHistory 필드 추가 | /be-dev | - | S |

### Track B: Agent (백엔드)

| Task ID | 작업명 | 담당 | 의존성 | 복잡도 |
|---------|--------|------|--------|--------|
| BE-001 | ShellManager 출력 버퍼링 구현 | /be-dev | SH-002 | M |
| BE-002 | WebSocket Server unicast 메서드 추가 | /be-dev | - | S |
| BE-003 | 연결 시 자동 셸 시작 로직 | /be-dev | BE-001, BE-002, SH-001 | M |
| BE-004 | 신규 클라이언트에 버퍼 전송 로직 | /be-dev | BE-001, BE-002, BE-003 | M |

### Track C: App (프론트엔드)

| Task ID | 작업명 | 담당 | 의존성 | 복잡도 |
|---------|--------|------|--------|--------|
| FE-001 | TerminalProvider 자동 셸 활성화 | /fe-dev | SH-001 | S |
| FE-002 | WebSocketService welcome 셸 상태 처리 | /fe-dev | SH-001, FE-001 | S |
| FE-003 | TerminalScreen xterm 메인 뷰 전환 | /fe-dev | FE-001 | M |
| FE-004 | TerminalInput 셸 패스스루 전환 | /fe-dev | - | S |
| FE-005 | 상태바 간소화 + `:vcr` 명령어 지원 | /fe-dev | FE-003, FE-004 | S |

### Track D: 통합 & 테스트

| Task ID | 작업명 | 담당 | 의존성 | 복잡도 |
|---------|--------|------|--------|--------|
| TEST-001 | ShellManager 버퍼링 단위 테스트 | /tester | BE-001 | S |
| TEST-002 | 자동 셸 시작 통합 테스트 | /tester | BE-003, FE-002 | M |
| TEST-003 | 셸 입력→출력 E2E 검증 | /tester | 전체 | M |

### 병렬 처리 가능 식별

```
Phase 1 (선행): SH-001, SH-002 (Shared, 동시)
      ↓
Phase 2 (병렬):
  Track B: BE-001 → BE-002 → BE-003 → BE-004
  Track C: FE-001 → FE-002 → FE-003 → FE-004 → FE-005
  * SH-001/002 완료 후 양쪽 동시 진행 가능
      ↓
Phase 3 (순차): TEST-001 → TEST-002 → TEST-003
```

---

## 10. 디자이너 전달 사항

`/designer`에게 전달할 핵심 정보:

1. **메인 화면 = xterm 터미널 뷰** (화면의 80%+ 차지)
2. **상태바 간소화**: 연결 상태 아이콘 + 호스트 IP만
3. **입력창**: `$` 프롬프트 고정, 셸 명령어 전용
4. **다크 테마 유지** (터미널 감성)
5. **제거 대상**: 셸 토글 버튼, VCR 명령어 출력 리스트, 디바이스 수, 프로젝트명
6. **유지 대상**: Connection Screen, Preview Screen (선택적 접근)
7. **새로 필요**: 셸 종료/에러 시 안내 UI (재시작 버튼 등)
