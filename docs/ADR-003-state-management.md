# ADR-003: 상태 관리 방식

## 상태
Accepted

## 컨텍스트
VCR App(모바일)에서 관리해야 할 상태:
1. **연결 상태**: WebSocket 연결 여부, 서버 정보
2. **터미널 상태**: 커맨드 히스토리, 출력 로그
3. **프리뷰 상태**: 현재 프레임 이미지, FPS
4. **Agent 상태**: connected / hot_reloading / build_error / disconnected

Flutter 상태 관리 솔루션을 선정해야 한다.

## 대안 검토

### 옵션 A: Provider
| 기준 | 평가 |
|------|------|
| 러닝 커브 | 낮음 (Flutter 공식 추천) |
| 보일러플레이트 | 적음 |
| 테스트 용이성 | 보통 |
| 생태계 | 매우 넓음 |
| 적합 규모 | 소~중형 |

- 장점:
  - Flutter 팀 공식 추천
  - ChangeNotifier 기반으로 직관적
  - 문서/예제 풍부
  - 의존성 하나 (provider 패키지)
- 단점:
  - 복잡한 상태 로직에서 ChangeNotifier가 비대해질 수 있음
  - 상태 간 의존성 관리가 수동적

### 옵션 B: Riverpod
| 기준 | 평가 |
|------|------|
| 러닝 커브 | 중간 |
| 보일러플레이트 | 중간 (코드 생성 사용 시 적음) |
| 테스트 용이성 | 높음 |
| 생태계 | 넓음 |
| 적합 규모 | 중~대형 |

- 장점:
  - 컴파일 타임 안전성
  - Provider 간 의존성 자동 관리
  - 테스트가 매우 쉬움 (override 지원)
  - 코드 생성으로 보일러플레이트 감소
- 단점:
  - 러닝 커브 존재
  - riverpod_generator + build_runner 필요
  - MVP에 과도할 수 있음

### 옵션 C: BLoC
- 장점:
  - 엄격한 패턴 (이벤트 → 상태)
  - 대규모 프로젝트에 적합
- 단점:
  - 보일러플레이트 많음
  - MVP에 확실히 과도함
  - 클래스 수 폭증

## 기술 스택 평가

| 기준 | 가중치 | Provider | Riverpod | BLoC |
|------|--------|----------|----------|------|
| 러닝 커브 | 20% | 5 | 3 | 2 |
| 보일러플레이트 | 15% | 5 | 3 | 1 |
| 테스트 용이성 | 15% | 3 | 5 | 4 |
| 생태계/문서 | 15% | 5 | 4 | 4 |
| MVP 적합성 | 20% | 5 | 3 | 1 |
| 확장성 | 15% | 3 | 5 | 5 |
| **총점** | | **4.35** | **3.70** | **2.65** |

## 결정
**옵션 A: Provider** 선택

## 선택 근거
1. **MVP 우선**: 빠른 개발이 목표. Provider의 단순함이 최대 장점
2. **상태 규모 적절**: VCR App의 상태는 4종류로 단순. Provider로 충분
3. **추가 도구 불필요**: build_runner, 코드 생성 없이 바로 사용
4. **마이그레이션 경로**: Provider → Riverpod 전환은 비교적 쉬움

### 상태 구조 설계
```dart
// 3개의 ChangeNotifier로 관심사 분리

class ConnectionProvider extends ChangeNotifier {
  // WebSocket 연결 상태, 서버 정보, mDNS 탐색 결과
}

class TerminalProvider extends ChangeNotifier {
  // 커맨드 히스토리, 출력 로그, 현재 입력
}

class PreviewProvider extends ChangeNotifier {
  // 현재 프레임 이미지 바이트, FPS, Agent 상태
}
```

### 의존성
```yaml
dependencies:
  provider: ^6.1.0
```
추가 도구 없음. 무료 오픈소스.

## 결과
- Provider 하나로 상태 관리 통일
- ChangeNotifier 3개로 관심사 분리
- 코드 생성 도구 불필요 → 빌드 파이프라인 단순
- 추후 상태 복잡도 증가 시 Riverpod 마이그레이션 고려
