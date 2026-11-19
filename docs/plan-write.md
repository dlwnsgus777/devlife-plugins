# plan-write

작업 폴더의 `plan.md`를 작성하거나 갱신합니다.
`plan.md`는 "무엇을 하나"와 코드 작업이면 "어떻게 만드나"까지 담는 문서로, 작업하는 동안 진행상황을 계속 갱신합니다.

## 언제 사용하나요?

- plan-creator가 탐색·질문 결과로 `plan.md`를 쓸 때
- TDD 스킬이 Phase를 끝내고 상태를 갱신할 때
- 작업 중 하지 않기로 한 일을 Backlog에 남길 때

## 트리거 문구

```
"plan.md 작성해줘"
"plan.md 갱신해줘"
"Phase 완료 표시해줘"
"Backlog에 추가해줘"
```

## 실행 흐름

### 작성 모드

1. **템플릿 읽기** — `assets/plan-template.md`
2. **작성** — 7개 섹션을 모두 채움. 쓸 내용이 없는 섹션은 `없음`. 기존 `plan.md`가 있으면 상태값·체크·Backlog는 유지
3. **추측 금지** — 입력에 없는 내용은 Backlog에 질문으로 남김
4. **경계값** — 기준 금액·상한·범위가 있는 규칙은 테스트 항목에 경계 값과 바로 앞 값을 기대 결과와 함께 적음 (예: `199,999원 → 29,999원`, `200,000원 → 30,000원`)

### 갱신 모드

아래 네 가지만 바꿉니다. 그 밖에 Context·Scope·Phase 목표·테스트가 바뀌어야 하면 갱신이 아니라 계획 변경이므로 멈추고 알립니다.

| 바꾸는 것 | 방법 |
|---|---|
| Phase 상태 | 시작하면 `doing`, Verification 항목이 모두 통과하면 `done` |
| Verification 체크 | 통과한 항목 `[ ]` → `[x]` |
| Backlog 항목 | 다음 번호로 덧붙임 |
| 대체된 결정 반영 | `decision-write`가 새 Dec로 옛 결정을 대체하면, 옛 결정을 따르던 함정·Phase 상세·스니핏·테스트를 새 결정대로 고치고 `(Dec-M)` 표시. 리팩터로 바뀐 이름·표현은 맞추지 않음 |

## 문서 구조

```
plan.md
├── 헤더: 제목(티켓), 의도 한 문장
├── 1. Context — 배경 / 외부 제약 / 도메인 불변성(출처 태그) / 기존 패턴 / 기존 코드의 함정
├── 2. Scope — In / Out(→ Backlog)
├── 3. Plan — Phase 표(목표·완료 기준·상태) + 코드 작업이면 Phase마다 구현 대상 파일·API·비즈니스 로직·코드 스니핏
├── 4. Verification — Phase별 테스트([NEW]/[REGRESSION]) / 수동 확인(기능별 체크리스트 — 행동 → 보이는 결과)
├── 5. Prerequisites — 실행 전제 / 배포 전 작업
├── 6. Glossary
└── 7. Backlog
```

## 관련 스킬

- [plan-creator](./plan-creator.md) — 이 스킬을 불러 `plan.md`를 작성
- [decision-write](./decision-write.md) — 같은 폴더의 `decisions.md` 작성
- [tdd-subagent](./tdd-subagent.md), [tdd-agent-team](./tdd-agent-team.md) — Phase가 끝나면 이 스킬로 상태 갱신
