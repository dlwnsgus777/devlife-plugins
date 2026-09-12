---
name: tdd-team
description: >
  Use this skill when the user wants to develop features using Test-Driven Development
  with an agentic Red-Green-Refactor cycle. Trigger on "start TDD", "do TDD",
  "TDD로 개발해줘", "TDD로 구현해줘", "TDD로 만들어줘", "TDD 시작", "TDD 팀 만들어",
  "테스트 주도 개발", "red green refactor", "test-driven development",
  "테스트 먼저 작성하고 싶어", "write tests first then implement",
  "테스트부터 짜줘", "TDD 방식으로 구현해줘".
  Also trigger when a user describes a feature and says they want it built incrementally
  with tests, e.g. "이 기능 테스트 먼저 만들고 하나씩 구현하자", "build this with
  failing tests first", or "한 단계씩 테스트 작성하면서 개발하고 싶어".
  Do NOT trigger for simply writing unit tests after implementation, running existing
  tests, or debugging test failures — those are not TDD workflows.
---

# TDD Team

Orchestrate a 3-phase Red-Green-Refactor TDD cycle using sequential Agent calls. Each cycle implements one small behavior increment.

## Execution Rules

- Respect system, developer, and project `CLAUDE.md` instructions above this skill.
- If project instructions require feedback after each stage, pause after RED, GREEN, REFACTOR, and review stages and ask for feedback before continuing.
- Use sub-agents (`Agent({ subagent_type: "general-purpose", ... })`) for RED, GREEN, REFACTOR, cycle review, and final review. If the Agent tool is not available, say `not available` and fall back to local execution.

## Right-Size the Ceremony

**Never cut RED/GREEN isolation, regardless of change size.** It is structural, not risk-based: one mind writing both the test and the implementation gravitates to happy-path-only coverage, because the test ends up describing what you already intended to build instead of pressure-testing the requirement. A tiny change is as vulnerable to that as a large one. RED always runs blind to how GREEN will implement it, and GREEN always runs as a separate dispatch, on every cycle.

What scales down with change size is everything *around* that isolation:
- **Cycle granularity** — batch scenarios that share one implementation change into a single task (Step 4).
- **REFACTOR** — skips itself when GREEN's output is clean.
- **CYCLE REVIEWER depth** — static reasoning by default; live experiments only for `ALREADY_PASSES` (see cycle-reviewer.md).
- **Final Review scope** — touched classes only unless the change has wide blast radius. Both reviewers are handed the test result the orchestrator (or GREEN/fix agent) already produced; they read and reason rather than re-running it.

## Model Selection

Every `Agent()` call takes a `model` field. Omitting it inherits the session default — **omit unless the table gives a concrete reason to override.** Don't downgrade reflexively: **turn count beats token price**, since an undersized model burns the savings on re-reads and retries.

| Role | Default | When to override |
|------|---------|-------------------|
| RED | omit | Designing a failing test from a domain-rule sentence is judgment, not transcription. |
| GREEN | omit | `model: "haiku"` only when genuinely narrow — one small method, shape already spelled out, nothing to design. |
| REFACTOR | omit | Skips itself on clean output; the runs that happen need real judgment. |
| CYCLE REVIEWER | omit | The check that catches vacuous tests and invariant gaps. Don't cheapen it. |
| FIX agent | omit; `haiku` for a mechanical fix | Cheap tier is enough for a rename, a one-line guard, a reference swap. A fix that re-derives *why*, or touches more than the named lines, stays at the default. |
| FINAL REVIEWER | **`model: "opus"`** | Last gate on the whole session — dispatch on the most capable model available. |

### Handling `BLOCKED`

1. Dispatched at a downgraded tier → re-dispatch the same call at the default tier.
2. `BLOCKED` at the default tier → re-dispatch **once** with reduced context: write a trimmed copy of the Project Context section — just the target package and the one or two signatures the agent needs — and point the retry's prompt at that file instead of the full `context.md`.
3. Still `BLOCKED` → stop dispatching and ask the user:

> "{역할} 에이전트가 '{사유}'로 막혔습니다. 이 태스크를 로컬에서 직접 진행할까요, 아니면 건너뛰고 다음 태스크로 갈까요?"

Never spend a third dispatch on the same call.

## Setup

### 0. Resume or Start Fresh

Before anything else, check for `.tdd-team/session.md` in the project root.

If it exists, read it and ask:

> "이전 TDD 세션 기록이 있습니다: {완료}/{전체} 태스크 완료, 마지막 단계 {last_phase}. 이어서 진행할까요, 새로 시작할까요?"

- **이어서** → adopt `.tdd-team/context.md` and `.tdd-team/session.md` as-is. Skip Setup steps 2–6 entirely; they have already run. Resume from the first row whose `status` is not `DONE`, at the phase after its `last_phase`, and restore `feedback_mode`, `consecutive_needs_fix`, and `fix_rounds_this_cycle` from the file. Restoring those three counters is the point of resuming: starting them at zero re-runs a fix round the previous session already spent.
- **새로 시작** → rename the old directory to `.tdd-team.{YYYYMMDD-HHMMSS}` and run Setup normally. Never delete it — it is the previous session's debugging record.

If it does not exist, continue to step 1.

### 1. Resolve Skill Path and Artifact Directory

This SKILL.md was loaded from a known absolute path. Capture its parent directory as `SKILL_DIR`. Each phase agent's prompt file lives under `{SKILL_DIR}/references/` and is read directly by that phase's `Agent` call — there is no separate aggregate prompts file to load here.

```
{SKILL_DIR}/references/red-agent.md
{SKILL_DIR}/references/green-agent.md
{SKILL_DIR}/references/refactor-agent.md
{SKILL_DIR}/references/cycle-reviewer.md
{SKILL_DIR}/references/final-reviewer.md
{SKILL_DIR}/references/fix-agent.md
```

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

### 2. Detect Environment

Check for build files (`build.gradle.kts`, `pom.xml`, `package.json`, etc.) and determine the test command. Capture:

```
PROJECT_ROOT / SOURCE_DIR / TEST_DIR / TEST_CMD / TEST_SCOPED_CMD / TEST_FRAMEWORK
```

- **TEST_CMD** — full-suite command. Not run by default (see Final Review) — only run it if the user explicitly asks for full-suite/cross-class regression coverage.
- **TEST_SCOPED_CMD** — command template that runs a **single test class**, used by every in-cycle test run and by Final Review. Gradle: `./gradlew test --tests "{FQCN}" --offline` (JUnit `@Nested` classes run with the enclosing class FQCN). Maven: `mvn -o test -Dtest={ClassName}`. npm/jest/vitest: pass the test file path (e.g. `npx vitest run {test_file}`). Most frameworks accept multiple `--tests`/file-path arguments in one invocation — use that to run several touched classes together instead of one command per class.

### 3. Identify Domain Invariants

**Source: the requirements document first, code second.** Spec, plan, ticket, or plain description — treat them all the same way.

1. Document provided → derive invariants exclusively from it; do NOT scan code yet. If it states its invariants explicitly, adopt them as written — **including their IDs** (`INV-001`, …) if it assigns any. Reuse those IDs verbatim through the whole session; they are how the final reviewer checks coverage without re-reading the plan.
2. Nothing provided → ask "구현할 기능의 요구사항이나 티켓 내용을 공유해주시겠어요?" and wait.
3. Only then scan code (enum transitions, validation annotations, guard clauses) for structural constraints the document omitted. Never let code override the document's intent.

Express each rule as a declarative sentence about **what should be true**, not what the code does:

> "결제 완료 상태로 전환된 주문의 금액은 어떠한 경우에도 변경될 수 없다."

Present the extracted invariants in this exact table format, then ask if anything is missing:

```
도메인 불변성 (비즈니스 규칙)

  ┌─────┬─────────────────────────────────────────────────────────────────────────────────┐
  │  #  │                                     불변성                                      │
  ├─────┼─────────────────────────────────────────────────────────────────────────────────┤
  │ 1   │ {invariant sentence}                                                            │
  ├─────┼─────────────────────────────────────────────────────────────────────────────────┤
  │ 2   │ {invariant sentence}                                                            │
  └─────┴─────────────────────────────────────────────────────────────────────────────────┘
```

These sentences become the source of test names.

### 4. Decompose into TDD Tasks

If the document already provides an ordered task list, adopt it instead of deriving a new one. Items tagged `[REGRESSION]` (an existing test already covers that behavior) are not cycles — list them once as "기존 커버리지로 확인" and run them as part of Final Review instead of giving each its own RED. Only `[NEW]` items become cycles. Apply the coverage floor and batching rule below before presenting the list — a document often lists scenarios one-per-line for readability, which is a documentation granularity, not a cycle granularity.

Name each task as a **domain rule sentence** — it becomes the test's `@DisplayName` directly.

**Coverage floor — a floor, never a cap.** Every invariant from Setup step 3 needs enough tests to pin its **boundary**, not one test somewhere inside it. An invariant is a rule; a single test only samples one point of a rule and proves nothing about where it starts and stops. For each invariant, the floor is:

- the case that **violates** it (the rule fires), and
- the nearest case that **satisfies** it (the rule does not fire), and
- every additional state or input the rule itself names — if it says "결제 완료 상태에서는", then 결제 대기 and 부분 환불 are boundaries the rule drew, not extras someone added.

Plus one happy-path test per class this feature touches, even where no invariant maps to it.

Under TDD this is not a coverage preference. **An edge case with no test is not an unverified behavior — it is an unbuilt one**, because GREEN implements exactly what the tests demand and nothing more. Under-listing tests here silently under-builds the feature.

Go above the floor whenever the domain gives a reason. The only scenarios to drop are ones that test the language, the framework, or a plain accessor — never a boundary of a domain rule. When you drop something, say which and why as you present the list.

**This does not cost cycles.** A rule's boundary cases share the same guard clause, so they belong to one task, not several — the batching rule below is what controls cost, and RED will express same-rule-different-input cases as a single `@ParameterizedTest`. More test methods in a cycle is nearly free; more cycles is what is expensive.

```
# Bad: add(1, 2) returns 3
# Good: 두 정수를 더하면 합계를 반환한다
```

**Batch scenarios that share one implementation change.** A cycle should map to a unit of *implementation work*, not to a single test method. Before finalizing the task list, look for groups of scenarios that will all be satisfied by the same guard clause, the same conditional, or the same small function — e.g. the positive and negative branches of one check, or a family of role/state permutations against one lookup. Merge each such group into a single task with multiple `@DisplayName`s under it, rather than one task per scenario.

> Signal you merged too coarsely: GREEN can't make all of a task's test methods pass with one small change — split it back apart.
> Signal you split too finely: cycle N's RED comes back `ALREADY_PASSES` because cycle N-1's GREEN already covered it — merge it into whichever earlier task actually implements the shared logic, going forward.

Present the task list in this format, then get user confirmation before starting:

```
TDD 태스크 목록

  ┌─────┬─────────────────────────────────────────────────────────────────────────────────┐
  │  #  │                                    태스크                                       │
  ├─────┼─────────────────────────────────────────────────────────────────────────────────┤
  │ 1   │ {domain rule sentence → @DisplayName} (+ {domain rule sentence → @DisplayName} if batched) │
  ├─────┼─────────────────────────────────────────────────────────────────────────────────┤
  │ 2   │ {domain rule sentence → @DisplayName}                                           │
  └─────┴─────────────────────────────────────────────────────────────────────────────────┘
```

### 5. Write the Session Context File

Before the first cycle, the **orchestrator** explores the feature area **one time** and writes `{TDD_DIR}/context.md`. Every phase agent reads this file instead of re-scanning the codebase, and instead of receiving the same blocks inline on every dispatch.

The file has four sections, in this order:

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

Keep it compact (signatures and paths, not full file bodies). If the feature is brand-new with no nearby code, state "관련 기존 코드 없음" and list only the target package.

**The last three lines are boundaries, not background.** Every phase agent runs in its own context and infers conventions from whatever code it reads, which is exactly how a known defect gets reproduced and how an edit lands in a file nobody meant to touch. Source them from the plan document — 「구현 대상 파일」, 「목표가 아닌 것」, and 「기존 코드의 함정」 respectively. If the plan has no pitfall section, spend one pass on the reference implementation the feature imitates before the first cycle; a defect found in cycle 3 has already been copied twice.

A pitfall entry without its `→ what to do instead` half is worse than omitting it — the agent knows to avoid something and invents its own replacement. If a section has nothing, write `해당 없음` rather than dropping the line, so a later reader can tell it was considered.

Never inline these sections into an agent prompt. Pass the path. The user may edit `context.md` between cycles, and an inlined copy would silently ignore their edit.

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

## TDD Cycle Execution

> **BLOCKING REQUIREMENT — TDD ORDER**: Do not write production implementation before a failing test has been written and verified.
>
> **BLOCKING REQUIREMENT — ORCHESTRATOR ONLY**: You are the orchestrator. After user confirmation, you MUST use the `Agent` tool for every RED / GREEN / REFACTOR step. Do NOT call `Edit` or `Write` on source or test files yourself. If you find yourself about to edit a file directly — stop and spawn an Agent instead.

For each task, call the `Agent` tool three times sequentially (RED → GREEN → REFACTOR). Each agent reads its own reference file plus `{TDD_DIR}/context.md` and `{TASK_DIR}/task.md` — the prompt carries paths, not content, so the agent does not re-scan the codebase.

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

### Cycle Flow

1. **RED** → capture test file path, method name(s), failure message(s) — a batched task reports one line per scenario
   - Every reported method is `ALREADY_PASSES` → skip GREEN + REFACTOR, proceed to next task (still run CYCLE REVIEWER — it's the only check that the new tests are real coverage, not vacuous)
   - At least one method is genuinely Red → proceed to GREEN as usual; GREEN targets the Red ones, the `ALREADY_PASSES` ones just ride along as already-passing coverage
   - Build fails → RED handles internally (fix stubs, re-verify)
2. **GREEN** → capture files modified, all test results
3. **REFACTOR** — skip if GREEN output is already clean
4. **CYCLE REVIEWER** → dispatch independent subagent (see below)

After every phase returns, update that task's row in `{TDD_DIR}/session.md` (`status`, `last_phase`) before dispatching the next phase. A crash between phases must leave the file telling the truth about where the session stopped.

### Cycle Reviewer Dispatch

First build the cycle diff. Redirect it straight to a file — the diff must never pass through your context.

```bash
paths=$(grep -hE '^(test_file|stubs|files_modified):' {TASK_DIR}/*-result.md \
  | sed 's/^[a-z_]*: *//' | tr ',' '\n' | sed 's/^ *//; s/ *$//' \
  | grep -v -e '^none$' -e '^$' | sort -u)
git diff -- $paths > {TASK_DIR}/diff.md
for f in $paths; do
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 || git diff --no-index /dev/null "$f" >> {TASK_DIR}/diff.md
done
wc -l < {TASK_DIR}/diff.md
```

The `for` loop appends the files that are new this cycle — RED's test class and stubs are untracked, and plain `git diff` reports nothing for them, so without it the reviewer would be handed a diff with the test missing. `git diff --no-index` exits non-zero whenever it finds differences; here that is the normal outcome, not a command failure to react to.

Only the line count comes back to you; use it to confirm the diff is non-empty. A count of zero means nothing changed at all — outside an `ALREADY_PASSES` cycle that is a defect worth stopping for, not a reviewable state, so stop and ask rather than dispatching the reviewer.

**Known limitation:** agents never commit, so a file already touched by an earlier cycle shows that cycle's changes here too. The reviewer is told to focus on the methods named in `red-result.md`, which bounds the noise. Committing per cycle would remove it, but that would change the "agents never commit" rule and is out of scope.

After REFACTOR completes, dispatch an independent reviewer subagent, **passing it GREEN's (or the fix agent's) reported test result** so it has no reason to re-run what was just run and reported. If the Agent tool is not available, say `not available`, then apply `references/cycle-reviewer.md` locally to the cycle diff.

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
- On a re-review after a fix round, read {TASK_DIR}/fix-result.md instead of green-result.md — it holds the current test run; do not re-run it
- If RED reported `ALREADY_PASSES` for every method, there is no green-result.md — rely on red-result.md, which already records that every method passes

Write your full review report to {TASK_DIR}/review.md.
Return ONLY the TDD_STATUS envelope.
"""
})
```

**Handle reviewer verdict** (read it from the envelope's `verdict` and `findings`, not from `review.md`):
- `APPROVED` → update `session.md`, reset `fix_rounds_this_cycle` to 0, set `consecutive_needs_fix` to 0, proceed to next task
- `NEEDS_FIX` with Critical or Important > 0 → dispatch a fix agent (see Fix Agent Dispatch), then re-run the cycle reviewer. Increment `fix_rounds_this_cycle` in `session.md` before each round.
- `NEEDS_FIX` with only Minor findings → log and continue; Minor never triggers a fix round

### Fix Round Budget

**Maximum 2 fix rounds per cycle.** A round is one fix-agent dispatch plus one reviewer re-run.

The count lives in `{TDD_DIR}/session.md` as `fix_rounds_this_cycle`, not in your head — a resumed session must know a round was already spent.

If the reviewer still returns `NEEDS_FIX` after the second round, stop the loop and hand the decision to the user rather than dispatching a third:

> "{태스크}에서 리뷰어가 2회 수정 후에도 지적을 남겼습니다: {미해결 findings}. 이대로 두고 다음 태스크로 갈까요, 직접 손보실까요, 아니면 이 태스크를 다시 설계할까요?"

A third round almost never resolves what two could not — it usually means the finding is about the task's design, not its code, and that is the user's call.

### Circuit Breaker

If **3 consecutive cycles** come back `NEEDS_FIX`, stop starting new cycles. The recurring cause is almost always upstream — invariants that don't say what they meant, or a task decomposition that doesn't match how the code wants to be structured. Report the pattern and return to Setup steps 3–4 with the user:

The count lives in `{TDD_DIR}/session.md` as `consecutive_needs_fix`. Increment it on every `NEEDS_FIX` verdict and reset it to 0 on every `APPROVED`.

> "최근 3개 사이클이 연속으로 수정 요청을 받았습니다: {사이클별 findings 한 줄 요약}. 개별 코드 문제라기보다 불변성 정의나 태스크 분해 쪽 문제로 보입니다. Setup의 불변성 표와 태스크 목록을 다시 확인할까요?"

### Feedback Cadence

Project instructions come first: if `CLAUDE.md` requires feedback after each stage, honor that and skip the rest of this section.

Otherwise, **gate cycle 1 and ask once**. Cycle 1 always pauses for feedback after its reviewer verdict, regardless of anything else — it is the cycle that reveals whether the invariants, the test conventions, and the task granularity were right. Immediately after that gate, ask exactly once:

> "1번 사이클이 끝났습니다. 남은 {N}개 사이클은 이어서 자동으로 진행할까요, 아니면 사이클마다 확인받을까요?
> (`.tdd-team/context.md`나 각 태스크의 `task.md`를 직접 수정하시면 다음 단계부터 반영됩니다.)"

Record the answer in `{TDD_DIR}/session.md` as `feedback_mode` and follow it for the rest of the session. Two exceptions override `auto`:
- the Fix Round Budget being exhausted, and
- the Circuit Breaker tripping.

Both stop and ask no matter which mode is active.

### Fix Agent Dispatch

Used by both the cycle reviewer and the final reviewer verdicts, and by a failing Final Review test run. Hand the agent the findings list itself — not the review report in full, and not the document they came from. If the Agent tool is not available, say `not available`, then apply `references/fix-agent.md` locally to the same findings.

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

## Error Handling

Every retry in this skill is bounded. When a budget runs out the answer is always to ask the user, never to try once more.

| Situation | Action | Budget |
|-----------|--------|--------|
| Build fails in RED | RED fixes stubs, re-verifies | handled inside RED |
| GREEN can't pass the test | Re-dispatch GREEN with a different approach | 2 attempts, then `BLOCKED` |
| REFACTOR breaks tests | Revert, apply changes one at a time | handled inside REFACTOR |
| Agent reports `BLOCKED` | See Handling `BLOCKED` | 1 reduced-context retry, then ask |
| Result block missing/incomplete | See Result Block Gate | 1 re-dispatch, then ask |
| Reviewer returns `NEEDS_FIX` | See Fix Round Budget | 2 rounds, then ask |
| 3 cycles in a row need fixes | See Circuit Breaker | stop and revisit Setup |

## Final Review

After all cycles complete, run **only the test classes touched this session** — the distinct `test_file` values from every `RED_RESULT`, together in one `TEST_SCOPED_CMD` invocation (Gradle: `./gradlew test --tests "FQCN1" --tests "FQCN2" … --offline`). Fall back to the full `TEST_CMD` only if the user asks for it, or if the change touched something with many indirect callers (a shared utility, a widely-used base class).

If anything fails, dispatch a fix agent first. Then dispatch an independent final reviewer, **passing it the scoped run's result** so it has no reason to re-run it. If the Agent tool is not available, say `not available` and apply `references/final-reviewer.md` locally to the task list, the invariants, and the branch diff.

Build the branch diff into a file first, the same way the cycle diff is built:

```bash
git diff > {TDD_DIR}/branch-diff.md
git ls-files --others --exclude-standard -- {SOURCE_DIR} {TEST_DIR} | while read -r f; do
  git diff --no-index /dev/null "$f" >> {TDD_DIR}/branch-diff.md
done
wc -l < {TDD_DIR}/branch-diff.md
```

The second command appends every file created this session — new test classes and new production classes are untracked, and `git diff` alone would omit them, leaving the final reviewer to conclude each task shipped without a test. `--exclude-standard` already honours `.git/info/exclude`, so `{TDD_DIR}` itself is skipped; scoping to `{SOURCE_DIR}` and `{TEST_DIR}` keeps unrelated untracked files in the user's repo out. `git diff --no-index` exits non-zero when it finds differences, which is the expected outcome here.

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

**Handle final reviewer verdict:**
- `APPROVED` → proceed to session end
- `NEEDS_FIX` → dispatch a single fix agent (see Fix Agent Dispatch) with the complete findings list, then re-run final reviewer. If the Agent tool is not available, fix locally.

The Fix Round Budget applies here too: **2 rounds maximum**. If findings remain after the second, end the session with them listed as unresolved rather than dispatching a third round, and say so plainly in the summary.

## Session End

Print a summary:

```
── TDD Session Complete ──
Cycles: {N} completed ({M} skipped GREEN — ALREADY_PASSES)
Tests:  {N} passed, 0 failed
Files:  {list of changed files}
Fixes:  {total fix rounds across the session}
Review: APPROVED | APPROVED WITH UNRESOLVED FINDINGS
Artifacts: .tdd-team/ (session.md, per-task results, reviews)
```

Leave `.tdd-team/` in place. It is the session's debugging record and the input to a later resume; it is excluded from git tracking, so it costs the user nothing to keep.

If the verdict is `APPROVED WITH UNRESOLVED FINDINGS`, list them underneath. Never print `APPROVED` for a session that ended on an exhausted budget.
