# tdd-agent-team

Claude Code **agent teams**로 Red-Green-Refactor TDD를 실행합니다.  
`tdd-red` 팀원은 실패 테스트를 태스크 순서대로 계속 작성하고, `tdd-green` 팀원은 넘겨받은 순서대로 통과시킵니다. 두 팀원이 직접 일을 주고받아, 태스크 N+1의 RED와 태스크 N의 GREEN이 동시에 진행됩니다. 역할 경계와 넘겨주기 조건은 hook이 강제합니다.

## 언제 사용하나요?

- 태스크가 여러 개이고 RED와 GREEN을 겹쳐 돌려 시간을 줄이고 싶을 때
- 사이클마다 확인받지 않고, 태스크 확정 후 끝까지 맡기고 싶을 때
- 마지막에 관점이 다른 리뷰어들이 서로 반박하는 교차 리뷰를 받고 싶을 때

`tdd-subagent`와의 차이:

| | `tdd-subagent` | `tdd-agent-team` |
|---|---|---|
| 실행 단위 | 단계마다 새 서브에이전트, 순차 | 계속 살아 있는 RED·GREEN 팀원, 병렬 |
| 넘겨주기 | 오케스트레이터가 모든 단계를 호출 | RED → GREEN 직접 전달, 리드는 관리만 |
| 격리 | 단계마다 컨텍스트가 새로 시작 | hook으로 강제 — RED는 구현 코드 읽기·쓰기 불가, GREEN은 테스트 쓰기 불가 |
| 사이클 검증 | 사이클마다 리뷰어 | 넘겨주기 게이트(실제 테스트 실행) |
| 사용자 확인 | 1번 사이클 후, 이후 선택 | 태스크 확정 시 + 최종 리뷰 반영 전 |
| 재개 | 지원 (`session.md`) | 미지원 — 팀원이 복원되지 않음 |
| 필요 조건 | 없음 | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, 대화형 세션, devlife 플러그인(팀원 정의 + hook) |

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
2. **`roles.env` 작성** — 컴파일 명령, **메서드 단위** 테스트 명령, 테스트·구현 경로 패턴. hook이 이 파일을 읽습니다. RED가 같은 클래스에 다음 태스크의 실패 테스트를 추가하는 동안 GREEN이 돌기 때문에, 클래스 단위로 돌리면 남의 실패가 섞입니다
3. **불변성·태스크 도출** — 요구사항 문서 우선, 커버리지 하한(불변성마다 어기는/지키는 경계 + 클래스당 해피패스), 하나의 구현 변경으로 통과하는 시나리오는 한 태스크로 병합, 의존하는 태스크는 뒤로
4. **태스크 확정** ← 사용자 확인 1
5. **`context.md`·`session.md`·`tasks/NN/task.md` 작성** — `context.md`의 「RED가 호출할 수 있는 시그니처」는 구현 코드를 못 읽는 RED의 유일한 창구입니다
6. **스텁 일괄 생성** — RED는 구현 경로를 쓸 수 없으므로 리드가 계획 문서 시그니처로 미리 만듭니다(`UnsupportedOperationException`). 리드가 소스 파일을 수정하는 마지막 시점입니다

### 사이클

```
리드 ──READ tasks/──▶ tdd-red
                       │ 태스크 01 실패 테스트 → red-result.md
                       ├─READ tasks/01/red-result.md─▶ tdd-green   ◀ red 게이트: 컴파일 + 실패
                       │ 태스크 02 실패 테스트 …             │ 최소 구현 → 구현 코드 정리 → green-result.md
                       ├─READ tasks/02/red-result.md─▶      │
                       ⋮                                    └─READ tasks/01/green-result.md─▶ 리드   ◀ green 게이트: 통과
```

- **메시지 본문은 `READ <경로>` 한 줄뿐**입니다. 내용은 `.tdd-agent-team/` 아래 md 파일에 씁니다
- 리드는 넘겨주기 경로에 끼지 않습니다. `green-result.md` 보고마다 `session.md`를 갱신하고, `missing-stub.md`(스텁 추가)·`blocked.md`(사실 보충 또는 사용자에게 에스컬레이션)만 처리합니다
- 게이트가 두 번 거절하면 해당 팀원이 `blocked.md`를 써서 리드에게 보내고 다음 태스크로 넘어갑니다

### 마무리

1. **테스트 코드 정리** — 모든 태스크가 끝난 뒤 RED가 테스트 파일을 한 번에 정리합니다(사이클 중에는 두 팀원이 같은 테스트 파일을 건드리지 않도록 GREEN은 구현 코드만 정리)
2. **최종 테스트** — 세션의 모든 메서드 + `[REGRESSION]` 클래스를 한 번에 실행, 실패 시 GREEN에 수정 요청(최대 2라운드)
3. **병렬 최종 리뷰** ← 사용자 확인 2 — `review-domain`(불변성 매트릭스·범위), `review-test`(테스트 품질·red 게이트 로그 유무), `review-design`(태스크 간 중복·책임) 3명이 각자 리포트를 쓰고 서로 1회 반박한 뒤 리드가 종합합니다. Critical/Important 지적 중 승인한 것만 구현은 GREEN, 테스트는 RED가 반영합니다
4. **종료** — 팀원 종료 요청, 요약 출력, `.tdd-agent-team/`는 git 제외 상태로 남깁니다

## 팀원 정의 (devlife 플러그인 `agents/`)

| 팀원 이름 | `subagent_type` | 정의 파일 |
|---|---|---|
| `tdd-red` | `devlife:tdd-red` | `agents/tdd-red.md` |
| `tdd-green` | `devlife:tdd-green` | `agents/tdd-green.md` |
| `review-domain` / `review-test` / `review-design` | `devlife:tdd-reviewer` | `agents/tdd-reviewer.md` (관점은 스폰 프롬프트로 지정) |

- 역할 지시는 정의 본문에 있어 팀원의 시스템 프롬프트로 들어갑니다. 스폰 프롬프트에는 `TDD_DIR` 같은 세션 정보만 담습니다
- 리뷰어 정의에는 `Edit`이 없습니다 — 리뷰하다가 코드를 고치지 못합니다
- 팀원은 시작하자마자 실제로 받은 도구 목록을 `tools-{이름}.md`로 리드에게 보고합니다. 역할에 필요한 도구가 빠졌으면 리드가 팀을 멈추고 알립니다
- 정의 파일에는 `hooks`를 넣지 않습니다. 플러그인 에이전트는 보안상 `hooks`·`mcpServers`·`permissionMode` 필드가 무시되기 때문에, 역할 제한은 아래 플러그인 hook이 팀원 이름으로 강제합니다

## hook (devlife 플러그인)

| Hook | 언제 | 하는 일 |
|---|---|---|
| `enforce-tdd-roles` | `tdd-red`/`tdd-green`의 Read·Write·Edit·Grep | RED: 구현 경로 읽기·쓰기 차단, Grep은 테스트 경로·`.tdd-agent-team/`만. GREEN: 테스트 경로 쓰기 차단 |
| `gate-tdd-handoff` | `tdd-red`/`tdd-green`의 SendMessage | RED → GREEN 넘겨주기는 테스트가 컴파일되고 실패할 때만, GREEN → 리드 완료 보고는 통과할 때만 전달. RED → GREEN의 다른 메시지와 GREEN → RED 메시지는 차단 |

- hook은 팀원을 **이름**(`tdd-red`, `tdd-green`)으로 식별하고, `.tdd-agent-team/roles.env`가 있는 프로젝트에서만 작동합니다. 다른 세션·에이전트에는 영향이 없습니다
- 게이트 실행 로그는 `tasks/NN/red-gate.log`, `green-gate.log`에 남습니다. `red-gate.log`가 없는 태스크는 넘겨주기 게이트를 거치지 않은 것이라 최종 리뷰에서 지적됩니다

## 주의사항

- **Bash 우회는 막지 못합니다** — RED는 테스트 실행에 Bash가 필요해서, `cat` 등으로 구현 코드를 읽는 것은 지시문으로만 막습니다
- **게이트 대기** — 넘겨주기마다 게이트가 테스트를 돌리는 동안(수십 초) 보내는 팀원이 기다립니다
- **red 게이트는 "하나 이상 실패"를 봅니다** — 모든 메서드가 실패해야 한다는 규칙은 RED 지시문이 맡습니다
- **플러그인 없이 스킬만 복사하면** 팀원 정의와 hook이 모두 없어 실행할 수 없습니다. 스킬이 시작할 때 확인하고 멈춥니다
- 실험 기능인 agent teams의 제약(대화형 세션 전용, 팀원 재개 불가)을 그대로 따릅니다

## 관련 스킬

- [tdd-subagent](./tdd-subagent.md) — 같은 TDD 원칙을 서브에이전트 순차 실행으로
- [plan-creator](./plan-creator.md) — 입력으로 쓸 계획 문서 생성, 완료 후 이 스킬로 넘길 수 있음
- [test-driven-development](./test-driven-development.md) — 직접 TDD 구현 시 원칙 가이드
