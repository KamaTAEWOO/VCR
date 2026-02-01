# VCR - MVP Development Plan

> 에이전트별 체크박스 기반 개발 플랜

---

## Phase 0: 프로젝트 초기화

### Agent: `/tech-lead` - 아키텍처 결정

- [x] 프로젝트 구조 확정 (모노레포: App + Agent + shared) → `ADR-001`
- [x] 의존성 패키지 선정 (전부 무료/오픈소스)
  - [x] App: `web_socket_channel`, `provider`, `nsd` (mDNS)
  - [x] Agent: `shelf_web_socket`, `args`, `nsd`, `process_run`, `image`
  - [x] Shared: `json_annotation` (공유 모델)
- [x] WebSocket 메시지 프로토콜 JSON 스키마 확정 → `PROTOCOL.md`
- [x] ADR 작성: 화면 전송 방식 → JPEG Base64 (JSON 통일) → `ADR-002`
- [x] ADR 작성: 상태 관리 → Provider 선택 → `ADR-003`

---

## Phase 1: 분석 & 설계

### Agent: `/planner` - 기능 명세서

- [x] VCR 커맨드 언어 상세 스펙 정의 → `FEATURE_SPEC.md` 섹션 2
  - [x] 각 커맨드의 파라미터, 정규식, 에러 케이스 (CMD-001 ~ CMD-009)
  - [x] 커맨드 -> Flutter 코드 변환 규칙 (삽입 알고리즘 포함)
- [x] WebSocket 메시지 타입 전체 목록 → `PROTOCOL.md` (이전 Phase에서 완료)
- [x] 에러 핸들링 시나리오 정리 → `FEATURE_SPEC.md` 섹션 3
- [x] UX 플로우 상세 (화면별 상태 전이) → `FEATURE_SPEC.md` 섹션 4
- [x] WBS 작성 (BE 9개 + FE 9개 + INT/TEST 6개) → `FEATURE_SPEC.md` 섹션 6

### Agent: `/designer` - UI/UX 설계

- [x] 화면 목록 및 네비게이션 플로우 → `UI_SPEC.md` 섹션 1
  - [x] Connection Screen (초기 연결) → 섹션 3.1
  - [x] Terminal Screen (메인 - 터미널 + 미리보기) → 섹션 3.2
  - [x] Preview Screen (전체화면 미리보기) → 섹션 3.3
- [x] 터미널 UI 상세 설계 → `UI_SPEC.md` 섹션 4
  - [x] 입력창 레이아웃 → TerminalInput (4.2)
  - [x] 출력 영역 (로그, 에러, 성공) → TerminalOutput (4.3)
  - [x] 커맨드 히스토리 표시 방식 → TerminalOutput 내 통합
- [x] 상태 표시 UI 설계 → `UI_SPEC.md` 섹션 5 (7가지 상태 + 애니메이션)
- [x] 컬러 팔레트 & 타이포그래피 (다크 테마) → 섹션 2.1, 2.2
- [x] 위젯 컴포넌트 트리 → 각 화면별 위젯 트리 포함
- [x] Flutter ThemeData 정의 → 섹션 6
- [x] fe-dev 전달 파일 목록 정리 → 섹션 7

---

## Phase 2: 핵심 인프라 개발 (병렬)

### Track A - Agent: `/be-dev` - VCR Agent (노트북) ✅

- [x] **shared 패키지** (BE-001)
  - [x] protocol.dart, commands.dart, 6개 모델 (vcr_message, vcr_command, vcr_response, frame_data, agent_state, welcome_data)
- [x] **vcr_agent 프로젝트 초기화** (BE-002)
  - [x] pubspec.yaml + bin/vcr_agent.dart + CLI 인자 파싱
- [x] **WebSocket 서버** (BE-003)
  - [x] shelf 기반, 다중 클라이언트, welcome/broadcast
- [x] **mDNS 서비스 등록** (BE-004)
  - [x] macOS: dns-sd, Linux: avahi 폴백 (nsd는 순수 Dart CLI 미지원)
- [x] **VCR 커맨드 파서** (BE-005)
  - [x] 9개 커맨드 정규식 패턴 + sealed class 기반 결과
- [x] **Flutter 프로젝트 컨트롤러** (BE-006)
  - [x] create/run/hot reload/restart/stop + 상태 감지 + 로그 스트리밍
- [x] **코드 생성기** (BE-007)
  - [x] 페이지 템플릿 + children 삽입 알고리즘 + const 제거 + 라우트 업데이트
- [x] **Emulator 화면 캡쳐** (BE-008)
  - [x] screencap → JPEG Q40 → Base64, 10fps, 3회 실패 시 자동 일시정지
- [x] **전체 파이프라인 통합** (BE-009)
  - [x] CLI → WebSocket → Parser → CodeGen/Flutter → 응답/프레임 브로드캐스트

### Track B - Agent: `/fe-dev` - VCR App (모바일) ✅

- [x] **프로젝트 구조 셋업** (FE-001)
  - [x] main.dart, app.dart, core/theme.dart, core/constants.dart
- [x] **모델 정의** (FE-002)
  - [x] agent_state, terminal_entry, vcr_message, vcr_response, frame_data
- [x] **Provider 셋업** (FE-003)
  - [x] ConnectionProvider, TerminalProvider, PreviewProvider
- [x] **WebSocket 서비스** (FE-004)
  - [x] 연결/해제/메시지 라우팅/keepalive/자동 재연결 (5회)
- [x] **mDNS 탐색 서비스** (FE-005)
  - [x] nsd 패키지, 10초 타임아웃, 수동 IP 폴백
- [x] **Connection Screen** (FE-006)
  - [x] 로고 + 서버 목록 + 수동 입력 + 연결 버튼
- [x] **Terminal Screen** (FE-007)
  - [x] StatusBar + TerminalOutput + TerminalInput + 미니 프리뷰 토글
- [x] **Terminal 위젯들**
  - [x] status_indicator (pulse/rotate 애니메이션)
  - [x] terminal_input (히스토리 네비게이션)
  - [x] terminal_output (자동 스크롤, 색상 코딩)
- [x] **Preview Screen** (FE-008)
  - [x] InteractiveViewer + PreviewViewer + FPS 카운터
- [x] **Preview 위젯**
  - [x] preview_viewer (gaplessPlayback, mini/full 모드)
  - [x] server_list_tile

---

## Phase 3: 통합

### Shared 패키지 연동 (통합 인프라)

- [x] App pubspec.yaml에 vcr_shared path dependency 추가
- [x] flutter pub get (App) 정상 완료
- [x] dart pub get (Agent) 정상 완료
- [x] flutter analyze (App) 에러 0
- [x] dart analyze (Agent) 에러 0
- [x] dart analyze (shared) 에러 0
- [x] App 내부 모델 ↔ shared 모델 정합성 확인 (호환 가능)

### Agent: `/fe-dev` - API 연동 ✅

- [x] WebSocket 서비스 <-> Terminal Screen 연결
  - [x] 커맨드 전송 시 JSON 래핑
  - [x] 응답 수신 시 터미널 출력에 표시
- [x] Screen Frame 수신 <-> Preview 연결
  - [x] 프레임 디코딩 파이프라인
  - [x] 메모리 관리 (이전 프레임 해제)
- [x] 상태 업데이트 <-> Status Indicator 연결
- [x] Discovery -> Connection -> Terminal 플로우 통합
- [x] 에러 시 사용자 피드백 (스낵바, 다이얼로그)

### Agent: `/tester` - 테스트

- [ ] **Unit Tests - Agent**
  - [ ] Command Parser 테스트
  - [ ] Code Generator 테스트
  - [ ] WebSocket 메시지 직렬화 테스트

- [ ] **Unit Tests - App**
  - [ ] VCR Command 모델 테스트
  - [ ] VCR Response 모델 테스트
  - [ ] WebSocket Service 테스트 (mock)

- [ ] **Integration Tests**
  - [ ] Agent <-> App WebSocket 연결 테스트
  - [ ] 커맨드 전송 -> 응답 수신 E2E
  - [ ] 화면 캡쳐 -> 프리뷰 표시 E2E

---

## Phase 4: 검증 ✅

### Agent: `/reviewer` - 코드 리뷰 ✅

- [x] 코드 품질 검토 → `REVIEW_REPORT.md`
  - [x] Dart lint 규칙 준수
  - [x] 네이밍 컨벤션 일관성
  - [x] 에러 핸들링 적절성
- [x] 보안 검토
  - [x] WebSocket 연결 검증
  - [x] 입력값 검증 (커맨드 인젝션 방지 → runInShell 제거, _escapeDartString 추가)
- [x] 성능 검토
  - [x] 화면 프레임 메모리 관리 (seq 기반 중복 스킵)
  - [x] WebSocket 메시지 크기

### Agent: `/tech-lead` - 아키텍처 검토 ✅

- [x] 모듈 간 의존성 방향 검토 → `ARCHITECTURE_REVIEW.md`
- [x] 확장성 평가 (2차 기능 추가 용이성)
- [x] 에러 복구 메커니즘 검토
- [x] 패키지 구조 적절성

---

## Phase 5: 마무리

### Agent: 해당 담당

- [x] 리뷰 지적사항 수정 (Critical 3건 + High 3건 수정 완료)
- [x] README.md 업데이트 (설치 & 사용법)
- [ ] 데모 시나리오 작성
- [ ] v0.1.0 태그

---

## Phase 6: 추가 기능 (Post-MVP)

### 연결 안정성 개선 ✅

- [x] 연결 타임아웃 (10초) 추가
- [x] WebSocket 채널 누수 수정
- [x] 이중 disconnect 방지 (_isDisconnecting 가드)
- [x] 사용자 친화적 에러 메시지 (_formatConnectionError)
- [x] WebSocket 경로 표준화 (/ws + / 호환)

### 멀티 디바이스 스크린 미러링 ✅

- [x] **shared**: DeviceInfo 모델, DeviceListData, MessageType.devices
- [x] **shared**: FrameData에 deviceId/deviceName/platform 필드 추가
- [x] **Agent**: DeviceController — Android(adb) + iOS(pymobiledevice3/idevicescreenshot) 동시 감지
- [x] **Agent**: ScreenCapture 디바이스별 인스턴스 (Android: adb screencap, iOS: pymobiledevice3/idevicescreenshot)
- [x] **Agent**: 10초 주기 디바이스 자동 재스캔
- [x] **App**: PreviewProvider 멀티 디바이스 프레임 관리
- [x] **App**: TerminalScreen 멀티 디바이스 미니 프리뷰 카드
- [x] **App**: PreviewScreen 스와이프 전환 + 디바이스 탭 바
- [x] **App**: PreviewViewer 디바이스 라벨 오버레이

### 설정 변경

- [x] 기본 포트 8765 → 9000
- [x] Connection Screen 기본 IP 192.168.219.104 고정

---

## 에이전트 실행 가이드

### 순차 실행 (Phase 0 -> 1)
```
/tech-lead   -> Phase 0 완료 후
/planner     -> Phase 1 기획 완료 후
/designer    -> Phase 1 설계 완료 후
```

### 병렬 실행 (Phase 2)
```
/be-dev  -> Track A (VCR Agent) 개발
/fe-dev  -> Track B (VCR App) 개발
** 동시에 실행 가능 **
```

### 순차 실행 (Phase 3)
```
/fe-dev  -> 통합 작업
/tester  -> 테스트 작성 & 실행
```

### 병렬 실행 (Phase 4)
```
/reviewer   -> 코드 리뷰
/tech-lead  -> 아키텍처 리뷰
** 동시에 실행 가능 **
```

---

## 의존성 맵

```
Phase 0 (tech-lead)
  │
  ├── Phase 1a (planner) ─── Phase 1b (designer)
  │                              │
  ├──────────────────────────────┤
  │                              │
  Phase 2a (be-dev)         Phase 2b (fe-dev)
  │                              │
  ├──────────────────────────────┤
  │
  Phase 3a (fe-dev: 통합)
  │
  Phase 3b (tester)
  │
  ├──────────────────────────────┤
  │                              │
  Phase 4a (reviewer)       Phase 4b (tech-lead)
  │                              │
  ├──────────────────────────────┤
  │
  Phase 5 (마무리)
```

---

## 예상 패키지 의존성

### VCR App (pubspec.yaml)
```yaml
dependencies:
  web_socket_channel: ^3.0.0
  provider: ^6.1.0
  nsd: ^2.2.0          # mDNS discovery
  json_annotation: ^4.9.0

dev_dependencies:
  json_serializable: ^6.8.0
  build_runner: ^2.4.0
  mockito: ^5.4.0
```

### VCR Agent (vcr_agent/pubspec.yaml)
```yaml
dependencies:
  shelf: ^1.4.0
  shelf_web_socket: ^2.0.0
  args: ^2.5.0
  nsd: ^2.2.0
  process_run: ^1.2.0
  image: ^4.2.0        # PNG -> JPEG 변환
  json_annotation: ^4.9.0

dev_dependencies:
  json_serializable: ^6.8.0
  build_runner: ^2.4.0
  test: ^1.25.0
```
