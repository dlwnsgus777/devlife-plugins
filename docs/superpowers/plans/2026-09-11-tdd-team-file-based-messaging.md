# tdd-team 파일 기반 에이전트 통신 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** tdd-team의 에이전트 통신을 프롬프트 인라인에서 `.tdd-team/` md 파일 경유로 전환해, 오케스트레이터 컨텍스트 누적을 줄이고 세션 재개·사람 개입·사이클 디버깅을 가능하게 한다.

**Architecture:** 에이전트는 결과 전문을 `{TASK_DIR}/*-result.md`에 쓰고 반환값으로는 `TDD_STATUS` envelope(고정 8줄)만 준다. 오케스트레이터는 envelope만으로 모든 분기를 판단하고 결과 전문은 읽지 않는다. 다음 단계 에이전트가 이전 단계 결과 파일을 직접 읽는다.

**Tech Stack:** Markdown 스킬 파일 (`skills/`, `codex/skills/`), Claude Code `Agent` 툴, Bash(grep/git).

**Spec:** `docs/superpowers/specs/2026-09-11-tdd-team-file-based-messaging-design.md`

## Global Constraints

- SKILL.md·references 본문은 **영어**로 작성한다. 사용자에게 그대로 출력되는 인용문(`> "…"`)만 한국어를 유지한다.
- `skills/`(Claude용)에는 Codex 전용 문구를 넣지 않는다. 서브에이전트는 `Agent({ subagent_type: "general-purpose", ... })` 문법을 쓴다.
- `codex/skills/tdd-team/`은 프로세스 뼈대를 동일하게 유지하되 에이전트 호출 문법·툴 이름만 Codex에 맞춘다.
- 산출물 디렉토리 이름은 `.tdd-team/`으로 고정한다. 태스크 디렉토리는 `task-01`, `task-02` … 2자리 zero-pad.
- envelope 이름은 `TDD_STATUS`로 고정한다. 한국어 문서에서만 "STATUS 봉투"로 부른다.
- 기존 결과 블록(`RED_RESULT`/`GREEN_RESULT`/`REFACTOR_RESULT`/`FIX_RESULT`)의 **필드 구성은 변경하지 않는다.** 위치만 파일로 옮긴다.
- 사용자 레포의 `.gitignore`는 건드리지 않는다. 추적 제외는 `.git/info/exclude`로만 한다.
- 커밋 메시지 형식: `type: subject` (소문자, 명령형).
- 버전: README의 `tdd-team`을 `1.10.0` → `2.0.0`.

## 검증 방식에 관한 참고

이 계획은 코드가 아니라 **스킬 문서**를 바꾼다. 실행 가능한 단위 테스트가 없으므로, 각 태스크의 "테스트"는 다음 두 가지다.

1. **구조 검증** — `grep`으로 필수 문자열의 존재/부재를 확인한다. 각 태스크에 실제 명령과 기대 출력을 적어 두었다.
2. **상호 일관성 검증** — `skills/`와 `codex/skills/`의 프로세스 뼈대가 어긋나지 않는지 확인한다 (Task 5).

각 태스크는 검증 통과 후 커밋한다.

---

### Task 1: SKILL.md — Setup 재구성 (재개 + 산출물 디렉토리)

**Files:**
- Modify: `skills/tdd-team/SKILL.md` (Setup 섹션, 현재 60–199행)

**Interfaces:**
- Produces: `.tdd-team/context.md`, `.tdd-team/session.md`, `{TASK_DIR}` 경로 규약. Task 2·3의 디스패치 블록이 이 경로들을 참조한다.
- Produces: `SKILL_DIR`, `TDD_DIR`(= `{PROJECT_ROOT}/.tdd-team`), `TASK_DIR`(= `{TDD_DIR}/task-{NN}`) 세 변수명.

- [ ] **Step 1: `## Setup` 바로 아래에 재개 단계를 신설한다**

`### 1. Resolve Skill Path` 바로 앞에 삽입:

```markdown
### 0. Resume or Start Fresh

Before anything else, check for `.tdd-team/session.md` in the project root.

If it exists, read it and ask:

> "이전 TDD 세션 기록이 있습니다: {완료}/{전체} 태스크 완료, 마지막 단계 {last_phase}. 이어서 진행할까요, 새로 시작할까요?"

- **이어서** → adopt `.tdd-team/context.md` and `.tdd-team/session.md` as-is. Skip Setup steps 2–6 entirely; they have already run. Resume from the first row whose `status` is not `DONE`, at the phase after its `last_phase`, and restore `feedback_mode`, `consecutive_needs_fix`, and `fix_rounds_this_cycle` from the file. Restoring those three counters is the point of resuming: starting them at zero re-runs a fix round the previous session already spent.
- **새로 시작** → rename the old directory to `.tdd-team.{YYYYMMDD-HHMMSS}` and run Setup normally. Never delete it — it is the previous session's debugging record.

If it does not exist, continue to step 1.
```

- [ ] **Step 2: Setup 1단계 제목과 본문에 산출물 디렉토리를 추가한다**

`### 1. Resolve Skill Path` 를 아래로 교체 (기존 `{SKILL_DIR}/references/…` 목록은 그대로 유지하고 뒤에 이어 붙인다):

```markdown
### 1. Resolve Skill Path and Artifact Directory

This SKILL.md was loaded from a known absolute path. Capture its parent directory as `SKILL_DIR`. Each phase agent's prompt file lives under `{SKILL_DIR}/references/` and is read directly by that phase's `Agent` call — there is no separate aggregate prompts file to load here.
```

그 다음 기존 6줄 목록을 유지하고, 목록 뒤에 추가:

```markdown
Then establish the artifact directory. Every file this session produces lives here, and every agent reads its inputs from here.

- `TDD_DIR` = `{PROJECT_ROOT}/.tdd-team`
- `TASK_DIR` = `{TDD_DIR}/task-{NN}` — `NN` is the task number, zero-padded to two digits

Create `TDD_DIR`, then exclude it from git tracking:

```bash
mkdir -p .tdd-team
git rev-parse --git-dir >/dev/null 2>&1 \
  && ! grep -qxF '.tdd-team/' "$(git rev-parse --git-dir)/info/exclude" 2>/dev/null \
  && echo '.tdd-team/' >> "$(git rev-parse --git-dir)/info/exclude"
```

Use `.git/info/exclude`, never `.gitignore` — `.gitignore` is a tracked file in the user's repository, and this skill does not author commits there.
```

- [ ] **Step 3: Setup 5단계를 "파일로 쓴다"로 바꾼다**

`### 5. Capture Project Context (once)` 의 제목과 첫 문단을 교체:

```markdown
### 5. Write the Session Context File

Before the first cycle, the **orchestrator** explores the feature area **one time** and writes `{TDD_DIR}/context.md`. Every phase agent reads this file instead of re-scanning the codebase, and instead of receiving the same blocks inline on every dispatch.

The file has four sections, in this order:
```

그 다음 파일 템플릿을 넣는다 (기존 `## Project Context` 블록의 8개 항목은 문구 그대로 재사용):

```markdown
```
# TDD Session Context

## Environment
- Project root: {PROJECT_ROOT}
- Source directory: {SOURCE_DIR}
- Test directory: {TEST_DIR}
- Scoped test command: {TEST_SCOPED_CMD}
- Test framework: {TEST_FRAMEWORK}

## Project Context (captured once — do NOT re-explore the codebase)
- Package / directory layout: {where the feature's source & test packages live}
- Test conventions: {JUnit version, assertion library/style, // arrange·act·assert, @Nested usage}
- Fixture pattern: {Fixture builder location & usage, repository.save helper pattern}
- Relevant existing types: {ClassName → key public method signatures} for classes this feature touches
- Domain anchors: {aggregate/entity files + invariants that apply here}
- In-scope files: {actual paths this session may modify — anything else is out of bounds}
- Out of scope: {what this task deliberately does not change}
- Known pitfalls — do NOT copy: {defect in existing code} → {what to do instead}

## Domain Invariants
{numbered list from step 3, IDs verbatim}

## Workspace Rules
Others may have edited this workspace since this file was written. Never revert a change you didn't make — it is someone else's work in progress.
Do not commit. The orchestrator and the user own the commit history.
```
```

이어서 기존 "Keep it compact …" 부터 "…rather than dropping the line, so a later reader can tell it was considered." 까지의 문단들을 **그대로 유지**한다. 마지막에 한 줄 추가:

```markdown
Never inline these sections into an agent prompt. Pass the path. The user may edit `context.md` between cycles, and an inlined copy would silently ignore their edit.
```

- [ ] **Step 4: Setup 6단계를 무조건 실행되는 세션 파일로 교체한다**

`### 6. Open a Session Ledger (4+ tasks only)` 섹션 전체(제목·본문·코드블록·마지막 두 문단)를 아래로 교체:

```markdown
### 6. Write the Session File

Write `{TDD_DIR}/session.md` before the first cycle — **always, regardless of task count.** Resume depends on this file, and resume must not be contingent on how large the session happens to be.

```
# TDD Session: {feature}
skill_dir: {SKILL_DIR}
test_command: {TEST_SCOPED_CMD}
feedback_mode: per-cycle | auto
consecutive_needs_fix: 0
fix_rounds_this_cycle: 0

| # | task | status | last_phase |
|---|------|--------|------------|
| 1 | {domain rule sentence} | PENDING | - |
| 2 | {domain rule sentence} | PENDING | - |
```

`status` is `PENDING` | `IN_PROGRESS` | `DONE`. `last_phase` records the last phase that returned `status: OK`, e.g. `GREEN` or `CYCLE_REVIEW:APPROVED`.

Update the row after every phase — one line edit, nothing else. Update `feedback_mode` when the user answers the cadence question, and the two counters whenever they change. An un-updated counter is the one failure mode that makes resume worse than starting over.

Then write one `{TASK_DIR}/task.md` per task:

```
# Task {NN}: {domain rule sentence}
invariants: {INV-001, INV-004}
test_class: {FQCN, or "미정 — RED가 결정"}
scenarios:
- {scenario sentence}
- {scenario sentence}
```
```

- [ ] **Step 5: 구조 검증**

```bash
cd /Users/finn/Desktop/private_study/devlife-plugins
grep -c '### 0. Resume or Start Fresh' skills/tdd-team/SKILL.md   # 기대: 1
grep -c 'git/info/exclude\|info/exclude' skills/tdd-team/SKILL.md # 기대: 2 이상
grep -c '4+ tasks only' skills/tdd-team/SKILL.md                  # 기대: 0
grep -c 'docs/tdd/session-' skills/tdd-team/SKILL.md              # 기대: 0
grep -c 'TASK_DIR' skills/tdd-team/SKILL.md                       # 기대: 3 이상
```

기대와 다르면 해당 단계로 돌아가 수정한다.

- [ ] **Step 6: 커밋**

```bash
git add skills/tdd-team/SKILL.md
git commit -m "feat: add .tdd-team artifact directory and session resume to tdd-team setup"
```

---

### Task 2: SKILL.md — TDD_STATUS envelope + 디스패치 패턴 + 게이트

**Files:**
- Modify: `skills/tdd-team/SKILL.md` (`### Agent Tool Call Pattern` ~ `### Result Block Gate`, 현재 208–275행)

**Interfaces:**
- Consumes: Task 1의 `TDD_DIR` / `TASK_DIR` / `context.md` / `task.md`.
- Produces: `TDD_STATUS` envelope 스펙과 RED/GREEN/REFACTOR 디스패치 템플릿. Task 3의 리뷰어·fix 디스패치와 Task 4의 reference 파일이 이 스펙을 참조한다.

- [ ] **Step 1: `### Agent Tool Call Pattern` 섹션 전체를 교체한다**

기존 "Each worker prompt must include:" 목록, ENVIRONMENT 블록, workspace 경고 블록을 모두 삭제하고 아래로 교체한다. (ENVIRONMENT와 경고문은 이제 `context.md`에 있다.)

```markdown
### Agent Tool Call Pattern

Every worker prompt carries **paths, not content**. It names the reference file to follow, the files to read, the file to write, and nothing else.

All three phases use one dispatch shape — only `{PHASE}`, the reference file, the prior-result line, and the result file differ:

```
Agent({
  subagent_type: "general-purpose",
  model: {per Model Selection},
  description: "{PHASE}: {task description}",
  prompt: """
Read {SKILL_DIR}/references/{PHASE_FILE} — you have permission to access this file.
Follow it exactly.

Read these before you start:
- {TDD_DIR}/context.md — environment, project context, domain invariants, workspace rules
- {TASK_DIR}/task.md — the task you are implementing
{PRIOR_RESULT_LINE}

Write your full result block to {TASK_DIR}/{RESULT_FILE}.
Return ONLY the TDD_STATUS envelope described in your reference file — no prose, no result block, no file contents.
"""
})
```

| PHASE | PHASE_FILE | PRIOR_RESULT_LINE | RESULT_FILE |
|-------|-----------|-------------------|-------------|
| RED | `red-agent.md` | *(omit the line)* | `red-result.md` |
| GREEN | `green-agent.md` | `- {TASK_DIR}/red-result.md — RED_RESULT from the RED phase` | `green-result.md` |
| REFACTOR | `refactor-agent.md` | `- {TASK_DIR}/green-result.md — GREEN_RESULT from the GREEN phase` | `refactor-result.md` |

Do not paste `context.md` or `task.md` contents into the prompt, and do not summarize them. The user may edit those files between phases; an inlined copy discards the edit.
```

- [ ] **Step 2: envelope 스펙 섹션을 새로 추가한다**

Step 1에서 교체한 블록 바로 뒤에 삽입:

```markdown
### The TDD_STATUS Envelope

Every phase returns exactly this, and nothing else. It is the only thing that enters the orchestrator's context.

```
TDD_STATUS
phase: RED | GREEN | REFACTOR | CYCLE_REVIEW | FIX | FINAL_REVIEW
status: OK | BLOCKED | ALREADY_PASSES
result_file: {path the agent wrote}
tests: {passed}/{failed}
verdict: APPROVED | NEEDS_FIX
findings: {Critical}/{Important}/{Minor}
note: {one line — only when status is BLOCKED}
```

Fields that don't apply to a phase are filled with `n/a`, never omitted — a blank and a missing field must stay distinguishable.

`status: ALREADY_PASSES` is RED-only and means *every* reported method already passes. If even one method is genuinely Red, RED returns `OK`.

The envelope is what drives every branch in this skill:

| Branch | Field |
|--------|-------|
| All methods `ALREADY_PASSES` → skip GREEN + REFACTOR | `status` |
| GREEN failed to make the test pass | `tests` |
| Reviewer verdict | `verdict` |
| Critical/Important go to a fix agent, Minor are logged | `findings` |
| Fix Round Budget, Circuit Breaker | `verdict`, counted in `session.md` |

Read the result file only when you need the detail the envelope does not carry — a `BLOCKED` diagnosis, or a gate failure. Routine cycles never open it.
```

- [ ] **Step 3: `### Result Block Gate` 섹션을 두 단계 검증으로 교체한다**

```markdown
### Result Block Gate

Validation happens in two places, because the envelope and the result file can fail independently.

**1. Envelope check** — it is the return value, so read it directly. Every field present, `result_file` non-empty, `status` one of the three literals.

**2. Result file check** — verify the file's required keys **without reading the file into context**:

```bash
f={TASK_DIR}/{RESULT_FILE}
miss=$(for k in {REQUIRED_KEYS}; do grep -q "^$k:" "$f" 2>/dev/null || echo "$k"; done | tr '\n' ',')
[ -z "$miss" ] && echo PASS || echo "MISSING:$miss"
```

| PHASE | REQUIRED_KEYS |
|-------|---------------|
| RED | `test_file test_method failure stubs` |
| GREEN | `files_modified tests_passed tests_failed failure_detail` |
| REFACTOR | `status reason tests_passed deferred` |
| FIX | `findings_addressed files_modified tests_passed tests_failed notes` |

If either check fails, **do not infer the value and do not proceed to the next phase** — re-dispatch that same agent with the same prompt plus one line naming what was missing. A guessed `RED_RESULT` sends GREEN after the wrong method, which costs a whole wasted cycle. Count the re-dispatch against the `BLOCKED` budget: one retry, then ask the user.

If the Agent tool is not available, say `not available`, then execute the same phase locally:
1. Read the relevant reference file for the phase.
2. Read `{TDD_DIR}/context.md` and `{TASK_DIR}/task.md`.
3. Follow that phase's workflow locally, using `Edit`/`Write` for file edits.
4. Write the result block to `{TASK_DIR}/{RESULT_FILE}` as an agent would.
```

- [ ] **Step 4: 구조 검증**

```bash
cd /Users/finn/Desktop/private_study/devlife-plugins
grep -c 'TDD_STATUS' skills/tdd-team/SKILL.md          # 기대: 4 이상
grep -c 'PRIOR_RESULT_LINE' skills/tdd-team/SKILL.md   # 기대: 2 이상
grep -c 'REQUIRED_KEYS' skills/tdd-team/SKILL.md       # 기대: 2 이상
grep -c 'PROJECT_CONTEXT block' skills/tdd-team/SKILL.md  # 기대: 0
grep -c '{ENVIRONMENT block}' skills/tdd-team/SKILL.md    # 기대: 0
```

`PROJECT_CONTEXT block` / `{ENVIRONMENT block}` 이 0이 아니면 Task 3에서 지울 디스패치 블록에 남아 있는 것이다. Task 3 완료 후 다시 확인한다.

- [ ] **Step 5: 커밋**

```bash
git add skills/tdd-team/SKILL.md
git commit -m "feat: replace inline agent prompts with TDD_STATUS envelope in tdd-team"
```

---

### Task 3: SKILL.md — 리뷰어·fix·final 디스패치 + diff 생성 + 카운터 영속

**Files:**
- Modify: `skills/tdd-team/SKILL.md` (`### Cycle Flow` ~ `## Session End`, 현재 276–446행)

**Interfaces:**
- Consumes: Task 2의 envelope 스펙과 디스패치 템플릿, Task 1의 `session.md` 카운터 필드.
- Produces: `{TASK_DIR}/diff.md`, `{TASK_DIR}/review.md`, `{TASK_DIR}/fix-result.md`, `{TDD_DIR}/final-review.md`.

- [ ] **Step 1: `### Cycle Flow` 에 파일 산출물과 세션 파일 갱신을 명시한다**

기존 1~4 번호 목록 뒤에 이어 붙인다:

```markdown
After every phase returns, update that task's row in `{TDD_DIR}/session.md` (`status`, `last_phase`) before dispatching the next phase. A crash between phases must leave the file telling the truth about where the session stopped.
```

- [ ] **Step 2: `### Cycle Reviewer Dispatch` 앞에 diff 생성 단계를 추가한다**

`### Cycle Reviewer Dispatch` 제목 바로 뒤, 기존 설명 문단 앞에 삽입:

```markdown
First build the cycle diff. Redirect it straight to a file — the diff must never pass through your context.

```bash
paths=$(grep -hE '^(test_file|stubs|files_modified):' {TASK_DIR}/*-result.md \
  | sed 's/^[a-z_]*: *//' | tr ',' '\n' | sed 's/^ *//; s/ *$//' \
  | grep -v -e '^none$' -e '^$' | sort -u)
git diff -- $paths > {TASK_DIR}/diff.md
wc -l < {TASK_DIR}/diff.md
```

Only the line count comes back to you; use it to confirm the diff is non-empty.

**Known limitation:** agents never commit, so a file already touched by an earlier cycle shows that cycle's changes here too. The reviewer is told to focus on the methods named in `red-result.md`, which bounds the noise. Committing per cycle would remove it, but that would change the "agents never commit" rule and is out of scope.
```

- [ ] **Step 3: 리뷰어 디스패치 블록을 교체한다**

기존 `Agent({ … cycle-reviewer.md … })` 블록 전체를 아래로 교체:

```
Agent({
  subagent_type: "general-purpose",
  model: {per Model Selection — omit},
  description: "CYCLE REVIEW: {task description}",
  prompt: """
Read {SKILL_DIR}/references/cycle-reviewer.md — you have permission to access this file.
Follow it exactly.

Read these before you start:
- {TDD_DIR}/context.md — environment, domain invariants, workspace rules
- {TASK_DIR}/task.md — the task under review
- {TASK_DIR}/diff.md — the cycle diff you are judging
- {TASK_DIR}/red-result.md — the test methods this cycle added; focus your review on these
- {TASK_DIR}/green-result.md — the test run already completed; do not re-run it

Write your full review report to {TASK_DIR}/review.md.
Return ONLY the TDD_STATUS envelope.
"""
})
```

기존 "**Handle reviewer verdict:**" 목록은 유지하되, 판단 근거를 envelope로 바꾼다:

```markdown
**Handle reviewer verdict** (read it from the envelope's `verdict` and `findings`, not from `review.md`):
- `APPROVED` → update `session.md`, reset `fix_rounds_this_cycle` to 0, set `consecutive_needs_fix` to 0, proceed to next task
- `NEEDS_FIX` with Critical or Important > 0 → dispatch a fix agent (see Fix Agent Dispatch), then re-run the cycle reviewer. Increment `fix_rounds_this_cycle` in `session.md` before each round.
- `NEEDS_FIX` with only Minor findings → log and continue; Minor never triggers a fix round
```

- [ ] **Step 4: Fix / Circuit Breaker 카운터를 파일에 기록하게 한다**

`### Fix Round Budget` 첫 문단 뒤에 한 줄 추가:

```markdown
The count lives in `{TDD_DIR}/session.md` as `fix_rounds_this_cycle`, not in your head — a resumed session must know a round was already spent.
```

`### Circuit Breaker` 첫 문단 뒤에 한 줄 추가:

```markdown
The count lives in `{TDD_DIR}/session.md` as `consecutive_needs_fix`. Increment it on every `NEEDS_FIX` verdict and reset it to 0 on every `APPROVED`.
```

- [ ] **Step 5: `### Feedback Cadence` 에 파일 편집 안내와 모드 기록을 추가한다**

기존 인용문을 아래로 교체:

> "1번 사이클이 끝났습니다. 남은 {N}개 사이클은 이어서 자동으로 진행할까요, 아니면 사이클마다 확인받을까요?
> (`.tdd-team/context.md`나 각 태스크의 `task.md`를 직접 수정하시면 다음 단계부터 반영됩니다.)"

그 뒤 "Record the answer" 문장을 교체:

```markdown
Record the answer in `{TDD_DIR}/session.md` as `feedback_mode` and follow it for the rest of the session. Two exceptions override `auto`:
```

- [ ] **Step 6: Fix Agent 디스패치 블록을 교체한다**

기존 `Agent({ … fix-agent.md … })` 블록 전체와 그 뒤 "Capture the returned `FIX_RESULT` block …" 문단을 아래로 교체:

```
Agent({
  subagent_type: "general-purpose",
  model: {per Model Selection — omit, or "haiku" only for a mechanical fix},
  description: "FIX: {short summary of findings}",
  prompt: """
Read {SKILL_DIR}/references/fix-agent.md — you have permission to access this file.
Follow it exactly.

Read these before you start:
- {TDD_DIR}/context.md — environment, project context, workspace rules
- {REVIEW_FILE} — the review report; fix ONLY its Critical and Important findings

Write your full result block to {TASK_DIR}/fix-result.md.
Return ONLY the TDD_STATUS envelope.
"""
})
```

`{REVIEW_FILE}` is `{TASK_DIR}/review.md` for a cycle fix and `{TDD_DIR}/final-review.md` for a final-review fix. The fix agent reads the findings itself — you never relay them.

The envelope's `tests` field is what you hand the reviewer on the re-run, so the reviewer has no reason to run the tests again.

- [ ] **Step 7: Final Review 디스패치 블록을 교체한다**

`## Final Review` 의 첫 두 문단은 유지한다(세션에서 건드린 테스트 클래스만 실행). 그 뒤 branch diff 생성을 추가하고 디스패치 블록을 교체:

```markdown
Build the branch diff into a file first, the same way the cycle diff is built:

```bash
git diff > {TDD_DIR}/branch-diff.md
wc -l < {TDD_DIR}/branch-diff.md
```

```
Agent({
  subagent_type: "general-purpose",
  model: "opus",
  description: "FINAL REVIEW",
  prompt: """
Read {SKILL_DIR}/references/final-reviewer.md — you have permission to access this file.
Follow it exactly.

Read these before you start:
- {TDD_DIR}/context.md — environment, domain invariants, workspace rules
- {TDD_DIR}/session.md — the confirmed task list and what was completed
- {TDD_DIR}/branch-diff.md — the full diff of this session
- {TASK_DIR}/red-result.md for each task — the tests that were added

Test run just completed by the orchestrator: {TEST_SCOPED_CMD invocation} → {N} passed, 0 failed

Write your full review report to {TDD_DIR}/final-review.md.
Return ONLY the TDD_STATUS envelope.
"""
})
```
```

- [ ] **Step 8: `## Session End` 요약에 산출물 경로를 추가한다**

기존 요약 블록 마지막 줄 뒤에 한 줄 추가:

```
Artifacts: .tdd-team/ (session.md, per-task results, reviews)
```

그리고 블록 뒤에 한 문단 추가:

```markdown
Leave `.tdd-team/` in place. It is the session's debugging record and the input to a later resume; it is excluded from git tracking, so it costs the user nothing to keep.
```

- [ ] **Step 9: 구조 검증**

```bash
cd /Users/finn/Desktop/private_study/devlife-plugins
grep -c 'PROJECT_CONTEXT block' skills/tdd-team/SKILL.md   # 기대: 0
grep -c '{ENVIRONMENT block}' skills/tdd-team/SKILL.md     # 기대: 0
grep -c 'workspace warning line' skills/tdd-team/SKILL.md  # 기대: 0
grep -c 'diff.md' skills/tdd-team/SKILL.md                 # 기대: 3 이상
grep -c 'fix_rounds_this_cycle' skills/tdd-team/SKILL.md   # 기대: 3 이상
grep -c 'consecutive_needs_fix' skills/tdd-team/SKILL.md   # 기대: 3 이상
grep -c 'Return ONLY the TDD_STATUS envelope' skills/tdd-team/SKILL.md  # 기대: 4
```

- [ ] **Step 10: 커밋**

```bash
git add skills/tdd-team/SKILL.md
git commit -m "feat: route reviewer and fix agent communication through .tdd-team files"
```

---

### Task 4: references 6개 — 입출력 규약 전환

**Files:**
- Modify: `skills/tdd-team/references/red-agent.md`
- Modify: `skills/tdd-team/references/green-agent.md`
- Modify: `skills/tdd-team/references/refactor-agent.md`
- Modify: `skills/tdd-team/references/fix-agent.md`
- Modify: `skills/tdd-team/references/cycle-reviewer.md`
- Modify: `skills/tdd-team/references/final-reviewer.md`

**Interfaces:**
- Consumes: Task 2의 `TDD_STATUS` envelope 스펙.
- Produces: 각 에이전트가 실제로 지키는 입출력 규약. 이 태스크가 끝나야 SKILL.md의 디스패치가 성립한다.

기존 역할 지시(Iron Law, Anti-Rationalization, Skip Condition, Read Scope, Severity 기준 등)는 **한 글자도 바꾸지 않는다.** 입력을 어디서 읽는지와 결과를 어디에 쓰는지만 바꾼다.

- [ ] **Step 1: 6개 파일 모두에 공통 Input 섹션을 넣는다**

각 파일의 `Role:`/제목 직후, 첫 `##` 섹션 앞에 삽입:

```markdown
## Input

Your prompt gives you file paths, not content. Read them before you start:

- `.tdd-team/context.md` — environment (including the scoped test command), project context, domain invariants, workspace rules
- the task or review file named in your prompt
- any prior-phase result file named in your prompt

Do not re-scan the codebase for anything `context.md` already answers. Read these files at the start of your run — they may have been edited since the previous phase.
```

- [ ] **Step 2: "Environment block" / "PROJECT_CONTEXT block" 참조를 파일 참조로 바꾼다**

아래 문자열을 전 파일에서 치환한다.

| 기존 | 변경 |
|---|---|
| `the scoped test command from your prompt's Environment block` | `the scoped test command from `.tdd-team/context.md`` |
| `Use the `PROJECT_CONTEXT` block for structural context` | `Use the Project Context section of `.tdd-team/context.md` for structural context` |
| `use the `PROJECT_CONTEXT` block for conventions and fixture patterns` | `use the Project Context section of `.tdd-team/context.md` for conventions and fixture patterns` |
| `Fall back to reading more only if `PROJECT_CONTEXT` is missing something you need.` | `Fall back to reading more only if `context.md` is missing something you need.` |

- [ ] **Step 3: red-agent.md 출력 규약을 바꾼다**

마지막 `5. Report results using EXACTLY this format — no additional explanation:` 문장과 그 뒤 `RED_RESULT` 블록을 아래로 교체:

````markdown
5. Write this block to the result file named in your prompt — exactly this format, no additional explanation:

```
RED_RESULT
test_file: {relative path to test file}
test_method: {class#methodA} | {class#methodB, class#methodC, ...} (one per line if batched)
failure: {one-line failure message, or "ALREADY_PASSES"} (one per test_method, in the same order)
stubs: {comma-separated relative paths, or "none"}
```

6. Return ONLY this envelope as your response — no prose, no result block, no file contents:

```
TDD_STATUS
phase: RED
status: OK | BLOCKED | ALREADY_PASSES
result_file: {the path you wrote}
tests: n/a
verdict: n/a
findings: n/a
note: {one line — only when status is BLOCKED}
```

`status: ALREADY_PASSES` only when **every** method you reported already passes. If even one is genuinely Red, return `OK`.
````

- [ ] **Step 4: green-agent.md 출력 규약을 바꾼다**

`GREEN_RESULT` 블록을 result 파일로 옮기고 envelope를 추가한다. Step 3과 같은 구조로, envelope 값은:

```
TDD_STATUS
phase: GREEN
status: OK | BLOCKED
result_file: {the path you wrote}
tests: {tests_passed}/{tests_failed}
verdict: n/a
findings: n/a
note: {one line — only when status is BLOCKED}
```

- [ ] **Step 5: refactor-agent.md 출력 규약을 바꾼다**

`REFACTOR_RESULT` 블록을 result 파일로 옮기고 envelope를 추가한다. envelope 값은:

```
TDD_STATUS
phase: REFACTOR
status: OK | BLOCKED
result_file: {the path you wrote}
tests: {tests_passed}/0
verdict: n/a
findings: n/a
note: {one line — only when status is BLOCKED}
```

`SKIPPED` is reported in the result file's `status` field, not in the envelope — the envelope's `status` is about whether your run succeeded, not whether you changed code.

- [ ] **Step 6: fix-agent.md 입출력 규약을 바꾼다**

Workflow 1번을 교체:

```markdown
1. Read the review file named in your prompt and take ONLY its Critical and Important findings. Ignore Minor. Each finding names a file, a behavior, and what must change.
```

`FIX_RESULT` 블록을 result 파일로 옮기고 envelope를 추가한다. envelope 값은:

```
TDD_STATUS
phase: FIX
status: OK | BLOCKED
result_file: {the path you wrote}
tests: {tests_passed}/{tests_failed}
verdict: n/a
findings: n/a
note: {one line — only when status is BLOCKED}
```

- [ ] **Step 7: cycle-reviewer.md 입출력 규약을 바꾼다**

`**Inputs:** task description, domain invariants, diff (test + implementation code)` 를 교체:

```markdown
**Inputs (all as file paths in your prompt):** `context.md` (domain invariants), `task.md`, `diff.md`, `red-result.md` (the methods this cycle added — focus here), `green-result.md` (the test run already completed)
```

`## Read Scope — What You Are Allowed to Open` 의 첫 문장을 교체:

```markdown
Judge `diff.md` against the invariants in `context.md`. That is the whole input. A file already touched by an earlier cycle may show that cycle's changes in the diff too — judge the methods named in `red-result.md`.
```

리포트 템플릿 끝(`### Summary` 블록 뒤)에 추가:

````markdown
---

## Output

Write the report above to the review file named in your prompt. Then return ONLY this envelope as your response — no prose, no report, no file contents:

```
TDD_STATUS
phase: CYCLE_REVIEW
status: OK | BLOCKED
result_file: {the path you wrote}
tests: n/a
verdict: APPROVED | NEEDS_FIX
findings: {Critical}/{Important}/{Minor}
note: {one line — only when status is BLOCKED}
```

`findings` counts must match the report. `APPROVED` requires `0/0/{any}`.
````

- [ ] **Step 8: final-reviewer.md 입출력 규약을 바꾼다**

`**Inputs:** …` 줄을 교체:

```markdown
**Inputs (all as file paths in your prompt):** `context.md` (domain invariants), `session.md` (the confirmed task list), `branch-diff.md` (the full session diff), each task's `red-result.md`, plus the test result the orchestrator reports inline in your prompt
```

Step 7과 같은 `## Output` 섹션을 파일 끝에 추가하되 `phase: FINAL_REVIEW` 로 한다.

- [ ] **Step 9: 구조 검증**

```bash
cd /Users/finn/Desktop/private_study/devlife-plugins/skills/tdd-team/references
grep -l 'PROJECT_CONTEXT' *.md          # 기대: 출력 없음
grep -l "prompt's Environment block" *.md  # 기대: 출력 없음
grep -c 'TDD_STATUS' *.md               # 기대: 각 파일 1 이상
grep -c '## Input' *.md                 # 기대: 각 파일 1
grep -h '^phase:' *.md | sort           # 기대: 6줄 — CYCLE_REVIEW / FINAL_REVIEW / FIX / GREEN / REFACTOR / RED 각 1회
grep -c 'Return ONLY this envelope' *.md  # 기대: 각 파일 1
```

- [ ] **Step 10: 커밋**

```bash
cd /Users/finn/Desktop/private_study/devlife-plugins
git add skills/tdd-team/references
git commit -m "feat: switch tdd-team agent references to file-based input and output"
```

---

### Task 5: codex 사본 동기화

**Files:**
- Modify: `codex/skills/tdd-team/SKILL.md`
- Modify: `codex/skills/tdd-team/references/*.md` (6개)

**Interfaces:**
- Consumes: Task 1–4의 최종 `skills/tdd-team/` 내용.
- Produces: 프로세스 뼈대가 동일하고 에이전트 호출 문법만 다른 Codex 버전.

- [ ] **Step 1: 현재 두 버전의 차이를 먼저 확인한다**

커밋 `11fd7d4`(설계 문서 커밋)은 스킬 변경이 시작되기 직전 상태다. 이걸 기준으로 원래 두 버전이 어떻게 갈라져 있었는지 본다.

```bash
cd /Users/finn/Desktop/private_study/devlife-plugins
diff <(git show 11fd7d4:skills/tdd-team/SKILL.md) \
     <(git show 11fd7d4:codex/skills/tdd-team/SKILL.md) > /tmp/codex-divergence.diff
wc -l < /tmp/codex-divergence.diff
grep -n '^[<>]' /tmp/codex-divergence.diff | head -40
```

Codex 버전이 Claude 버전과 **어디서 어떻게 갈라져 있었는지**(에이전트 호출 문법, 툴 이름)를 먼저 파악한다. 그 차이를 유지한 채로 이번 변경을 이식한다. 통째로 복사하면 안 된다 — `skills/`에는 Codex 전용 문구가 없고, `codex/skills/`에는 Claude 전용 문법이 없어야 한다.

- [ ] **Step 2: references 6개를 이식한다**

references는 에이전트 호출 문법을 포함하지 않으므로 Task 4의 변경이 그대로 적용된다. 단, Codex 버전에만 있는 문구(`tool_search` 등)가 있으면 보존한다.

```bash
cd /Users/finn/Desktop/private_study/devlife-plugins
for f in red-agent green-agent refactor-agent fix-agent cycle-reviewer final-reviewer; do
  diff skills/tdd-team/references/$f.md codex/skills/tdd-team/references/$f.md
done
```

차이가 없던 파일은 복사한다. 차이가 있던 파일은 Task 4의 변경만 수동 이식한다.

- [ ] **Step 3: SKILL.md를 이식한다**

아래 항목을 하나씩 이식한다. Step 1에서 확인한 Codex 쪽 고유 문구는 보존하고, 디스패치 블록만 Codex 문법으로 바꾼다. 파일 경로 규약(`.tdd-team/`, `TDD_STATUS` envelope, `session.md` 필드명)은 Claude 버전과 **글자 단위로 동일**해야 한다 — 두 버전이 같은 `.tdd-team/`을 읽고 쓰기 때문이다.

- [ ] `### 0. Resume or Start Fresh` 섹션 신설
- [ ] `### 1.` 제목을 `Resolve Skill Path and Artifact Directory`로 바꾸고 `TDD_DIR`/`TASK_DIR`/`.git/info/exclude` 블록 추가
- [ ] `### 5.` → `Write the Session Context File` + `context.md` 템플릿
- [ ] `### 6.` → `Write the Session File` + `session.md`/`task.md` 템플릿 (4+ 조건 삭제)
- [ ] `### Agent Tool Call Pattern` 교체 (경로만 전달하는 디스패치 + PHASE 표)
- [ ] `### The TDD_STATUS Envelope` 섹션 신설
- [ ] `### Result Block Gate` 2단계 검증으로 교체 (REQUIRED_KEYS 표 포함)
- [ ] `### Cycle Flow` 에 session.md 갱신 문단 추가
- [ ] `### Cycle Reviewer Dispatch` 에 diff 생성 블록 + 디스패치 교체 + verdict 처리 교체
- [ ] `### Fix Round Budget` / `### Circuit Breaker` 카운터 영속 문장 추가
- [ ] `### Feedback Cadence` 인용문·기록 문장 교체
- [ ] `### Fix Agent Dispatch` 디스패치 교체 (`{REVIEW_FILE}` 규약 포함)
- [ ] `## Final Review` branch-diff 생성 + 디스패치 교체
- [ ] `## Session End` 산출물 경로 + 보존 문단 추가

- [ ] **Step 4: 구조 검증**

```bash
cd /Users/finn/Desktop/private_study/devlife-plugins
# 플랫폼 분리: Claude 쪽에 Codex 전용 문구가 없어야 한다
grep -ric 'codex\|tool_search' skills/tdd-team/    # 기대: 모두 0

# 뼈대 일치: 양쪽의 파일 규약이 같아야 한다
for k in TDD_STATUS .tdd-team/ session.md fix_rounds_this_cycle consecutive_needs_fix diff.md; do
  printf '%-28s claude=%s codex=%s\n' "$k" \
    "$(grep -rc "$k" skills/tdd-team/ | awk -F: '{s+=$2} END {print s}')" \
    "$(grep -rc "$k" codex/skills/tdd-team/ | awk -F: '{s+=$2} END {print s}')"
done
```

두 열의 값이 크게 벌어지면 이식 누락이다.

- [ ] **Step 5: 커밋**

```bash
git add codex/skills/tdd-team
git commit -m "feat: sync tdd-team file-based messaging to codex skill copy"
```

---

### Task 6: 문서·버전·CHANGELOG

**Files:**
- Modify: `docs/tdd-team.md`
- Modify: `README.md` (43행 `tdd-team` 행)
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 1–5의 최종 동작.

- [ ] **Step 1: `docs/tdd-team.md`의 실행 흐름을 갱신한다**

`## 실행 흐름` 섹션에 다음을 반영한다. 문서는 한국어를 유지한다.

- Setup 0단계(재개 여부 확인)
- `.tdd-team/` 산출물 구조 — `context.md`, `session.md`, `task-NN/`, `final-review.md`
- 에이전트는 파일을 읽고 결과를 파일에 쓰며, 반환값은 STATUS 봉투(`TDD_STATUS`) 한 장
- 사이클 중간에 `context.md` / `task.md`를 직접 수정하면 다음 단계부터 반영된다는 점
- `.git/info/exclude`로 추적 제외된다는 점

- [ ] **Step 2: README 버전을 올린다**

43행 `| `tdd-team` | `1.10.0` | …` 의 버전을 `2.0.0`으로 바꾸고, Description 끝에 다음을 덧붙인다:

```
, 에이전트 통신을 `.tdd-team/` md 파일로 전환(컨텍스트·태스크·단계 결과·리뷰를 파일로 주고받고 반환값은 TDD_STATUS 봉투만), 세션 재개 지원(태스크 수 무관하게 session.md 기록, fix/서킷 카운터 포함), 사이클 중 context.md·task.md 직접 수정 가능
```

`## Plugins` 상단 요약 테이블에 `tdd-team` 버전이 있으면 함께 갱신한다.

```bash
grep -n 'tdd-team' README.md
```

- [ ] **Step 3: CHANGELOG에 기록한다**

`CHANGELOG.md` 최상단 형식을 확인한 뒤(`head -20 CHANGELOG.md`) 같은 형식으로 추가한다. 요약만 적는다:

```markdown
## 2026-09-11

- `tdd-team` `2.0.0` — 에이전트 통신을 프롬프트 인라인에서 `.tdd-team/` md 파일 경유로 전환. 반환값은 `TDD_STATUS` 봉투만, 결과 전문은 파일. 세션 재개(`session.md`에 fix/서킷 카운터 포함), 사이클 중 `context.md`·`task.md` 직접 수정, 사이클별 산출물 보존 추가. 오케스트레이터 계약 변경으로 진행 중이던 기존 세션과는 호환되지 않음.
```

- [ ] **Step 4: 검증**

```bash
cd /Users/finn/Desktop/private_study/devlife-plugins
grep -n '2.0.0' README.md            # 기대: tdd-team 행에 존재
grep -c 'tdd-team' CHANGELOG.md      # 기대: 1 이상
grep -c '.tdd-team/' docs/tdd-team.md  # 기대: 3 이상
```

- [ ] **Step 5: 커밋**

```bash
git add docs/tdd-team.md README.md CHANGELOG.md
git commit -m "docs: bump tdd-team to 2.0.0 for file-based agent messaging"
```
