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

1. **코드베이스 탐색** — 기존 패턴, 재사용 가능한 서비스/유틸리티 탐색
2. **명확화 질문** — 구현 방식, 범위, 도메인 컨텍스트 3~5개 질문
3. **계획 문서 작성** — `docs/plan/task-{feature}.md` 생성 (디렉토리 없으면 생성)
4. **피드백 요청** — 단계 구성, 누락 항목, 범위 검토

## 생성 문서 구조

```
task-{feature}.md
├── 0. Tidy First        ← 기존 코드 수정 시에만 포함
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
