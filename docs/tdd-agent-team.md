# tdd-agent-team

Claude Code **agent teams**로 Red-Green-Refactor TDD를 실행합니다.  
`tdd-red` 팀원은 실패 테스트를 태스크 순서대로 계속 작성하고, `tdd-green` 팀원은 넘겨받은 순서대로 통과시킵니다. 두 팀원이 직접 일을 주고받아, 태스크 N+1의 RED와 태스크 N의 GREEN이 동시에 진행됩니다. 각 팀원의 역할과 쓸 수 있는 도구는 에이전트 정의 파일이 정합니다.

## 언제 사용하나요?

- 태스크가 여러 개이고 RED와 GREEN을 겹쳐 돌려 시간을 줄이고 싶을 때
- 사이클마다 확인받지 않고, 태스크 확정 후 끝까지 맡기고 싶을 때
- 마지막에 관점이 다른 리뷰어들이 서로 반박하는 교차 리뷰를 받고 싶을 때

`tdd-subagent`와의 차이:

| | `tdd-subagent` | `tdd-agent-team` |
|---|---|---|
| 실행 단위 | 단계마다 새 서브에이전트, 순차 | 계속 살아 있는 RED·GREEN 팀원, 병렬 |
| 넘겨주기 | 오케스트레이터가 모든 단계를 호출 | 팀원끼리 직접 전달(RED ↔ GREEN, `tdd-refactor` ↔ RED), 리드는 결과 통합·검수·에러 처리만 |
| 진행 상태 | `session.md` | 공유 작업 목록(Task 도구, 있을 때) + `session.md` |
| 격리 | 단계마다 컨텍스트가 새로 시작 | 정의 파일의 지시 — RED는 구현 코드를 읽지·쓰지 않고, GREEN은 테스트를 쓰지 않음(강제 장치 없음) |
| 사이클 검증 | 사이클마다 리뷰어 | GREEN이 구현 전에 테스트가 실제로 실패하는지 확인(red check) |
| 사용자 확인 | 1번 사이클 후, 이후 선택 | 태스크 확정 시 + 최종 리뷰 반영 전 |
| 재개 | 지원 (`session.md`) | 미지원 — 팀원이 복원되지 않음 |
| 필요 조건 | 없음 | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, 대화형 세션, 팀원 정의 파일을 `~/.claude/agents/`에 설치. 선택: Task 도구(`CLAUDE_CODE_ENABLE_TODO_TOOLS=1` — 없으면 메시지 방식) |

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

### 준비 단계

0. **agent teams 확인** — `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`가 `1`이 아니면 `~/.claude/settings.json` 수정을 제안하고, 동의할 때만 고칩니다. 거절하면 `tdd-subagent`를 안내하고 마칩니다. 이어서 **Task 도구**(`TaskCreate`·`TaskGet`·`TaskList`·`TaskUpdate`)가 있는지 확인합니다. 일부 모델에서만 기본 제공이라, 없으면 `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` 추가를 제안하고 추가 후 다시 확인합니다(설정 `env`는 보통 실행 중 세션에 바로 적용 — 그래도 없을 때만 재시작 안내). 거절하면 **메시지 방식**으로 진행합니다. 결정한 방식은 `context.md`의 `Coordination: task-list | messages`에 기록됩니다
1. **이전 세션** — `_workspace/tdd-agent-team/session.md`가 있을 때, 끝까지 완료된 세션(마지막 줄 `session: COMPLETE`)이면 묻지 않고 `archive-{시각}/`으로 보관한 뒤 한 줄로 알립니다. 중간에 끊긴 세션이면 팀원이 복원되지 않아 이어갈 수 없음을 알리고, 보관 후 새로 시작할지 묻습니다
2. **`roles.env` 작성** — 컴파일 명령과 **메서드 단위** 테스트 명령. 팀원이 이 파일에서 명령을 읽습니다. RED가 같은 클래스에 다음 태스크의 실패 테스트를 추가하는 동안 GREEN이 돌기 때문에, 클래스 단위로 돌리면 남의 실패가 섞입니다
3. **탐색 1회 + 정비 항목·범위·회귀 테스트·불변성·태스크 도출** — 문서에 있으면 문서를, 없으면 탐색 결과로 직접 정하고 태스크 확정 때 함께 확인받습니다. In-scope 파일·Out of scope·기존 코드의 함정, 회귀 테스트 묶음(문서가 지목한 테스트 + **수정할 파일을 다루는 기존 테스트는 문서와 무관하게 항상 포함**), 불변성 ID(문서에 없으면 리드가 `INV-001`부터 부여). 요구사항 문서에서 **동작은 그대로 두고 구조만 먼저 바꾸라는 항목**(Tidy First·코드 정비·추상화 추출 등, 이름이나 위치와 무관하게 내용으로 판단)은 태스크가 아니라 **정비 항목**으로 따로 잡습니다(실패하는 테스트를 만들 수 없으므로). 항목마다 막는 지점·정비 내용·정비 후 요구사항이 들어갈 자리를 확인하고, 문서에 없으면 태스크 확정 때 묻습니다. **문서에 정비 항목이 없으면** 리드가 `references/tidy-first-scan.md` 기준(요구사항이 한 곳에 들어가지 못하게 막는 지점만, 추상화는 3조건 충족 시만)으로 직접 찾아 **후보**로 보여 주고, 사용자가 승인한 것만 정비합니다 요구사항 문서 우선, 커버리지 하한(불변성마다 어기는/지키는 경계 + 클래스당 해피패스), 하나의 구현 변경으로 통과하는 시나리오는 한 태스크로 병합, 의존하는 태스크는 뒤로
4. **태스크 확정** ← 사용자 확인 1. 태스크가 1~2개면 병렬 이득보다 팀 비용(팀원마다 가이드·문맥 재독, idle 알림마다 리드 턴)이 커서, 확정 질문 대신 `tdd-subagent`로 전환할지 묻습니다. 전환하면 확정한 태스크 목록을 그대로 넘기고 팀원은 띄우지 않습니다
5. **`context.md`·`session.md`·`tasks/NN/task.md` 작성** — `context.md`의 「RED가 호출할 수 있는 시그니처」는 구현 코드를 못 읽는 RED의 유일한 창구입니다
6. **팀원 생성** — RED는 리드가 시작 신호를 줄 때까지 대기합니다. 리드는 팀원의 첫 보고(`READY`)를 받은 뒤에만 첫 작업(`READ tasks/`, `tidy.md`, `refactor.md`)을 보냅니다 — 막 뜬 팀원은 메시지를 놓칠 수 있고, 재전송하면 끝난 일을 두 번 보고합니다. 반응이 없어 보여도 재전송 전에 Task의 owner·상태(메시지 방식이면 결과 파일)를 먼저 확인합니다
7. **Tidy First (정비 항목이 있을 때만)** — `tdd-refactor`를 띄우고, 항목마다: 리드가 기존 테스트(안전망)를 먼저 돌려 통과를 확인 → `tdd-refactor`가 계획에 적힌 정비만 수행(동작 변경 금지) → 테스트가 이동·이름 변경을 따라가야 하면 `tdd-refactor`가 기계적 수정 목록을 써서 **RED에게 직접** 보내고 RED가 그대로 반영(assertion 불변) 후 `tdd-refactor`에게 회신 → `tdd-refactor`가 리드에게 한 번 보고 → 리드가 안전망 재통과·범위를 검수. 모두 끝나면 ← **사용자 확인**: `refactor` 커밋을 따로 할지(리드가 커밋 / 직접 / 커밋 없이)
8. **스텁 일괄 생성 후 시작** — 정비된 구조 위에 리드가 계획 문서 시그니처로 스텁을 만들고(`UnsupportedOperationException`), Task 방식이면 `task.md`마다 Task를 하나씩 만든 뒤(정비가 끝난 다음이라 RED가 움직이는 구조 위에서 시작하지 않음), RED에게 `READ tasks/`로 사이클 시작을 알립니다

### 공유 작업 목록 (Task 방식)

- **작업 md 하나 = Task 하나** — `tidy/NN/tidy.md`, `tasks/NN/task.md`, `refactor.md`, `test-refactor.md`. Task의 description은 `READ <경로>` 한 줄이고 내용은 md 파일에만 둡니다. 리뷰어와 `fixes.md`는 Task가 없습니다
- **사이클 Task 하나를 RED와 GREEN이 같이 씁니다** — RED가 착수 시 `in_progress`, 넘길 때 owner를 `tdd-green`으로, GREEN이 red check 거절 시 owner를 `tdd-red`로 되돌리고, 통과시키면 `completed`
- **owner 변경은 알림이 아닙니다** — 넘길 때마다 받는 쪽에 `READ` 메시지를 함께 보냅니다
- **리드는 사후 검수** — GREEN이 `completed`로 바꾼 뒤 태스크 검수를 하고, 실패하면 Task를 `in_progress`·owner `tdd-green`으로 다시 엽니다. `session.md`의 `DONE`은 검수 통과로만 매기고, Task 상태는 근거로 쓰지 않습니다(상태 반영이 늦을 수 있음)
- 리팩터링 Task는 모든 사이클 Task, 테스트 정리 Task는 리팩터링 Task에 묶여(`blockedBy`) 순서가 보장됩니다

### 사이클

```
리드 ──READ tasks/──▶ tdd-red
                       │ 태스크 01 실패 테스트 → red-result.md
                       ├─READ tasks/01/red-result.md─▶ tdd-green
                       │ 태스크 02 실패 테스트 …             │ red check(컴파일 + 실패) → 최소 구현 → 구현 코드 정리 → green-result.md
                       ├─READ tasks/02/red-result.md─▶      │   (red check 실패 시 ─READ tasks/NN/gate.md─▶ tdd-red)
                       ⋮                                    └─READ tasks/01/green-result.md─▶ 리드
```

- **메시지 본문은 `READ <경로>` 한 줄뿐**입니다. 내용은 `_workspace/tdd-agent-team/` 아래 md 파일에 씁니다
- 리드는 넘겨주기 경로에 끼지 않습니다. 대신 GREEN의 `green-result.md` 보고마다 **태스크 검수** 3가지를 합니다. 필요한 정보(수정 파일·메서드 id·`red-check.log` 경로)는 모두 `green-result.md`에 있어서 이 파일만 읽습니다 — `red-check.log`가 있는지(없으면 기록만 하고 최종 리뷰가 지적), 수정 파일이 In-scope 안인지(벗어나면 GREEN에 되돌림), 해당 메서드가 실제로 통과하는지(직접 실행, 실패하면 되돌림). 같은 태스크가 두 번 되돌려지면 BLOCKED로 두고 사용자에게 묻습니다. `blocked.md`도 리드가 처리합니다
- **스텁 요청은 팀원끼리** — RED가 `context.md`에 없는 시그니처가 필요하면 `missing-stub.md`를 **GREEN에게** 보내고, GREEN이 "미구현" 예외 스텁을 만들어 `context.md`에 시그니처를 추가한 뒤 RED에게 회신합니다. 리드는 Setup 이후 소스 파일을 고치지 않습니다
- GREEN의 red check가 같은 태스크를 두 번 거절하면 RED가 `blocked.md`를 써서 리드에게 보냅니다

### 마무리

1. **구현 코드 리팩터링** — `tdd-refactor`가 세션에서 바뀐 구현 파일 전체를 한 번에 정리합니다. GREEN은 태스크마다 최소 코드만 썼으므로 **여러 태스크를 거치며 한 클래스에 쌓인 책임**이 첫 대상이고(클래스마다 책임을 한 문장으로 쓰고, 필드·의존성 묶음과 변경 이유를 세어 둘 이상이면 Extract Class), 그다음 태스크 사이의 중복·하드코딩입니다. 결과 파일에 클래스마다 `responsibilities:` 한 줄을 남깁니다. 리드가 안전망(세션 전체 메서드 + `[REGRESSION]`) 통과, 범위, 그리고 책임이 둘 이상인 클래스에 Extract Class 또는 미룬 이유가 있는지(형식만)를 검수
2. **테스트 코드 정리** — 그다음 RED가 최종 구조에 맞춰 테스트 파일을 한 번에 정리합니다(사이클 중에는 두 팀원이 같은 파일을 건드리지 않도록 정리를 모두 사이클 뒤로 미룸)
3. **최종 테스트** — 세션의 모든 메서드 + `[REGRESSION]` 클래스를 리드가 한 번에 실행. 팀원이 스스로 하지 않는 유일한 테스트 실행이라, GREEN이 통과 없이 완료를 보고한 경우를 여기서 잡습니다. 실패 시 GREEN에 수정 요청(최대 2라운드)
4. **병렬 최종 리뷰** ← 사용자 확인 2 — `review-domain`(불변성 매트릭스·범위), `review-test`(테스트 품질·`red-check.log` 유무), `review-design`(태스크 간 중복·책임) 3명이 각자 리포트를 씁니다. Critical/Important 지적이 있는 리뷰어만 다른 두 명에게 그 지적에 대한 반박을 1회 받고 수정하며, Minor뿐이면 반박 없이 바로 보고합니다. 리드가 종합해 사용자에게 묻습니다 — Critical/Important가 있으면 그 목록과 Minor 한 줄 요약을 함께, Minor뿐이면 건마다 한 줄 요약으로 짧게 묻고, 지적이 없으면 묻지 않습니다. 답을 받을 때까지 RED·GREEN·`tdd-refactor`는 종료하지 않습니다. 승인한 것만 반영합니다 — 테스트는 RED, 설계·가독성(`review-design`)은 `tdd-refactor`, 동작 누락·오류는 GREEN
5. **종료** — 팀원 종료 요청, 요약 출력, `session.md` 끝에 `session: COMPLETE` 기록(다음 실행이 묻지 않고 보관하도록), `_workspace/tdd-agent-team/`는 git 제외 상태로 남깁니다

## 팀원 정의 (`skills/tdd-agent-team/agents/` → `~/.claude/agents/`)

| 팀원 이름 | `subagent_type` | 정의 파일 | `tools` |
|---|---|---|---|
| `tdd-red` | `tdd-red` | `agents/tdd-red.md` | Read, Write, Edit, Bash, SendMessage |
| `tdd-green` | `tdd-green` | `agents/tdd-green.md` | Read, Write, Edit, Bash, SendMessage |
| `tdd-refactor` | `tdd-refactor` | `agents/tdd-refactor.md` | Read, Write, Edit, Bash, SendMessage |
| `review-domain` / `review-test` / `review-design` | `tdd-reviewer` | `agents/tdd-reviewer.md` (관점은 스폰 프롬프트로 지정) | Read, Write, Bash, SendMessage — `Edit` 없음 |

- 스킬이 Setup 0에서 정의 파일을 `~/.claude/agents/`에 설치(또는 갱신)할지 묻습니다. 설치 직후 에이전트 목록에 안 보이면 Claude Code를 다시 시작해야 합니다
- **user 범위에 두는 이유:** agent teams는 project·user·managed 범위의 정의만 팀원에게 적용합니다. 플러그인 에이전트(`devlife:tdd-red`)로 두면 오류 없이 무시되고, 팀원이 역할도 도구 제한도 없는 기본 에이전트로 뜹니다(실제 테스트에서 확인)
- 역할 지시는 정의 본문에 있어 팀원의 시스템 프롬프트로 들어갑니다. 스폰 프롬프트에는 `TDD_DIR` 같은 세션 정보만 담습니다
- `tdd-red`·`tdd-green`·`tdd-refactor`는 시작하자마자 리드에게 `READY` 한 줄을 보냅니다(`READ <경로>`가 아닌 유일한 메시지, 리뷰어는 생략). 첫 idle 알림이 올 때까지 보고가 없으면 `SendMessage`가 없는 것으로 보고 리드가 멈춥니다

### 테스트 작성 가이드 (`references/test-writing.md`)

- 테스트를 어떻게 쓰는지에 대한 규칙만 모은 문서입니다. 언어와 무관한 원칙에 Java(JUnit 5 + AssertJ) 예시를 붙였고, Python·TypeScript 대응표가 끝에 있습니다. Java가 아닌 프로젝트에서는 스킬 전체(사용자에게 보이는 화면 포함)에서 그 언어의 표현을 씁니다
- 이름 규칙 등 테스트 컨벤션은 기존 테스트나 프로젝트 지침에서 확인한 것만 프로젝트 규칙으로 기록하고, 그것이 이 문서보다 우선합니다. 기존 테스트가 없으면 이 문서를 따릅니다
- 담긴 규칙: 무엇을 테스트하는가(비즈니스 규칙과 경계, 시나리오 전부), 한 테스트에 한 동작, 같은 규칙은 한 테스트로 합치고 다른 규칙은 분리, 도메인 문장 이름, arrange·act·assert, 프로젝트 Fixture 사용, 계층별 테스트 전략, 기존 테스트 삭제 금지 — 글로벌 CLAUDE.md의 테스트 규칙(§3, §6 계층별 전략)을 반영
- RED와 `review-test` 리뷰어가 같은 파일을 읽습니다. 리드가 스폰 프롬프트에 `TEST_GUIDE` 경로로 넘깁니다(정의 파일에 경로를 박지 않아 설치 위치와 무관)
- 실행 시점·순서 같은 진행 규칙은 넣지 않았습니다 — 그건 팀원 정의의 몫입니다

### 구현 가이드 (`references/implementation.md`) — GREEN

- GREEN이 **테스트를 통과하는 최소 코드**를 쓰는 규칙입니다. 언어와 무관한 원칙에 Java(Spring) 예시
- 담긴 규칙: 범위(테스트가 요구하는 것만), 최소 구현 후 **리팩터링하지 않음**, 최소여도 지킬 것(도메인 규칙은 도메인에·도메인 언어로, 계층·의존 방향, 안티패턴), 테스트 수정 금지 — 글로벌 CLAUDE.md §5 범위·§6 반영
- GREEN과 `review-design`이 읽고, `tdd-refactor`에게는 남기는 코드의 하한선입니다

### 리팩터링 가이드 (`references/refactoring.md`) — tdd-refactor

- 동작을 바꾸지 않고 구조·품질을 바꾸는 규칙입니다. Tidy First(사이클 전, 계획 항목만)와 리팩터링(사이클 후, 세션에서 바뀐 구현 파일) 두 시점을 다룹니다
- 담긴 규칙: Tidy First 범위(문서에 적힌 것만, 추상화는 기존 케이스로만 추출), **클래스당 책임 하나 점검**(한 문장 서술·필드/의존성 묶음·변경 이유 세기 — 냄새 표보다 먼저), 코드 냄새→기법 표(바뀌는 이유가 둘 이상인 클래스, 태스크 사이 중복·하드코딩 일반화 포함), 일괄 적용 후 실패 시 하나씩, SOLID는 필요할 때만(단, 이미 있는 책임을 나누는 것은 YAGNI 위반이 아님), 가독성·메서드 순서, 테스트가 따라가야 할 때의 기계적 수정 목록 — 글로벌 CLAUDE.md §2·§5·§6 반영
- `tdd-refactor`와 `review-design`이 읽습니다. 리드가 `REFACTOR_GUIDE` 경로로 넘깁니다

### 무엇이 강제되고 무엇이 아닌가

- **강제됨:** 정의의 `tools` 목록. 리뷰어는 `Edit`이 없어 코드를 고칠 수 없습니다
- **강제되지 않음:** `tools`는 경로를 나누지 못하고, RED·GREEN 모두 테스트 실행에 Bash가 필요합니다. 그래서 RED가 구현 코드를 읽지 않는 것, GREEN이 테스트를 고치지 않는 것, GREEN의 red check는 모두 정의 파일의 지시에 기댑니다
- **사후 확인:** 리드의 최종 테스트와 `review-test` 관점(`red-check.log` 유무)이 위반을 잡는 독립 검사입니다. 써 보고 지시만으로 부족하면 hook을 다시 넣습니다

## 주의사항

- **역할 경계는 지시문 수준입니다** — 위 "무엇이 강제되고 무엇이 아닌가" 참고
- **red check는 "하나 이상 실패"를 봅니다** — 모든 메서드가 실패해야 한다는 규칙은 RED 지시문이 맡습니다
- **`~/.claude/agents/`에 파일을 씁니다** — 사용자 확인 후에만 설치합니다
- 실험 기능인 agent teams의 제약(대화형 세션 전용, 팀원 재개 불가)을 그대로 따릅니다

## 관련 스킬

- [tdd-subagent](./tdd-subagent.md) — 같은 TDD 원칙을 서브에이전트 순차 실행으로
- [plan-creator](./plan-creator.md) — 입력으로 쓸 계획 문서 생성, 완료 후 이 스킬로 넘길 수 있음
- [test-driven-development](./test-driven-development.md) — 직접 TDD 구현 시 원칙 가이드
