# ADR-001: 프로젝트 구조 (모노레포)

## 상태
Accepted

## 컨텍스트
VCR은 두 개의 독립적인 Dart 프로젝트로 구성된다:
- **VCR App**: Flutter 모바일 앱 (스마트폰에서 실행)
- **VCR Agent**: Dart CLI 프로그램 (노트북에서 실행)

이 두 프로젝트를 어떤 구조로 관리할지 결정해야 한다.

## 대안 검토

### 옵션 A: 모노레포 (단일 저장소, 서브디렉토리 분리)
```
vcr/
├── lib/           # VCR App (Flutter)
├── vcr_agent/     # VCR Agent (Dart CLI)
└── shared/        # 공유 모델/프로토콜
```
- 장점:
  - 공유 코드(프로토콜, 모델)를 쉽게 참조
  - 하나의 git 히스토리로 변경 추적
  - 프로토콜 변경 시 양쪽 동시 수정 가능
  - CI/CD 파이프라인 단순
- 단점:
  - pubspec.yaml이 2개 (루트 + vcr_agent)
  - Agent는 Flutter SDK 의존 없이 순수 Dart로 실행해야 함

### 옵션 B: 멀티레포 (별도 저장소)
- 장점:
  - 완전한 독립 배포
  - 각 팀이 독립적으로 작업 가능
- 단점:
  - 프로토콜 변경 시 양쪽 저장소 동기화 필요
  - 공유 코드 관리 복잡 (별도 패키지로 퍼블리시해야 함)
  - 테스트용 프로젝트에 과도한 오버헤드

### 옵션 C: Dart workspace (melos 등)
- 장점:
  - 패키지 간 의존성 자동 관리
  - 모노레포의 장점 유지
- 단점:
  - melos 같은 추가 도구 필요
  - 셋업 복잡도 증가
  - MVP에 과도한 인프라

## 결정
**옵션 A: 모노레포 (단순 서브디렉토리)** 선택

## 선택 근거
1. 테스트용 프로젝트 → 단순한 구조가 최선
2. 프로토콜 공유: `shared/` 디렉토리로 모델/상수 공유 (path dependency)
3. 한 명 또는 소수가 개발 → 멀티레포의 이점 없음
4. vcr_agent는 `dart run`으로 실행 가능 (Flutter SDK 불필요)

## 최종 프로젝트 구조

```
vcr/
├── docs/                         # 문서
│   ├── PRD.md
│   ├── DEVELOPMENT_PLAN.md
│   ├── ADR-*.md
│   └── PROTOCOL.md
├── lib/                          # VCR App (Flutter 모바일)
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   ├── models/
│   ├── services/
│   ├── screens/
│   └── widgets/
├── vcr_agent/                    # VCR Agent (Dart CLI)
│   ├── bin/
│   │   └── vcr_agent.dart
│   ├── lib/
│   │   ├── server/
│   │   ├── parser/
│   │   ├── flutter/
│   │   └── emulator/
│   ├── pubspec.yaml
│   └── test/
├── shared/                       # 공유 코드
│   ├── lib/
│   │   ├── protocol.dart         # 메시지 타입 정의
│   │   ├── commands.dart         # 커맨드 타입 상수
│   │   └── models/               # 공유 모델
│   └── pubspec.yaml
├── pubspec.yaml                  # App pubspec
├── android/
├── ios/
└── test/
```

### 패키지 의존성 관계
```
vcr (App) ──depends──> shared
vcr_agent  ──depends──> shared
```

`shared`는 path dependency로 참조:
```yaml
# vcr/pubspec.yaml 및 vcr_agent/pubspec.yaml
dependencies:
  shared:
    path: ../shared   # (또는 ./shared)
```

## 결과
- 프로토콜 변경 시 `shared/`만 수정하면 양쪽 자동 반영
- Agent는 순수 Dart로 실행 (Flutter SDK 불필요)
- 추후 멀티레포 전환 시 shared를 pub.dev 패키지로 분리 가능
