# tdd-agent-team

Claude Code **agent teams**로 Red-Green-Refactor TDD를 실행합니다.  
`tdd-red`가 실패 테스트를 쓰고, `tdd-green`이 최소 코드로 통과시키고, `tdd-refactor`가 그 태스크 범위 안에서 프로덕션·테스트 코드를 리팩터링합니다. 팀원은 리드의 지시 없이 공유 작업 목록에서 자기 일을 가져가고, 다음 단계로 직접 넘깁니다. 영향 범위가 겹치지 않는 태스크는 병렬로, 겹치는 태스크는 앞 태스크의 리팩터링이 끝난 뒤 진행됩니다.

## 언제 사용하나요?

- 태스크가 여러 개이고, 서로 다른 파일을 건드리는 태스크를 동시에 돌려 시간을 줄이고 싶을 때
- 사이클마다 확인받지 않고, 태스크 확정 후 끝까지 맡기고 싶을 때
- 마지막에 관점이 다른 리뷰어들이 서로 반박하는 교차 리뷰를 받고 싶을 때

`tdd-subagent`와의 차이:

| | `tdd-subagent` | `tdd-agent-team` |
|---|---|---|
| 실행 단위 | 단계마다 새 서브에이전트, 순차 | 계속 살아 있는 RED·GREEN·REFACTOR 팀원, 범위가 겹치지 않는 태스크는 병렬 |
| 넘겨주기 | 오케스트레이터가 모든 단계를 호출 | 팀원끼리 직접(RED → GREEN → `tdd-refactor` → 다음 태스크의 RED). 리드는 Setup·장애 처리·최종 검수만 |
| 진행 상태 | `session.md` | 공유 작업 목록(Task 도구) + `session.md` |
| 격리 | 단계마다 컨텍스트가 새로 시작 | 정의 파일의 지시 — RED는 구현 코드와 다른 팀원의 역할 파일을 읽지 않고, GREEN은 테스트를 쓰지 않음(강제 장치 없음) |
| 사이클 검증 | 사이클마다 리뷰어 | GREEN이 구현 전에 테스트가 실제로 실패하는지 확인(red check), 리드 검수는 마지막에 한 번 |
| 사용자 확인 | 1번 사이클 후, 이후 선택 | 태스크 확정 시 + (정비 항목이 있으면 정비 커밋 여부) + 최종 리뷰 반영 전 |
| 재개 | 지원 (`session.md`) | 미지원 — 팀원이 복원되지 않음 |
| 필요 조건 | 없음 | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, 대화형 세션, **`devlife` 플러그인 설치**(팀원 정의), Task 도구(필수) |

> 구현 후 테스트를 작성하거나, 기존 테스트를 실행하거나, 테스트 실패를 디버깅하는 용도로는 사용하지 않습니다. 팀을 언급하지 않은 "TDD로 개발해줘"는 `tdd-subagent`가 맡습니다.

## 트리거 문구

```
"TDD 팀으로 개발해줘"
"에이전트 팀으로 TDD"
"agent team으로 TDD"
"병렬 TDD"
"팀원끼리 TDD"
```

## 실행 흐름

### 준비 단계 (리드)

0. **실행 조건 확인**
   - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`가 `1`이 아니면 `~/.claude/settings.json` 수정을 제안하고, 동의할 때만 고칩니다. 거절하면 `tdd-subagent`를 안내하고 마칩니다
   - 플러그인 에이전트 `devlife:tdd-red`·`devlife:tdd-green`·`devlife:tdd-refactor`·`devlife:tdd-reviewer`가 있는지 확인합니다. 없으면 플러그인 설치·갱신을 안내하고 중단합니다(스킬만 복사해서는 팀원 정의가 없음)
   - **Task 도구**(`TaskCreate`·`TaskGet`·`TaskList`·`TaskUpdate`)는 필수입니다. 없으면 `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` 추가를 제안하고 다시 확인합니다. 그래도 없거나 거절하면 진행하지 않습니다
1. **이전 세션** — 완료된 세션(마지막 줄 `session: COMPLETE`)은 묻지 않고 `archive-{시각}/`으로 보관합니다. 중간에 끊긴 세션이면 이어갈 수 없음을 알리고, 보관 후 새로 시작할지 묻습니다
2. **`roles.env` 작성** — 컴파일 명령과 **메서드 단위** 테스트 명령. 병렬로 도는 태스크와 회귀 묶음이 섞이지 않도록 모든 테스트 실행은 메서드 단위입니다. 두 명령을 `.claude/settings.local.json` 허용 목록에 넣을지 한 번 묻습니다
3. **탐색 1회 + 도출** — 요구사항 문서에 있으면 문서를, 없으면 탐색 결과로 정합니다
   - In-scope 파일·Out of scope·기존 코드의 함정
   - 회귀 테스트 묶음 — 문서가 지목한 테스트 + 수정할 파일을 다루는 기존 테스트(항상 포함)
   - 불변성 ID — 문서에 없으면 `INV-001`부터 부여
   - **정비 항목** — 동작은 그대로 두고 구조만 먼저 바꾸라는 항목(Tidy First·코드 정비·추상화 추출 등). 문서에 없으면 `references/tidy-first-scan.md` 기준으로 **후보**를 찾아 보여 주고 승인분만 정비
   - **태스크와 영향 범위** — 태스크마다 바꿀 프로덕션 파일(`scope_production`)과 테스트 클래스. 파일이나 테스트 클래스가 하나라도 같으면 "겹친다". 커버리지 하한(불변성마다 어기는/지키는 경계 + 클래스당 해피패스), 하나의 구현 변경으로 통과하는 시나리오는 한 태스크로 병합
4. **태스크 확정** ← 사용자 확인 1. 태스크가 1~2개면 팀 유지 비용(팀원마다 가이드·문맥 재독, idle 알림마다 리드 턴)이 이득보다 커서 `tdd-subagent` 전환을 제안합니다
5. **공유 문맥과 역할 파일 작성**
   - `context.md` — 모두가 읽는 사실: 환경, 프로젝트 컨텍스트, 「RED가 호출할 수 있는 시그니처」(구현 코드를 못 읽는 RED의 유일한 창구), 불변성, 작업 규칙
   - `roles/tdd-red.md`·`roles/tdd-green.md`·`roles/tdd-refactor.md` — 그 역할에만 필요한 것(가이드 경로, In-scope 파일, 함정, 회귀 묶음). RED가 GREEN이 무엇을 기준으로 구현하는지 알지 못하도록 나눕니다
   - `session.md`, `tasks/NN/task.md`
6. **작업 준비** — 정비 항목이 있으면 항목마다 안전망 테스트를 먼저 돌려 통과를 확인하고 `tidy/NN/tidy.md`를 씁니다. 정비 항목이 없으면 이때 스텁을 만듭니다(있으면 정비가 끝난 뒤). 그리고 세션의 **모든 Task를 한 번에** 만들고 `blockedBy`로 순서를 겁니다
7. **팀원 생성** — 세 팀원을 `devlife:tdd-*`로 띄우고 스폰 프롬프트는 `Start.` 한 줄입니다. 팀원은 `READY`를 보낸 뒤 `context.md`와 자기 역할 파일을 읽고, `TaskList`에서 자기 담당이면서 풀린 Task를 번호 순으로 가져갑니다. 리드는 첫 작업을 보내지 않습니다

### 공유 작업 목록

| Task | 담당 | `blockedBy` |
|---|---|---|
| `Tidy NN` | `tdd-refactor` | 앞 `Tidy` |
| `Tidy gate` (정비 항목이 있을 때만) | 리드 | 모든 `Tidy` |
| `Task NN` | `tdd-red` → `tdd-green` | `Tidy gate`(있으면) + 범위가 겹치는 앞 태스크들의 `Refactor` |
| `Refactor NN` | `tdd-refactor` | `Task NN` |

- Task의 description은 `READ <경로>` 한 줄이고, 내용은 md 파일에만 둡니다
- **owner 변경은 알림이 아닙니다** — 넘길 때마다 받는 쪽에 `READ` 메시지를 함께 보냅니다
- 진행 판단의 근거는 결과 파일입니다. Task 상태는 늦게 반영될 수 있어 표시용입니다

### Tidy First (정비 항목이 있을 때만)

`tdd-refactor`가 `Tidy` Task를 순서대로 처리합니다 — 계획에 적힌 정비만(동작 변경 금지), 테스트가 이동·이름 변경을 따라가야 하면 직접 고침(assertion 불변), 안전망 재통과. 마지막 항목 뒤 `tidy-finished.md`를 리드에게 보내면, 리드가 안전망·범위·테스트 변경을 검수하고 ← **사용자 확인**: `refactor` 커밋을 따로 할지(리드가 커밋 / 직접 / 커밋 없이). 이어서 스텁을 만들고 `Tidy gate`를 완료해 사이클을 엽니다.

### 사이클 (태스크마다)

```
tdd-red ── 실패 테스트 → red-result.md, owner를 tdd-green으로
   └─READ red-result.md─▶ tdd-green ── red check(컴파일 + 실제 실패) → 최소 구현 → green-result.md, completed
                             │  (red check 거절 시 ─READ gate.md─▶ tdd-red)
                             └─READ green-result.md─▶ tdd-refactor ── 범위 안 리팩터링 → refactor-result.md, completed
                                                        └─READ task.md─▶ tdd-red (이 Refactor로 풀린 다음 태스크)
```

- **메시지 본문은 `READ <경로>` 한 줄뿐**입니다(예외: 첫 보고 `READY`)
- **GREEN은 최소 코드만** 쓰고 리팩터링하지 않습니다
- **`tdd-refactor`는 그 태스크의 범위 안에서만** 프로덕션·테스트를 리팩터링합니다. 클래스마다 책임을 한 문장으로 적고(둘 이상이면 Extract Class), 테스트는 단언·입력·테스트 수를 바꾸지 않습니다. 범위 밖에서 보인 리팩터링 거리는 고치지 않고 `deferred`에 남겨 최종 리뷰로 넘깁니다
- **스텁 요청은 팀원끼리** — RED가 `missing-stub.md`를 GREEN에게 보내고, GREEN이 "미구현" 예외 스텁과 시그니처를 추가한 뒤 회신합니다
- 모든 `Refactor`가 끝나면 `tdd-refactor`가 리드에게 `cycle-finished.md`를 보냅니다

### 사이클 중 리드

리드가 팀원에게 보내는 메시지는 세 가지뿐입니다: `blocked.md` 회신, `Tidy gate` 해제, 전원 idle일 때 보내는 쪽에 재전송 지시.

- **`blocked.md`** — 빠진 사실이면 `context.md`나 역할 파일을 보충하고 회신. 범위 밖 파일이 필요하면 범위·`blockedBy`를 갱신하거나 사용자에게. red check가 두 번 거절됐거나 설계 문제면 **막힌 태스크** 처리 후 사용자에게 묻습니다
- **막힌 태스크는 세션을 멈추지 않습니다** — 그 `Task`를 `completed`(`blocked`), `Refactor`를 `completed`(`skipped`)로 바꿔 뒤 작업을 풀고, 사용자 판단 뒤 새 Task 쌍으로 다시 진행합니다
- idle 알림에는 보통 반응하지 않습니다

### 마무리

1. **최종 검수** (리드, `cycle-finished.md` 수신 후 한 번) — 태스크마다 `green-result.md`·`refactor-result.md`만 읽고 확인합니다
   - `red-check.log` 기록(없으면 반려하지 않고 `red-first unverified`로 남겨 `review-test`가 지적)
   - 수정 파일이 그 태스크 범위 안인지
   - 리팩터링 기록(기법, 클래스당 책임 한 줄)
   - 테스트 변경이 단언·테스트 수를 바꾸지 않았는지
   - 세션 전체 메서드 + 회귀 묶음 일괄 실행(`final-test.log`)
   
   실패는 `fixes.md`로 담당자별로(동작 GREEN, 구조 `tdd-refactor`, 테스트 RED) 최대 2라운드, 넘으면 사용자에게 묻습니다. 모든 `deferred`는 `deferred.md`로 모읍니다
2. **병렬 최종 리뷰** ← 사용자 확인 2 — `review-domain`(불변성 매트릭스·범위), `review-test`(테스트 품질·`red-check.log` 유무), `review-design`(태스크 간 중복·책임, `deferred.md` 항목 판정) 3명이 각자 리포트를 씁니다. Critical/Important 지적이 있는 리뷰어만 나머지 두 명에게 반박을 1회 받습니다. 리드가 종합해 사용자에게 묻고, 승인한 것만 반영합니다 — 테스트는 RED, 설계·가독성은 `tdd-refactor`, 동작 누락·오류는 GREEN
3. **종료** — 팀원 종료 요청, 요약 출력, `session.md` 끝에 `session: COMPLETE` 기록, `_workspace/tdd-agent-team/`는 git 제외 상태로 남깁니다

## 팀원 정의 (플러그인 `agents/`)

| 팀원 이름 | `subagent_type` | 정의 파일 | `tools` |
|---|---|---|---|
| `tdd-red` | `devlife:tdd-red` | `agents/tdd-red.md` | Read, Write, Edit, Bash, SendMessage |
| `tdd-green` | `devlife:tdd-green` | `agents/tdd-green.md` | Read, Write, Edit, Bash, SendMessage |
| `tdd-refactor` | `devlife:tdd-refactor` | `agents/tdd-refactor.md` | Read, Write, Edit, Bash, SendMessage |
| `review-domain` / `review-test` / `review-design` | `devlife:tdd-reviewer` | `agents/tdd-reviewer.md` (관점은 스폰 프롬프트로 지정) | Read, Write, Bash, SendMessage — `Edit` 없음 |

- 정의는 `devlife` 플러그인 에이전트로만 실립니다. 스킬은 `~/.claude/agents/`에 아무것도 설치하지 않습니다
- 역할 지시는 정의 본문에 있어 팀원의 시스템 프롬프트로 들어가고, 세션 정보는 `context.md`와 `roles/{이름}.md`에 있어 스폰 프롬프트는 `Start.` 한 줄입니다
- 팀원 정의에 `Skill` 도구는 없습니다. 규칙 문서는 역할 파일에 적힌 경로를 `Read`로 읽습니다

### 규칙 문서

| 문서 | 쓰는 쪽 | 판정하는 쪽 |
|---|---|---|
| [`test-writing`](./test-writing.md) 스킬 | RED, `tdd-refactor`(테스트 정리) | `review-test` |
| `references/implementation.md` — 최소 구현, 계층, 안티패턴 | GREEN (`tdd-refactor`에게는 하한선) | `review-design` |
| `references/refactoring.md` — Tidy First, 클래스당 책임 하나, 냄새 → 기법, 테스트 리팩터링 규칙, 범위 밖은 `deferred` | `tdd-refactor` | `review-design` |

### 무엇이 강제되고 무엇이 아닌가

- **강제됨:** 정의의 `tools` 목록. 리뷰어는 `Edit`이 없어 코드를 고칠 수 없습니다
- **강제되지 않음:** `tools`는 경로를 나누지 못하고, 팀원 모두 테스트 실행에 Bash가 필요합니다. RED가 구현 코드를 읽지 않는 것, GREEN이 테스트를 고치거나 리팩터링하지 않는 것, `tdd-refactor`가 범위와 테스트 검증 내용을 지키는 것, GREEN의 red check는 모두 정의 파일의 지시에 기댑니다
- **사후 확인:** 리드의 최종 검수와 `review-test` 관점이 위반을 잡는 독립 검사입니다

## 주의사항

- **역할 경계는 지시문 수준입니다** — 위 "무엇이 강제되고 무엇이 아닌가" 참고
- **사이클 중 태스크별 반려가 없습니다** — 잘못된 태스크가 리팩터링까지 거친 뒤 최종 검수에서 발견될 수 있습니다
- **red check는 "하나 이상 실패"를 봅니다** — 모든 메서드가 실패해야 한다는 규칙은 RED 지시문이 맡습니다
- 실험 기능인 agent teams의 제약(대화형 세션 전용, 팀원 재개 불가)을 그대로 따릅니다

## 관련 스킬

- [tdd-subagent](./tdd-subagent.md) — 같은 TDD 원칙을 서브에이전트 순차 실행으로
- [test-writing](./test-writing.md) — RED·`tdd-refactor`·`review-test`가 읽는 테스트 작성 규칙
- [plan-creator](./plan-creator.md) — 입력으로 쓸 계획 문서 생성, 완료 후 이 스킬로 넘길 수 있음
- [test-driven-development](./test-driven-development.md) — 직접 TDD 구현 시 원칙 가이드
