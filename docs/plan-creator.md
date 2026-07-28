# plan-creator

단일 태스크의 구현 계획 문서를 작성합니다.  
API 설계, 비즈니스 로직, 구현 파일 목록, TDD 테스트 순서까지 포함한 상세 계획을 생성합니다.

## 언제 사용하나요?

- 새 기능이나 버그 픽스 구현을 시작하기 전
- API 설계, 비즈니스 로직 흐름을 미리 정리하고 싶을 때
- TDD로 개발할 테스트 케이스 목록이 필요할 때
- `prd-creator`로 만든 하위 태스크를 구체화할 때

## 트리거 문구

```
"계획 작성해줘"
"계획을 md 파일에 작성해줘"
"구현 계획"
"실행 계획"
"계획 MD로 정리"
```

## 실행 흐름

1. **코드베이스 탐색** — 기존 패턴, 재사용 가능한 서비스/유틸리티 탐색 + **변화 지점 스캔**
2. **명확화 질문** — 구현 방식, 범위, 도메인 컨텍스트 3~5개 질문 (변화 축이 실제로 늘어나는지 포함)
3. **계획 문서 작성** — `docs/plan/task-{feature}.md` 생성 (디렉토리 없으면 생성)
4. **피드백 요청** — 단계 구성, 누락 항목, 범위 + 추상화 제안 도입 여부 검토

### 변화 지점 추상화 제안

기존 코드를 수정하는 태스크에서는, 요구사항이 건드리는 축이 **앞으로도 계속 늘어나는 축**인지 확인해 추상화를 제안합니다.
탐색 대상은 enum·타입·채널 기준 `if`/`switch` 분기, 하드코딩된 정책값, 한 단계만 다른 중복 메서드 등입니다.

억지 추상화를 막는 기준(**two-case rule**):

| 조건 | 처리 |
|------|------|
| 구체 케이스가 이미 2개 이상 | 추상화 제안 |
| 이번 요구사항이 두 번째 케이스를 추가 | 추상화 제안 |
| 케이스가 1개 | 제안하지 않음 (구현체 1개뿐인 인터페이스는 안티패턴) |
| 도메인 근거 없이 구조 냄새만 있음 | 제안하지 않음 |
| 해당 변화 지점 없음 | `0-2. 추상화 제안`에 `해당 없음` |

제안된 추상화는 설계 결정이므로 **승인 전까지 적용 여부를 확정하지 않으며**, 반려되면 문서에서 삭제합니다.
승인된 경우 기존 케이스로 먼저 추출(`refactor` 커밋)한 뒤, 새 케이스를 기능 커밋(`feat`)에서 구현합니다.

## 생성 문서 구조

```
task-{feature}.md
├── 0. 코드 구조 정비     ← 기존 코드 수정 시에만 포함
│   ├── 0-1. Tidy First      ← 동작 변경 없는 정비
│   └── 0-2. 추상화 제안      ← 변화 지점 (없으면 "해당 없음")
├── 1. Feature Overview
├── 2. Domain Context & Invariants
├── 3. API Design        ← 엔드포인트별 Request/Response 예시
├── 4. Business Logic
├── 5. Implementation Files + 코드 스니핏
├── 6. Considerations & Questions
├── 7. Implementation Order (TDD 순서)
└── 8. Acceptance Criteria
```

## 파일명 규칙

| 상황 | 파일명 |
|------|--------|
| 사용자가 파일명 지정 | 지정한 이름 그대로 사용 |
| 지정 없음 | `task-{feature}.md` (예: `task-payment-refund.md`) |

## 워크플로우 위치

```
devlife-brainstorming
└── spec-creator
    └── plan-creator  ← 현재 위치
        └── tdd-team / test-driven-development
```

## 관련 스킬

- [spec-creator](./spec-creator.md) — plan-creator 실행 전 Spec 문서 작성
- [tdd-team](./tdd-team.md) — 계획 문서를 입력으로 TDD 사이클 실행
- [prd-creator](./prd-creator.md) — spec-creator 대안 (product-focused)
