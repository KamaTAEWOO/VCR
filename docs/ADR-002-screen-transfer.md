# ADR-002: 화면 전송 방식

## 상태
Accepted

## 컨텍스트
VCR Agent는 노트북의 Android Emulator 화면을 캡쳐하여 스마트폰의 VCR App에 실시간으로 전송해야 한다. WebSocket을 통해 에뮬레이터 화면 프레임을 어떤 형태로 전송할지 결정해야 한다.

타겟: 10~20fps, 사용 가능한 수준의 지연시간

## 대안 검토

### 옵션 A: JPEG + Base64 (JSON 내부)
```json
{
  "type": "frame",
  "payload": {
    "data": "<base64 encoded JPEG>",
    "width": 1080,
    "height": 1920
  }
}
```
- 장점:
  - JSON 프로토콜과 통일 (모든 메시지가 JSON)
  - 파싱 로직 단순
  - 디버깅 쉬움 (텍스트 기반)
- 단점:
  - Base64 인코딩으로 약 33% 크기 증가
  - 인코딩/디코딩 CPU 오버헤드
  - 대역폭 비효율

### 옵션 B: Binary WebSocket Frame
WebSocket binary frame으로 JPEG 바이트 직접 전송.
메타데이터는 별도 JSON 메시지 또는 바이너리 헤더로.
- 장점:
  - 크기 효율 (33% 절약)
  - 인코딩 오버헤드 없음
  - 네트워크 대역폭 효율
- 단점:
  - JSON과 binary 메시지를 분기 처리해야 함
  - `web_socket_channel`에서 binary와 text를 구분하는 추가 로직 필요
  - 디버깅 어려움

### 옵션 C: 별도 HTTP 스트림
화면 프레임은 별도 HTTP MJPEG 스트림으로 분리.
- 장점:
  - 명령 채널과 미디어 채널 완전 분리
  - 표준 MJPEG 뷰어 호환
- 단점:
  - 두 개의 연결 관리 필요
  - 연결 동기화 복잡도 증가
  - MVP에 과도한 아키텍처

## 기술 분석

### 크기 비교 (1080x1920 에뮬레이터 화면 기준)
| 항목 | JPEG Q50 | JPEG Q30 |
|------|---------|---------|
| Raw JPEG | ~80KB | ~50KB |
| Base64 | ~107KB (+33%) | ~67KB (+33%) |

### 대역폭 계산 (10fps 기준)
| 방식 | 초당 전송량 |
|------|-----------|
| Binary JPEG Q50 | ~800KB/s |
| Base64 JPEG Q50 | ~1,070KB/s |
| Binary JPEG Q30 | ~500KB/s |
| Base64 JPEG Q30 | ~670KB/s |

Wi-Fi 환경에서 670KB/s~1MB/s는 문제없는 수준.

## 결정
**옵션 A: JPEG + Base64 (JSON 내부)** 선택

## 선택 근거
1. **MVP 단순성**: 모든 메시지가 JSON이면 파서가 하나로 통일
2. **대역폭 충분**: Wi-Fi LAN 환경에서 Base64 오버헤드(+33%)는 무시 가능
3. **디버깅 용이**: 텍스트 기반이므로 메시지 로깅/디버깅이 쉬움
4. **JPEG 품질 조절**: Q30~Q50으로 충분한 화질 + 적절한 크기
5. **추후 최적화 경로 명확**: 나중에 옵션 B(Binary)로 전환 가능

### 구현 스펙
- 화면 캡쳐: `adb exec-out screencap -p` (PNG 출력)
- 변환: PNG → JPEG (quality 40)
- 인코딩: JPEG bytes → Base64 string
- 전송: JSON `{ "type": "frame", "payload": { "data": "..." } }`
- 캡쳐 간격: 100ms (10fps) 기본, 설정 가능
- 해상도: 에뮬레이터 기본 해상도 그대로 (리사이즈 없음, MVP)

## 결과
- 프로토콜 파서가 단순해짐 (JSON only)
- Wi-Fi LAN에서 충분한 성능
- 추후 성능 이슈 시 Binary frame으로 마이그레이션 가능
- JPEG 품질 파라미터로 품질/크기 트레이드오프 조절 가능
