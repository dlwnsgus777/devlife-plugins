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

Orchestrate a 3-phase Red-Green-Refactor TDD cycle using sequential sub-agent dispatches. Each cycle implements one small behavior increment.

## Codex Compatibility Rules

- Respect system, developer, and project `AGENTS.md` instructions above this skill.
- If project instructions require feedback after each stage, pause after RED, GREEN, REFACTOR, and review stages and ask for feedback before continuing.
- Use Codex sub-agents for RED, GREEN, REFACTOR, cycle review, and final review. If the Codex sub-agent tool is not available, say `not available` and fall back to local execution.
- In Codex, do not use Claude Code `Agent({ ... })`, `Read`, `Edit`, or `Write` tool names as literal tool calls. Use the available Codex tools and `apply_patch` for edits.

## Right-Size the Ceremony

**Never cut RED/GREEN isolation, regardless of change size.** It is structural, not risk-based: one mind writing both the test and the implementation gravitates to happy-path-only coverage, because the test ends up describing what you already intended to build instead of pressure-testing the requirement. A tiny change is as vulnerable to that as a large one. RED always runs blind to how GREEN will implement it, and GREEN always runs as a separate dispatch, on every cycle.

What scales down with change size is everything *around* that isolation:
- **Cycle granularity** — batch scenarios that share one implementation change into a single task (Step 4).
- **REFACTOR** — skips itself when GREEN's output is clean.
- **CYCLE REVIEWER depth** — static reasoning by default; live experiments only for `ALREADY_PASSES` (see cycle-reviewer.md).
- **Final Review scope** — touched classes only unless the change has wide blast radius. Both reviewers are handed the test result the orchestrator (or GREEN/fix agent) already produced; they read and reason rather than re-running it.

## Model Selection

If the Codex sub-agent tool you discovered exposes a model or reasoning-effort parameter, set it per the table below. If it exposes no such parameter, dispatch every role on the session default and skip this section entirely — do not invent a parameter the tool does not accept.

Where the parameter does exist, **inherit the session default unless the table gives a concrete reason to override.** Don't downgrade reflexively: **turn count beats token price**, since an undersized model burns the savings on re-reads and retries.

| Role | Default | When to override |
|------|---------|-------------------|
| RED | inherit | Designing a failing test from a domain-rule sentence is judgment, not transcription. |
| GREEN | inherit | Cheapest available tier only when genuinely narrow — one small method, shape already spelled out, nothing to design. |
| REFACTOR | inherit | Skips itself on clean output; the runs that happen need real judgment. |
| CYCLE REVIEWER | inherit | The check that catches vacuous tests and invariant gaps. Don't cheapen it. |
| FIX agent | inherit; cheapest tier for a mechanical fix | Cheap tier is enough for a rename, a one-line guard, a reference swap. A fix that re-derives *why*, or touches more than the named lines, stays at the default. |
| FINAL REVIEWER | **the most capable model available** | Last gate on the whole session — dispatch on the most capable model available. |

### Handling `BLOCKED`

1. Dispatched at a downgraded tier → re-dispatch the same call at the default tier.
2. `BLOCKED` at the default tier → re-dispatch **once** with a reduced prompt: keep the task, environment, and previous-phase result; drop `PROJECT_CONTEXT` down to just the target package and the one or two signatures the agent needs.
3. Still `BLOCKED` → stop dispatching and ask the user:

> "{역할} 에이전트가 '{사유}'로 막혔습니다. 이 태스크를 로컬에서 직접 진행할까요, 아니면 건너뛰고 다음 태스크로 갈까요?"

Never spend a third dispatch on the same call.

## Setup

### 1. Resolve Skill Path

This SKILL.md was loaded from a known absolute path. Capture its parent directory as `SKILL_DIR`. Each phase agent's prompt file lives under `{SKILL_DIR}/references/` and is read directly by that phase's sub-agent dispatch — there is no separate aggregate prompts file to load here.

```
{SKILL_DIR}/references/red-agent.md
{SKILL_DIR}/references/green-agent.md
{SKILL_DIR}/references/refactor-agent.md
{SKILL_DIR}/references/cycle-reviewer.md
{SKILL_DIR}/references/final-reviewer.md
{SKILL_DIR}/references/fix-agent.md
```

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

### 5. Capture Project Context (once)

Before the first cycle, the **orchestrator** explores the feature area **one time** and captures a reusable `PROJECT_CONTEXT` block. Each phase agent then reads this block instead of re-scanning the codebase.

Capture only what the agents actually need to avoid re-reading:

```
## Project Context (captured once — do NOT re-explore the codebase)
- Package / directory layout: {where the feature's source & test packages live}
- Test conventions: {JUnit version, assertion library/style, // arrange·act·assert, @Nested usage}
- Fixture pattern: {Fixture builder location & usage, repository.save helper pattern}
- Relevant existing types: {ClassName → key public method signatures} for classes this feature touches
- Domain anchors: {aggregate/entity files + invariants that apply here}
- In-scope files: {actual paths this session may modify — anything else is out of bounds}
- Out of scope: {what this task deliberately does not change}
- Known pitfalls — do NOT copy: {defect in existing code} → {what to do instead}
```

Keep it compact (signatures and paths, not full file bodies). If the feature is brand-new with no nearby code, state "관련 기존 코드 없음" and list only the target package.

**The last three lines are boundaries, not background.** Every phase agent runs in its own context and infers conventions from whatever code it reads, which is exactly how a known defect gets reproduced and how an edit lands in a file nobody meant to touch. Source them from the plan document — 「구현 대상 파일」, 「목표가 아닌 것」, and 「기존 코드의 함정」 respectively. If the plan has no pitfall section, spend one pass on the reference implementation the feature imitates before the first cycle; a defect found in cycle 3 has already been copied twice.

A pitfall entry without its `→ what to do instead` half is worse than omitting it — the agent knows to avoid something and invents its own replacement. If a section has nothing, write `해당 없음` rather than dropping the line, so a later reader can tell it was considered.

### 6. Open a Session Ledger (4+ tasks only)

If the confirmed task list has **4 or more tasks**, write `docs/tdd/session-{feature}.md` before the first cycle so an interrupted or compacted session can resume without re-deriving Setup:

```
# TDD Session: {feature}
Test command: {TEST_SCOPED_CMD}
Invariants: {numbered list from step 3}

| # | Task | Status | Test class | Fix rounds |
|---|------|--------|-----------|-----------|
| 1 | {domain rule sentence} | pending | - | 0 |
```

Update the row after each cycle's reviewer verdict — one line edit, nothing else. For 3 tasks or fewer, skip this: the list fits in the conversation and the file costs more than it saves.

**On resume**, read this file first. Adopt its task list and invariants as-is and continue from the first non-`done` row — do NOT re-run Setup steps 3–4.

## TDD Cycle Execution

> **BLOCKING REQUIREMENT — TDD ORDER**: Do not write production implementation before a failing test has been written and verified.
>
> **BLOCKING REQUIREMENT — ORCHESTRATOR ONLY**: You are the orchestrator. After user confirmation, you MUST dispatch a Codex sub-agent for every RED / GREEN / REFACTOR step. Do NOT patch source or test files yourself. If you find yourself about to edit a file directly — stop and dispatch a sub-agent instead.

For each task, dispatch a Codex sub-agent three times sequentially (RED → GREEN → REFACTOR). Each agent reads only its own prompt file. Include the `PROJECT_CONTEXT` block (from Setup step 5) in every agent prompt so the agent does not re-scan the codebase.

### Codex Sub-Agent Pattern

Discover the available multi-agent tool with `tool_search`, then spawn one worker per phase sequentially — inheriting the session model for RED/GREEN/REFACTOR unless Model Selection gives you a reason to override.
Each worker prompt must include:
- The phase reference file path
- The task description
- The environment block
- The `PROJECT_CONTEXT` block from Setup step 5 (so the agent does not re-scan the codebase)
- The previous phase result block where applicable
- A warning that other agents or the user may have edited the workspace and unrelated changes must not be reverted

The environment block has one fixed shape, built once from Setup step 2 and reused verbatim in every prompt below (RED/GREEN/REFACTOR/CYCLE REVIEW/FIX/FINAL REVIEW alike — cycle reviewers and the final reviewer need `{TEST_SCOPED_CMD}` too, for the narrow case where their Verification Depth section calls for running it):

```
## Environment
- Project root: {PROJECT_ROOT}
- Source directory: {SOURCE_DIR}
- Test directory: {TEST_DIR}
- Scoped test command: {TEST_SCOPED_CMD}
- Test framework: {TEST_FRAMEWORK}
```

The workspace warning is one fixed line, also reused verbatim everywhere:

```
Others may have edited this workspace since your prompt was prepared. Never revert a change you didn't make — it is someone else's work in progress.
```

### Result Block Gate

Every phase returns a fixed result block (`RED_RESULT` / `GREEN_RESULT` / `REFACTOR_RESULT` / `FIX_RESULT`). Before acting on one, check that the block is present and every field is filled.

If it is missing or a field is blank, **do not infer the value and do not proceed to the next phase** — re-dispatch that same agent with the same prompt plus one line naming the missing field. A guessed `RED_RESULT` sends GREEN after the wrong method, which costs a whole wasted cycle. Count the re-dispatch against the `BLOCKED` budget above: one retry, then ask the user.

If no Codex sub-agent tool is available, say `not available`, then execute the same phase locally:
1. Read the relevant reference file for the phase.
2. Follow that phase's workflow locally.
3. Use `apply_patch` for file edits.

All three phases use one prompt shape — only `{PHASE_FILE}` and the trailing result block differ:

```
Read {SKILL_DIR}/references/{PHASE_FILE} — you have permission to access this file.
Follow it exactly.

Task: {task description}

{ENVIRONMENT block}

{PROJECT_CONTEXT block}

{PRIOR_RESULT block, if any}

{workspace warning line}
```

| PHASE | PHASE_FILE | PRIOR_RESULT |
|-------|-----------|--------------|
| RED | `red-agent.md` | none |
| GREEN | `green-agent.md` | `RED_RESULT` only — not RED's full output |
| REFACTOR | `refactor-agent.md` | `GREEN_RESULT` only — not GREEN's full output |

### Cycle Flow

1. **RED** → capture test file path, method name(s), failure message(s) — a batched task reports one line per scenario
   - Every reported method is `ALREADY_PASSES` → skip GREEN + REFACTOR, proceed to next task (still run CYCLE REVIEWER — it's the only check that the new tests are real coverage, not vacuous)
   - At least one method is genuinely Red → proceed to GREEN as usual; GREEN targets the Red ones, the `ALREADY_PASSES` ones just ride along as already-passing coverage
   - Build fails → RED handles internally (fix stubs, re-verify)
2. **GREEN** → capture files modified, all test results
3. **REFACTOR** — skip if GREEN output is already clean
4. **CYCLE REVIEWER** → dispatch an independent Codex reviewer sub-agent (see below)

### Cycle Reviewer Dispatch

After REFACTOR completes, dispatch an independent reviewer sub-agent, **passing it GREEN's (or the fix agent's) reported test result** so it has no reason to re-run what was just run and reported.

1. Discover the available multi-agent tool with `tool_search`.
2. Spawn a reviewer sub-agent with the prompt below, inheriting the session model (see Model Selection — don't cheapen this role).
3. If no Codex sub-agent tool is available, say `not available`, then apply `references/cycle-reviewer.md` locally to the cycle diff.

```
Read {SKILL_DIR}/references/cycle-reviewer.md — you have permission to access this file.
Follow it exactly.

Task: {task description}

{ENVIRONMENT block}

Domain Invariants:
{invariants}

Test run just completed: tests_passed={N}, tests_failed=0 (from GREEN_RESULT / fix report)

Diff:
{test code + implementation code written in this cycle}

{workspace warning line}
```

**Handle reviewer verdict:**
- `APPROVED` → log progress, proceed to next task
- `NEEDS_FIX` → dispatch a Codex fix sub-agent (see Fix Sub-Agent Dispatch) for Critical/Important findings, then re-run cycle reviewer, again passing the fix agent's reported test result. If no Codex sub-agent tool is available, fix locally.
  - Minor findings: log and continue

### Fix Round Budget

**Maximum 2 fix rounds per cycle.** A round is one fix-agent dispatch plus one reviewer re-run.

If the reviewer still returns `NEEDS_FIX` after the second round, stop the loop and hand the decision to the user rather than dispatching a third:

> "{태스크}에서 리뷰어가 2회 수정 후에도 지적을 남겼습니다: {미해결 findings}. 이대로 두고 다음 태스크로 갈까요, 직접 손보실까요, 아니면 이 태스크를 다시 설계할까요?"

A third round almost never resolves what two could not — it usually means the finding is about the task's design, not its code, and that is the user's call.

### Circuit Breaker

If **3 consecutive cycles** come back `NEEDS_FIX`, stop starting new cycles. The recurring cause is almost always upstream — invariants that don't say what they meant, or a task decomposition that doesn't match how the code wants to be structured. Report the pattern and return to Setup steps 3–4 with the user:

> "최근 3개 사이클이 연속으로 수정 요청을 받았습니다: {사이클별 findings 한 줄 요약}. 개별 코드 문제라기보다 불변성 정의나 태스크 분해 쪽 문제로 보입니다. Setup의 불변성 표와 태스크 목록을 다시 확인할까요?"

### Feedback Cadence

Project instructions come first: if `AGENTS.md` requires feedback after each stage, honor that and skip the rest of this section.

Otherwise, **gate cycle 1 and ask once**. Cycle 1 always pauses for feedback after its reviewer verdict, regardless of anything else — it is the cycle that reveals whether the invariants, the test conventions, and the task granularity were right. Immediately after that gate, ask exactly once:

> "1번 사이클이 끝났습니다. 남은 {N}개 사이클은 이어서 자동으로 진행할까요, 아니면 사이클마다 확인받을까요?"

Record the answer and follow it for the rest of the session. Two exceptions override "자동으로 진행":
- the Fix Round Budget being exhausted, and
- the Circuit Breaker tripping.

Both stop and ask no matter which mode is active.

### Fix Sub-Agent Dispatch

Used by both the cycle reviewer and the final reviewer verdicts, and by a failing Final Review test run. Hand the agent the findings list itself — not the review report in full, and not the document they came from.

1. Discover the available multi-agent tool with `tool_search`.
2. Spawn a fix sub-agent with the prompt below, inheriting the session model — or the cheapest available tier when the fix is purely mechanical (see Model Selection).
3. If no Codex sub-agent tool is available, say `not available`, then apply `references/fix-agent.md` locally to the same findings.

```
Read {SKILL_DIR}/references/fix-agent.md — you have permission to access this file.
Follow it exactly.

Findings to fix (Critical/Important only):
{findings list — each naming a file, a behavior, and what must change}

{ENVIRONMENT block}

{PROJECT_CONTEXT block}

{workspace warning line}
```

Capture the returned `FIX_RESULT` block — its `tests_passed`/`tests_failed` counts are what you pass to the reviewer on the re-run, so the reviewer has no reason to run the tests again.

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

If anything fails, dispatch a fix sub-agent first. Then dispatch an independent final reviewer sub-agent, **passing it the scoped run's result** so it has no reason to re-run it.

1. Discover the available multi-agent tool with `tool_search`.
2. Spawn a reviewer sub-agent with the prompt below, on **the most capable model available** (see Model Selection — this is the last gate on the session's work).
3. If no Codex sub-agent tool is available, say `not available`, then apply `references/final-reviewer.md` locally to the confirmed task list, the invariants, and the full branch diff.

```
Read {SKILL_DIR}/references/final-reviewer.md — you have permission to access this file.
Follow it exactly.

Confirmed task list:
{task list}

{ENVIRONMENT block}

Domain Invariants:
{invariants}

Test run just completed by the orchestrator: {TEST_SCOPED_CMD invocation} → {N} passed, 0 failed

Branch diff:
{full diff of all changes in this session}

{workspace warning line}
```

**Handle final reviewer verdict:**
- `APPROVED` → proceed to session end
- `NEEDS_FIX` → dispatch a single Codex fix sub-agent (see Fix Sub-Agent Dispatch) with the complete findings list, then re-run final reviewer. If no Codex sub-agent tool is available, fix locally.

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
```

If the verdict is `APPROVED WITH UNRESOLVED FINDINGS`, list them underneath. Never print `APPROVED` for a session that ended on an exhausted budget.
