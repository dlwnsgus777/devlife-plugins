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
| 넘겨주기 | 오케스트레이터가 모든 단계를 호출 | RED → GREEN 직접 전달, 리드는 관리만 |
| 격리 | 단계마다 컨텍스트가 새로 시작 | 정의 파일의 지시 — RED는 구현 코드를 읽지·쓰지 않고, GREEN은 테스트를 쓰지 않음(강제 장치 없음) |
| 사이클 검증 | 사이클마다 리뷰어 | GREEN이 구현 전에 테스트가 실제로 실패하는지 확인(red check) |
| 사용자 확인 | 1번 사이클 후, 이후 선택 | 태스크 확정 시 + 최종 리뷰 반영 전 |
| 재개 | 지원 (`session.md`) | 미지원 — 팀원이 복원되지 않음 |
| 필요 조건 | 없음 | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, 대화형 세션, 팀원 정의 파일을 `~/.claude/agents/`에 설치 |

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

0. **agent teams 확인** — `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`가 `1`이 아니면 `~/.claude/settings.json` 수정을 제안하고, 동의할 때만 고칩니다. 거절하면 `tdd-subagent`를 안내하고 마칩니다
1. **이전 세션** — `.tdd-agent-team/session.md`가 있으면 팀원이 복원되지 않아 이어갈 수 없음을 알리고, 보관(`archive-*/`) 후 새로 시작할지 묻습니다
2. **`roles.env` 작성** — 컴파일 명령과 **메서드 단위** 테스트 명령. 팀원이 이 파일에서 명령을 읽습니다. RED가 같은 클래스에 다음 태스크의 실패 테스트를 추가하는 동안 GREEN이 돌기 때문에, 클래스 단위로 돌리면 남의 실패가 섞입니다
3. **불변성·태스크 도출** — 요구사항 문서 우선, 커버리지 하한(불변성마다 어기는/지키는 경계 + 클래스당 해피패스), 하나의 구현 변경으로 통과하는 시나리오는 한 태스크로 병합, 의존하는 태스크는 뒤로
4. **태스크 확정** ← 사용자 확인 1
5. **`context.md`·`session.md`·`tasks/NN/task.md` 작성** — `context.md`의 「RED가 호출할 수 있는 시그니처」는 구현 코드를 못 읽는 RED의 유일한 창구입니다
6. **스텁 일괄 생성** — RED는 구현 파일을 쓰지 않으므로 리드가 계획 문서 시그니처로 미리 만듭니다(`UnsupportedOperationException`). 리드가 소스 파일을 수정하는 마지막 시점입니다

### 사이클

```
리드 ──READ tasks/──▶ tdd-red
                       │ 태스크 01 실패 테스트 → red-result.md
                       ├─READ tasks/01/red-result.md─▶ tdd-green
                       │ 태스크 02 실패 테스트 …             │ red check(컴파일 + 실패) → 최소 구현 → 구현 코드 정리 → green-result.md
                       ├─READ tasks/02/red-result.md─▶      │   (red check 실패 시 ─READ tasks/NN/gate.md─▶ tdd-red)
                       ⋮                                    └─READ tasks/01/green-result.md─▶ 리드
```

- **메시지 본문은 `READ <경로>` 한 줄뿐**입니다. 내용은 `.tdd-agent-team/` 아래 md 파일에 씁니다
- 리드는 넘겨주기 경로에 끼지 않습니다. 대신 GREEN의 `green-result.md` 보고마다 **태스크 검수** 3가지를 합니다 — `red-check.log`가 있는지(없으면 기록만 하고 최종 리뷰가 지적), 수정 파일이 In-scope 안인지(벗어나면 GREEN에 되돌림), 해당 메서드가 실제로 통과하는지(직접 실행, 실패하면 되돌림). 같은 태스크가 두 번 되돌려지면 BLOCKED로 두고 사용자에게 묻습니다. `missing-stub.md`·`blocked.md`도 리드가 처리합니다
- GREEN의 red check가 같은 태스크를 두 번 거절하면 RED가 `blocked.md`를 써서 리드에게 보냅니다

### 마무리

1. **테스트 코드 정리** — 모든 태스크가 끝난 뒤 RED가 테스트 파일을 한 번에 정리합니다(사이클 중에는 두 팀원이 같은 테스트 파일을 건드리지 않도록 GREEN은 구현 코드만 정리)
2. **최종 테스트** — 세션의 모든 메서드 + `[REGRESSION]` 클래스를 리드가 한 번에 실행. 팀원이 스스로 하지 않는 유일한 테스트 실행이라, GREEN이 통과 없이 완료를 보고한 경우를 여기서 잡습니다. 실패 시 GREEN에 수정 요청(최대 2라운드)
3. **병렬 최종 리뷰** ← 사용자 확인 2 — `review-domain`(불변성 매트릭스·범위), `review-test`(테스트 품질·`red-check.log` 유무), `review-design`(태스크 간 중복·책임) 3명이 각자 리포트를 씁니다. Critical/Important 지적이 있는 리뷰어만 다른 두 명에게 그 지적에 대한 반박을 1회 받고 수정하며, Minor뿐이면 반박 없이 바로 보고합니다. 리드가 종합합니다. Critical/Important 지적 중 승인한 것만 구현은 GREEN, 테스트는 RED가 반영합니다
4. **종료** — 팀원 종료 요청, 요약 출력, `.tdd-agent-team/`는 git 제외 상태로 남깁니다

## 팀원 정의 (`skills/tdd-agent-team/agents/` → `~/.claude/agents/`)

| 팀원 이름 | `subagent_type` | 정의 파일 | `tools` |
|---|---|---|---|
| `tdd-red` | `tdd-red` | `agents/tdd-red.md` | Read, Write, Edit, Bash, SendMessage |
| `tdd-green` | `tdd-green` | `agents/tdd-green.md` | Read, Write, Edit, Bash, SendMessage |
| `review-domain` / `review-test` / `review-design` | `tdd-reviewer` | `agents/tdd-reviewer.md` (관점은 스폰 프롬프트로 지정) | Read, Write, Bash, SendMessage — `Edit` 없음 |

- 스킬이 Setup 0에서 정의 파일을 `~/.claude/agents/`에 설치(또는 갱신)할지 묻습니다. 설치 직후 에이전트 목록에 안 보이면 Claude Code를 다시 시작해야 합니다
- **user 범위에 두는 이유:** agent teams는 project·user·managed 범위의 정의만 팀원에게 적용합니다. 플러그인 에이전트(`devlife:tdd-red`)로 두면 오류 없이 무시되고, 팀원이 역할도 도구 제한도 없는 기본 에이전트로 뜹니다(실제 테스트에서 확인)
- 역할 지시는 정의 본문에 있어 팀원의 시스템 프롬프트로 들어갑니다. 스폰 프롬프트에는 `TDD_DIR` 같은 세션 정보만 담습니다
- `tdd-red`·`tdd-green`은 시작하자마자 실제로 받은 도구 목록을 `tools-{이름}.md`로 리드에게 보고합니다(리뷰어는 생략 — 수명이 짧고, 정의가 안 붙어도 잃는 건 `Edit` 금지뿐). 정의에 없는 도구(`Agent`, `Skill`, MCP 등)가 보이면 정의가 적용되지 않은 것이라 리드가 멈춥니다

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
