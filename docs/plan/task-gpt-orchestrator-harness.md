# spec: GPT 오케스트레이터 하네스

> 설계: `docs/brainstorming/2026-09-29-gpt-orchestrator-harness.md`

## 1. 기능 개요

Codex(GPT-5.6-Terra)가 지휘하고 Claude Code(Opus)가 작업하는 cmux 기반 하네스를 만든다. 오케스트레이터는 문서를 작성해 사람의 승인을 받고, 승인된 작업을 워커에 하나씩 위임한 뒤 테스트를 직접 실행해 검증한다. 목적은 교차 모델 검토의 효과를 실험하는 것이며, 실행 기록이 파일로 남아야 한다.

### 기능 구성

| 구성 | 설명 |
|---|---|
| **`devlife-orchestrator` 스킬** (Codex) | 준비 → 문서 → 승인 → 위임 루프 → 보고 |
| **오케스트레이터 정책** | 역할 규칙, 재시도 상한, 보고 시점, 테스트 금지 규칙 예외 |
| **인계 템플릿** | 지시(`task.md`)·결과(`result.md`)·원장(`ledger.md`) 형식 |
| **`devlife-worker` 에이전트** (Claude) | 질문 없이 작업하고 결과 파일과 완료 신호를 남김 |
| **워치독 pane** | 작업마다 30분 타임아웃을 샌드박스 밖에서 측정 |

### 선행 실험 결과 (2026-09-29, codex-cli 0.158.0 / Claude Code 2.1.284)

| 실험 | 결과 | 반영 |
|---|---|---|
| `codex queue`로 대기 중인 TUI 세션에 턴 시작 | 성공 | 완료 신호로 확정. 폴링 대체는 두지 않음 |
| 세션 안에서 자기 세션 ID 확인 | `CODEX_THREAD_ID` 환경변수 | 지시 파일의 알림 명령에 사용 |
| `--agent` 실행 시 전역 CLAUDE.md | 로드됨. 에이전트 프롬프트에 우선순위 문구가 있으면 질문 없이 수행 | 워커 프롬프트에 우선순위 문구 필수 |
| 플러그인 에이전트 이름 | `devlife:devlife-worker`, `devlife-worker` 모두 동작. 없는 이름은 에러로 종료 | `devlife:devlife-worker`로 명시 |
| Codex 기본 샌드박스에서 `cmux` | 소켓 차단으로 실패 | `-c sandbox_workspace_write.network_access=true`로 실행 |
| Codex 셸의 `CMUX_*` 환경변수 | 전달되지 않음. `--workspace` 없이 만든 pane이 포커스된 다른 workspace에 생김 | `shell_environment_policy.set`으로 주입하고 모든 cmux 호출에 `--workspace` 명시 |
| 샌드박스 안에서 `codex queue` | `~/.codex` 상태 DB 쓰기 금지로 실패. 백그라운드 `nohup`도 발동 안 함 | 워치독은 `cmux new-split --command`로 샌드박스 밖에서 실행 (성공 확인) |

---

## 2. 도메인 문맥 및 불변성

### 도메인 문맥

하네스에는 사람, 오케스트레이터, 워커의 세 주체가 있다. 사람은 문서 승인과 막힌 상황의 판단만 맡는다. 오케스트레이터는 판단과 검증만 하고 소스를 직접 고치지 않으며, 워커는 소스를 고치지만 사람과 대화하지 않는다. 두 에이전트는 서로의 내부를 모르고 cmux 신호(한 줄)와 `devlifeteam/<run-id>/` 아래 파일(내용)로만 연결된다. 한 번의 실행(run)은 승인된 문서 하나에 대응하며, 그 진행 상태의 유일한 원천은 `ledger.md`다.

### 비즈니스 불변성

| ID | 불변성 | 위반 시 영향 | 출처 |
|----|-------|------------|------|
| INV-001 | 오케스트레이터는 어떤 경우에도 작업 대상 소스 파일을 직접 수정하지 않는다. 쓰는 파일은 `devlifeteam/<run-id>/` 아래와 문서 스킬의 산출물뿐이다 | 교차 모델 검토 실험이 무효가 됨(검증자가 작업자가 됨) | `[사용자확인]` |
| INV-002 | 위임 루프는 사람의 명시적 문서 승인 이후에만 시작된다. spec 경로에서는 하위 작업마다 plan 승인이 따로 필요하다 | 승인되지 않은 범위의 코드 변경 | `[사용자확인]` |
| INV-003 | 워커는 사람에게 질문하거나 계획·피드백을 요청하지 않는다. 진행할 수 없으면 결과 파일에 `BLOCKED`와 사유를 적고 완료 신호를 보낸다 | 아무도 보지 않는 pane에서 교착, 30분 타임아웃까지 정지 | `[사용자확인]` |
| INV-004 | 오케스트레이터는 완료 신호(`codex queue`)를 받은 뒤에만 결과 파일을 읽는다 | 쓰는 중인 결과를 읽어 잘못 판정 | `[문서]` |
| INV-005 | 작업의 완료 판정은 워커 보고가 아니라 오케스트레이터가 직접 실행한 테스트 결과로만 한다 | 워커의 잘못된 "통과" 보고가 그대로 완료 처리됨 | `[사용자확인]` |
| INV-006 | 한 작업의 재지시는 최대 2회다. 초과하면 사람에게 보고하고 대기한다 | 두 에이전트가 고치고 되돌리기를 반복하며 비용 누수 | `[사용자확인]` |
| INV-007 | 지시·결과 파일은 덮어쓰지 않는다. 재지시는 `Txx-retryN.md`로 새로 만든다 | 오케스트레이터가 무엇을 잡아냈는지 비교할 실험 기록 소실 | `[사용자확인]` |
| INV-008 | 하네스 실행 중에는 누구도 git commit을 하지 않는다. 커밋은 실행이 끝난 뒤 사람이 한다 | 검증 전 변경이 이력에 섞임 | `[사용자확인]` |
| INV-009 | "테스트를 실행하지 않는다" 규칙의 예외는 하네스 실행 중에만 적용된다. 정책과 워커 에이전트 밖으로 새지 않는다 | 평소 세션의 사용자 규칙이 무력화됨 | `[사용자확인]` |
| INV-010 | 모든 cmux 호출은 `--workspace "$CMUX_WORKSPACE_ID"`를 명시한다 | 사람이 작업 중인 다른 workspace에 pane 생성·입력 전송 | `[사용자확인]` (실험에서 발생) |
| INV-011 | 워커의 권한은 시작 시 받은 테스트 명령과 고정 목록(`Read`, `Glob`, `Grep`, `Edit`, `Write`, `Bash(git diff*)`, `Bash(git status*)`, `Bash(codex queue*)`)으로 제한한다 | 무제한 셸 실행 | `[사용자확인]` |

---

## 3. 기존 코드의 함정 (답습 금지)

### 3-1. 결과 파일이 "비어 있지 않으면" 곧바로 읽는다

**현재 코드** — `skills/devlife-codex/SKILL.md` Step 4: `[ -f "$RESULT_FILE" ] && [ -s "$RESULT_FILE" ]`이 참이면 바로 `cat`

**왜 문제인가**: 파일 쓰기가 끝나기 전에 첫 바이트만 써진 상태를 완료로 판정할 수 있다.

**→ 신규는**: 결과 파일은 워커가 쓰고 나서 보내는 `codex queue` 신호를 받은 뒤에만 읽는다(INV-004). 폴링하지 않는다.

**기존 코드 수정 여부**: 수정하지 않음. `devlife-codex`는 재사용 대상이 아니다.

### 3-2. 긴 프롬프트를 터미널에 그대로 보낸다

**현재 코드** — `skills/devlife-codex/SKILL.md` Step 3: 작업 전체를 `cmux send`로 전송하고, 길면 `mktemp /tmp/...`에 담아 `$(cat ...)`로 전송

**왜 문제인가**: 따옴표·`$`·백틱 이스케이프가 깨지고 붙여넣기가 잘린다. `/tmp`는 Codex 샌드박스 쓰기 범위 밖이다.

**→ 신규는**: 내용은 `devlifeteam/<run-id>/tasks/Txx.md`에 쓰고, 워커에는 경로를 담은 한 줄만 보낸다.

**기존 코드 수정 여부**: 수정하지 않음.

### 3-3. pane을 제목 문자열로 찾는다

**현재 코드** — `skills/devlife-codex/SKILL.md` Step 1: `cmux tree --json`에서 `title == "Codex"` 검색

**왜 문제인가**: 제목은 실행 중인 프로그램이 바꾼다(Claude Code는 세션 요약으로 탭 제목을 덮어씀). 같은 제목이 다른 workspace에 있을 수 있다.

**→ 신규는**: `cmux new-split` 출력(`OK surface:N workspace:M`)의 surface ref를 `ledger.md`에 기록하고 그 ref로만 접근한다. `rename-tab`은 사람이 알아보기 위한 표시일 뿐 탐색에 쓰지 않는다.

**기존 코드 수정 여부**: 수정하지 않음.

### 3-4. `plan-creator`가 승인 후 `tdd-team`으로 넘어간다

**현재 코드** — `codex/skills/plan-creator/SKILL.md` Step 5: 승인 후 `tdd-team` 핸드오프 질문

**왜 문제인가**: 재사용하면 루프 대신 `tdd-team`이 시작될 수 있다.

**→ 신규는**: 오케스트레이터 스킬이 "`plan-creator`는 Step 4 승인까지 진행하고 Step 5는 실행하지 않는다. 승인되면 위임 루프로 전환한다"를 명시한다. `spec-creator` Step 5(→ `plan-creator`)는 spec 경로의 흐름과 같으므로 그대로 둔다.

**기존 코드 수정 여부**: 수정하지 않음(스킬 재사용 원칙).

### 3-5. 권한 규칙을 `Write(경로)`로 쓴다

**현재 코드** — `~/.claude/settings.json`의 `Write(**/src/**)` 규칙. 실행할 때마다 "only Edit(path) rules are" 경고가 뜸

**→ 신규는**: 경로 제한이 필요하면 `Edit(경로)` 규칙을 쓴다. 이번 워커 허용 목록은 경로 제한 없이 도구 이름만 쓴다.

**기존 코드 수정 여부**: 사용자 전역 설정이라 이 작업 범위 밖이다.

---

## 5. 비즈니스 로직

### 5-1. 오케스트레이터 실행 전제

오케스트레이터 Codex는 cmux 터미널 안에서 다음 옵션으로 실행되어야 한다. 문서(`docs/devlife-orchestrator.md`)에 셸 alias로 제공한다.

```bash
codex -c sandbox_workspace_write.network_access=true \
      -c "shell_environment_policy.set.CMUX_WORKSPACE_ID=\"$CMUX_WORKSPACE_ID\"" \
      -c "shell_environment_policy.set.CMUX_SOCKET_PATH=\"$CMUX_SOCKET_PATH\""
```

스킬 Step 0에서 `$CMUX_WORKSPACE_ID`가 비었거나 `cmux ping`이 실패하면 진행하지 않고, 위 명령으로 다시 실행하라고 안내한다.

### 5-2. 흐름

| 단계 | 처리 |
|---|---|
| 0. 전제 확인 | `CMUX_WORKSPACE_ID`, `CODEX_THREAD_ID`, `cmux ping` 확인. `devlifeteam/*/ledger.md` 중 미완료 run이 있으면 재개할지 질문 |
| 1. 준비 | 사람에게 테스트 명령(예: `./gradlew test`) 확인 → `run-id`(`YYYYMMDD-HHMMSS`) 생성 → 디렉토리 생성 → 워커 pane 실행 → surface ref 기록 → 사이드바 상태 `준비` |
| 2. 문서 | 요청 크기에 따라 `plan-creator` 또는 `spec-creator`를 사람과 대화하며 실행. `plan-creator` Step 5는 실행하지 않음 |
| 3. 승인 | 명시적 승인 → 문서의 작업을 `ledger.md`의 T01..Tn으로 옮김 |
| 4. 루프 | 5-3 참고 |
| 5. 보고 | 전체 완료 또는 막힘 → `cmux notify` + 오케스트레이터 pane에 보고. spec 경로면 다음 하위 작업의 `plan-creator`로 돌아가 2단계부터 반복 |

### 5-3. 작업 하나의 루프

1. 워커에 `/clear` 전송
2. `tasks/Txx.md` 작성 (템플릿 `assets/task.md`)
3. 워치독 pane 실행 → surface ref를 원장에 기록
4. 워커에 한 줄 전송: `Read devlifeteam/<run-id>/tasks/Txx.md and do it.`
5. 대기 (턴 종료). `codex queue` 메시지로 깨어남
   - `Txx done` → 워치독 pane을 닫고, 결과 파일을 읽고, 테스트 명령을 직접 실행
   - `Txx timeout` → 워커 화면을 `read-screen`으로 읽어 원인과 함께 사람에게 보고
6. 판정

| 결과 파일 상태 | 테스트 | 처리 |
|---|---|---|
| `DONE` | 통과 | 원장 `done`, 사이드바 진행률 갱신, 다음 작업 |
| `DONE` | 실패 | 재지시 (`Txx-retryN.md`에 실패 내용과 부족한 점) |
| `BLOCKED` | — | 오케스트레이터가 해결 가능한 정보 부족이면 재지시, 아니면 사람에게 보고 |
| 재지시 2회 초과 | — | 원장 `blocked`, 사람에게 보고하고 대기 |

### 5-4. 신호 형식

| 신호 | 발신 | 명령 |
|---|---|---|
| 지시 | 오케스트레이터 | `cmux send --workspace "$CMUX_WORKSPACE_ID" --surface <worker> "<한 줄>"` → `sleep 0.3` → `"\n"` 별도 전송 |
| 완료 | 워커 | `codex queue --thread <thread-id> --message "<task-id> done"` |
| 타임아웃 | 워치독 | `sleep 1800; [ -f <result> ] \|\| codex queue --thread <thread-id> --message "<task-id> timeout"; exit` |

---

## 6. 구현 대상 파일

### Codex 플러그인 (`codex/`)

| 파일 | 역할 |
|------|------|
| `codex/skills/devlife-orchestrator/SKILL.md` | 5-2 흐름, 5-3 루프, cmux 명령 (영문) |
| `codex/skills/devlife-orchestrator/references/orchestrator-policy.md` | INV-001~011을 역할 규칙으로 서술 (영문) |
| `codex/skills/devlife-orchestrator/assets/task.md` | 지시 파일 템플릿 |
| `codex/skills/devlife-orchestrator/assets/result.md` | 결과 파일 템플릿 |
| `codex/skills/devlife-orchestrator/assets/ledger.md` | 원장 템플릿 |

### Claude 플러그인 (루트)

| 파일 | 역할 |
|------|------|
| `agents/devlife-worker.md` | 워커 모드 규칙, `tools`, `model: opus` |

### 레포 관리 파일 변경

- `scripts/check-skill-parity.sh`: `CODEX_ONLY_SKILLS=" devlife-orchestrator "` 추가, 이 목록의 스킬은 "codex 에만 존재" 실패에서 제외
- `docs/devlife-orchestrator.md`: `## 언제 사용하나요?`, `## 트리거 문구`, `## 실행 흐름` + 실행 alias와 전제 조건
- `README.md`: `devlife-tools` Skills 표에 `devlife-orchestrator` `0.1.0` 행, `#### Agents` 표 신설 후 `devlife-worker` `0.1.0` 행, `## Plugins` 요약 설명 갱신
- `CHANGELOG.md`: 2026-09-29 항목에 두 컴포넌트 추가
- `spec-creator`, `plan-creator`, `cmux`, `devlife-codex`, `devlife-team-starter`: 변경 없음

### 코드 스니핏

**워커 pane 실행** (SKILL.md 1단계)

```bash
WS="$CMUX_WORKSPACE_ID"
OUT=$(cmux new-split right --workspace "$WS" --focus false --command \
  "cd '$PROJECT_ROOT' && claude --agent devlife:devlife-worker --permission-mode dontAsk --allowedTools \
   Read Glob Grep Edit Write 'Bash($TEST_CMD*)' 'Bash(git diff*)' 'Bash(git status*)' 'Bash(codex queue*)'")
WORKER=$(echo "$OUT" | grep -oE 'surface:[0-9]+')   # INV-010, 3-3: ref로만 접근
cmux rename-tab --workspace "$WS" --surface "$WORKER" "Worker"
# 에이전트 이름이 없으면 claude가 에러로 종료 → read-screen으로 "not found" 확인 후 플러그인 설치 안내
```

**작업 위임** (SKILL.md 4단계, 작업마다)

```bash
cmux send --workspace "$WS" --surface "$WORKER" "/clear"; sleep 0.3
cmux send --workspace "$WS" --surface "$WORKER" "\n"; sleep 1
# tasks/T01.md 작성은 파일 쓰기로 (INV-001: devlifeteam/ 아래만)
DOG=$(cmux new-split down --workspace "$WS" --focus false --command \
  "sleep 1800; [ -f '$RUN/results/T01.md' ] || codex queue --thread $CODEX_THREAD_ID --message 'T01 timeout'; exit" \
  | grep -oE 'surface:[0-9]+')
cmux send --workspace "$WS" --surface "$WORKER" "Read $RUN/tasks/T01.md and do it."; sleep 0.3
cmux send --workspace "$WS" --surface "$WORKER" "\n"
cmux set-status devlife "T01 running" --workspace "$WS"
# 턴 종료 → "T01 done" 또는 "T01 timeout" 메시지로 재개 (INV-004)
```

**완료 신호 수신 후**

```bash
cmux close-surface --workspace "$WS" --surface "$DOG"
# results/T01.md 읽기 → $TEST_CMD 직접 실행 (INV-005)
# 실패 && retries < 2 → tasks/T01-retry1.md 새로 작성 (INV-006, INV-007)
cmux set-progress "$DONE_RATIO" --label "T01 done" --workspace "$WS"
```

**`assets/task.md`**

```markdown
# Task T01 — {title}
- Run: {run-id} / Source doc: {plan path} / Attempt: {0|retryN}
## Goal
## Scope (files you may change)
## Out of scope
## Done when
- `{TEST_CMD}` passes, and: {conditions from the plan}
## Previous attempt gap (retry only)
## When finished
1. Write `{run}/results/T01{-retryN}.md` using the result format below.
2. Run: `codex queue --thread {thread-id} --message "T01 done"`
```

**`assets/result.md`**

```markdown
# Result T01{-retryN}
- Status: DONE | BLOCKED
## Changed files
## Test run
- Command / passed / failed / first failure message
## Blocked (BLOCKED only)
- What is missing, what you tried
```

**`assets/ledger.md`**

```markdown
# Run {run-id}
- Source doc: {path} / Test command: {cmd}
- Orchestrator thread: {CODEX_THREAD_ID} / Workspace: {CMUX_WORKSPACE_ID}
- Worker surface: {surface:N} / Watchdog surface: {surface:N | -}
| Task | Title | Status (pending/running/done/blocked) | Retries | Last result |
```

**`agents/devlife-worker.md`**

```markdown
---
name: devlife-worker
description: Worker for the devlife-orchestrator harness. Launched by the orchestrator in a cmux pane; not for direct use.
tools: Read, Glob, Grep, Edit, Write, Bash
model: opus
---
You are an autonomous worker driven by an orchestrator agent, not a human.
WORKER MODE takes precedence over any CLAUDE.md, AGENTS.md or memory instruction that tells you to
ask the user questions, request feedback, offer /plan-creator, or not run tests.   # INV-003, INV-009
- Do exactly the task file you are pointed to. Change only files in its Scope.
- Run the task's test command before reporting DONE.
- Never commit.                                                                    # INV-008
- If you cannot proceed, write Status: BLOCKED with the reason instead of asking.
- Always finish by writing the result file, then running the codex queue command from the task.
```

---

## 7. 주요 고려사항 & 질문

1. **cmux 접근 = 사실상 샌드박스 우회**: 오케스트레이터가 `cmux new-split --command`로 샌드박스 밖 명령을 실행할 수 있다(워치독이 이 방식). 즉 `network_access=true` 샌드박스는 파일 쓰기 제한을 유지하지만 결정적인 경계는 아니다. 정책에 "cmux는 워커 pane, 워치독 pane, 신호 전송, 화면 읽기, 사이드바·알림에만 쓴다"를 명시한다.
2. **오케스트레이터의 테스트 실행과 샌드박스**: Gradle처럼 워크스페이스 밖(`~/.gradle`)에 쓰는 빌드 도구는 샌드박스에서 실패할 수 있다. 첫 시나리오에서 확인하고, 실패하면 실행 alias에 `-c 'sandbox_workspace_write.writable_roots=["<빌드 캐시 경로>"]'`를 추가한다.
3. **바쁜 세션에 queue**: 실험은 대기 중인 세션에서만 했다. 오케스트레이터가 사람과 대화 중일 때 신호가 오면 현재 턴 뒤에 처리될 것으로 예상하며, 시나리오에서 확인한다.
4. **CLAUDE.md 우선순위는 1회 확인**: headless(`-p`) 1회 결과다. 대화형 TUI에서 재확인한다(8단계 시나리오).
5. **커밋 주체**: 이번에는 사람이 커밋(INV-008). 안정되면 "검증 통과 작업마다 오케스트레이터가 커밋"으로 바꾸는 것을 별도 작업으로 검토한다.

---

## 8. 구현 순서

> 스킬·에이전트 정의라 자동 테스트가 없다. 테스트 항목은 cmux에서 실제로 돌리는 **시나리오 검증**이다. 모든 항목이 `[NEW]`다.

### 1단계: 레포 관리

1. [ ] `scripts/check-skill-parity.sh` — `CODEX_ONLY_SKILLS` 추가 (커밋: `chore: allow codex-only skills in parity check`)

### 2단계: 워커

2. [ ] `agents/devlife-worker.md` 작성
3. [ ] `[NEW]` `INV-003` `INV-009` 대화형 워커 — `"워커는 전역 CLAUDE.md가 있어도 질문 없이 작업하고 테스트를 실행한다"`
4. [ ] `[NEW]` `INV-011` — `"허용 목록 밖의 명령은 권한 프롬프트 없이 거부되고, 워커는 BLOCKED로 보고한다"` (`--permission-mode dontAsk`)

### 3단계: 오케스트레이터

5. [ ] `assets/task.md`, `result.md`, `ledger.md` 작성
6. [ ] `references/orchestrator-policy.md` 작성
7. [ ] `SKILL.md` 작성 — 0~5단계
8. [ ] `[NEW]` `INV-010` — `"실행 전제가 없으면 시작하지 않고 실행 명령을 안내한다"`
9. [ ] `[NEW]` `INV-010` — `"워커와 워치독 pane은 오케스트레이터와 같은 workspace에만 생긴다"`
10. [ ] `[NEW]` `INV-002` `INV-005` — `"작업 2개짜리 plan은 승인 후 사람 개입 없이 검증까지 완료된다"`
11. [ ] `[NEW]` `INV-004` `INV-001` — `"오케스트레이터는 완료 신호 전에 결과를 읽지 않고, 소스를 직접 고치지 않는다"`
12. [ ] `[NEW]` `INV-006` `INV-007` — `"테스트가 실패하면 재지시 파일을 새로 만들고, 2회 초과 시 사람에게 보고한다"`
13. [ ] `[NEW]` 타임아웃 — `"워커가 응답하지 않으면 워치독 신호로 깨어나 워커 화면과 함께 보고한다"` (검증 시에만 sleep을 60초로 줄여 실행)
14. [ ] `[NEW]` 재개 — `"중단된 run은 ledger.md 기준으로 이어서 진행한다"`
15. [ ] `[NEW]` `INV-002` spec 경로 — `"spec 승인 후 하위 작업마다 plan 승인을 따로 받는다"`
16. [ ] `[NEW]` `INV-008` — `"실행이 끝나도 커밋은 생기지 않는다"`

### 4단계: 문서와 버전

17. [ ] `docs/devlife-orchestrator.md`, `README.md`, `CHANGELOG.md` (커밋: `feat: add devlife-orchestrator skill and devlife-worker agent`)

---

## 9. 인수 조건

- [ ] 작업 2개짜리 plan 하나가 승인 이후 사람 개입 없이 완료되고, 오케스트레이터가 직접 실행한 테스트로 판정된다
- [ ] 재시도 상한 도달과 워커 타임아웃이 원인과 함께 사람에게 보고된다
- [ ] 다른 workspace에 pane이나 입력이 전달되지 않는다
- [ ] `devlifeteam/<run-id>/`에 지시·결과·재지시 파일이 모두 남는다
- [ ] `./scripts/check-skill-parity.sh`가 통과한다
