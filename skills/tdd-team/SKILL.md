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

## Agent Roles

| Agent | Phase | Responsibility |
|-------|-------|----------------|
| **red** | RED | Write a failing test, verify it fails |
| **green** | GREEN | Make it pass with minimal code |
| **refactor** | REFACTOR | Improve quality, keep tests passing |

## Right-Size the Ceremony

**Never cut RED/GREEN isolation, regardless of change size.** The reason RED and GREEN are separate dispatches isn't "this feature is risky, so be careful" — it's structural: one mind writing both the test and the implementation gravitates to happy-path-only coverage, because the test ends up describing whatever you already intended to build rather than pressure-testing the actual requirement. A tiny change is just as vulnerable to that bias as a large one — the implementer *wants* green, and a test they wrote with the implementation already in mind is the easiest way to get there. So RED always runs blind to how GREEN will implement it, and GREEN always runs as a separate dispatch from RED, on every cycle, no matter how small the task looks.

What legitimately scales down with change size and risk is everything *around* that isolation:
- **Cycle granularity** — batch related scenarios that share one implementation change into a single task instead of one full RED→GREEN→REFACTOR→REVIEW per test method (see Step 4's batching guidance).
- **REFACTOR** — already skips itself when GREEN's output is clean; don't force it to run when there's nothing to improve.
- **CYCLE REVIEWER depth** — static reasoning by default; reserve live mutation experiments for genuine doubt, and never `--rerun-tasks`/`--rerun`/`clean` even then (see cycle-reviewer.md's Verification Depth section).
- **Final Review scope** — touched classes only, not the full suite, unless the change has wide blast radius (see Final Review below). Both the cycle reviewer and the final reviewer are handed the test result the orchestrator (or GREEN/fix agent) already produced — they read and reason, they don't re-run it themselves absent a specific, concrete doubt.

## Setup

### 1. Resolve Skill Path

This SKILL.md was loaded from a known absolute path. Capture its parent directory as `SKILL_DIR`. Each phase agent's prompt file lives under `{SKILL_DIR}/references/` and is read directly by that phase's `Agent` call — there is no separate aggregate prompts file to load here.

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

**Source: the requirements document first, code second.** The document may be a spec, a plan, a ticket, or a plain feature description — treat them all the same way.

1. If a document is provided, read it and derive domain invariants exclusively from it. Do NOT scan code at this step. If the document already states its invariants explicitly, adopt them as written instead of re-deriving.
2. If nothing is provided, ask: "구현할 기능의 요구사항이나 티켓 내용을 공유해주시겠어요?" and wait for the response.
3. Only after extracting invariants from the document, scan existing code (enum state transitions, validation annotations, guard clauses) to catch structural constraints the document may have omitted. Never let the code override the document's intent.

Express each business rule as a complete declarative sentence that describes **what should be true**, not what the code currently does:

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

If the document already provides an ordered task list, adopt it instead of deriving a new one. Drop any item that only re-runs existing coverage rather than requiring new behavior, and apply the batching rule below before presenting the list — a document often lists scenarios one-per-line for readability, which is a documentation granularity, not a cycle granularity.

Name each task as a **domain rule sentence** — it becomes the test's `@DisplayName` directly.

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
```

Keep it compact (signatures and paths, not full file bodies). If the feature is brand-new with no nearby code, state "관련 기존 코드 없음" and list only the target package.

## TDD Cycle Execution

> **BLOCKING REQUIREMENT — TDD ORDER**: Do not write production implementation before a failing test has been written and verified.
>
> **BLOCKING REQUIREMENT — ORCHESTRATOR ONLY**: You are the orchestrator. After user confirmation, you MUST use the `Agent` tool for every RED / GREEN / REFACTOR step. Do NOT call `Edit` or `Write` on source or test files yourself. If you find yourself about to edit a file directly — stop and spawn an Agent instead.

For each task, call the `Agent` tool three times sequentially (RED → GREEN → REFACTOR). Each agent reads only its own prompt file. Include the `PROJECT_CONTEXT` block (from Setup step 5) in every agent prompt so the agent does not re-scan the codebase.

### Agent Tool Call Pattern

Each worker prompt must include:
- The phase reference file path
- The task description
- The environment block
- The `PROJECT_CONTEXT` block from Setup step 5 (so the agent does not re-scan the codebase)
- The previous phase result block where applicable
- A warning that other agents or the user may have edited the workspace and unrelated changes must not be reverted

If the Agent tool is not available, say `not available`, then execute the same phase locally:
1. Read the relevant reference file for the phase.
2. Follow that phase's workflow locally.
3. Use `Edit`/`Write` for file edits.

**RED:**
```
Agent({
  subagent_type: "general-purpose",
  description: "RED: {task description}",
  prompt: """
Read {SKILL_DIR}/references/red-agent.md — you have permission to access this file.
Follow it exactly.

Task: {task description}

{PROJECT_CONTEXT block}
"""
})
```

**GREEN** (append only the RED_RESULT block — not RED's full output):
```
Agent({
  subagent_type: "general-purpose",
  description: "GREEN: {task description}",
  prompt: """
Read {SKILL_DIR}/references/green-agent.md — you have permission to access this file.
Follow it exactly.

Task: {task description}

{PROJECT_CONTEXT block}

{RED_RESULT block}
"""
})
```

**REFACTOR** (append only the GREEN_RESULT block — not GREEN's full output):
```
Agent({
  subagent_type: "general-purpose",
  description: "REFACTOR: {task description}",
  prompt: """
Read {SKILL_DIR}/references/refactor-agent.md — you have permission to access this file.
Follow it exactly.

Task: {task description}

{PROJECT_CONTEXT block}

{GREEN_RESULT block}
"""
})
```

### Cycle Flow

1. **RED** → capture test file path, method name(s), failure message(s) — a batched task reports one line per scenario
   - Every reported method is `ALREADY_PASSES` → skip GREEN + REFACTOR, proceed to next task (still run CYCLE REVIEWER — it's the only check that the new tests are real coverage, not vacuous)
   - At least one method is genuinely Red → proceed to GREEN as usual; GREEN targets the Red ones, the `ALREADY_PASSES` ones just ride along as already-passing coverage
   - Build fails → RED handles internally (fix stubs, re-verify)
2. **GREEN** → capture files modified, all test results
3. **REFACTOR** — skip if GREEN output is already clean
4. **CYCLE REVIEWER** → dispatch independent subagent (see below)

### Cycle Reviewer Dispatch

After REFACTOR completes, dispatch an independent reviewer subagent, **passing it GREEN's (or the fix agent's) reported test result** so it has no reason to re-run what was just run and reported. If the Agent tool is not available, say `not available`, then apply `references/cycle-reviewer.md` locally to the cycle diff.

```
Agent({
  subagent_type: "general-purpose",
  description: "CYCLE REVIEW: {task description}",
  prompt: """
Read {SKILL_DIR}/references/cycle-reviewer.md — you have permission to access this file.
Follow it exactly.

Task: {task description}

Domain Invariants:
{invariants}

Test run just completed: tests_passed={N}, tests_failed=0 (from GREEN_RESULT / fix report)

Diff:
{test code + implementation code written in this cycle}
"""
})
```

**Handle reviewer verdict:**
- `APPROVED` → log progress, proceed to next task
- `NEEDS_FIX` → dispatch a fix agent (see Fix Agent Dispatch) for Critical/Important findings, then re-run cycle reviewer, again passing the fix agent's reported test result. If the Agent tool is not available, fix locally.
  - Minor findings: log and continue

Follow project feedback gates between stages and cycles. If no feedback gate is required, continue through the task list without asking between cycles.

### Fix Agent Dispatch

Used by both the cycle reviewer and the final reviewer verdicts, and by a failing Final Review test run. Hand the agent the findings list itself — not the review report in full, and not the document they came from. If the Agent tool is not available, say `not available`, then apply `references/fix-agent.md` locally to the same findings.

```
Agent({
  subagent_type: "general-purpose",
  description: "FIX: {short summary of findings}",
  prompt: """
Read {SKILL_DIR}/references/fix-agent.md — you have permission to access this file.
Follow it exactly.

Findings to fix (Critical/Important only):
{findings list — each naming a file, a behavior, and what must change}

{PROJECT_CONTEXT block}
"""
})
```

Capture the returned `FIX_RESULT` block — its `tests_passed`/`tests_failed` counts are what you pass to the reviewer on the re-run, so the reviewer has no reason to run the tests again.

## Error Handling

| Situation | Action |
|-----------|--------|
| Build fails in RED | Fix stubs, re-verify failure |
| GREEN can't pass test | Retry with different approach |
| REFACTOR breaks tests | Revert and try smaller changes |

## Final Review

After all cycles complete, run **only the test classes touched this session** — collect the distinct `test_file` values from every cycle's `RED_RESULT` and run them together in one `TEST_SCOPED_CMD` invocation (e.g. Gradle: `./gradlew test --tests "FQCN1" --tests "FQCN2" ... --offline`). Do **not** run the full suite by default. Only fall back to the full `TEST_CMD` if the user explicitly asks for full-suite/cross-class coverage, or if the change touched something with many indirect callers (a shared utility, a widely-used base class) where breakage wouldn't show up in the touched classes alone.

If anything fails, dispatch a fix agent (see Fix Agent Dispatch) before proceeding. Then dispatch an independent final reviewer subagent, **passing it the scoped test run's result** (pass/fail counts, which classes) so it has no reason to re-run what you just ran yourself. If the Agent tool is not available, say `not available`, then apply `references/final-reviewer.md` locally to the confirmed task list, the invariants, and the full branch diff.

```
Agent({
  subagent_type: "general-purpose",
  description: "FINAL REVIEW",
  prompt: """
Read {SKILL_DIR}/references/final-reviewer.md — you have permission to access this file.
Follow it exactly.

Confirmed task list:
{task list}

Domain Invariants:
{invariants}

Test run just completed by the orchestrator: {TEST_SCOPED_CMD invocation} → {N} passed, 0 failed

Branch diff:
{full diff of all changes in this session}
"""
})
```

**Handle final reviewer verdict:**
- `APPROVED` → proceed to session end
- `NEEDS_FIX` → dispatch a single fix agent (see Fix Agent Dispatch) with the complete findings list, then re-run final reviewer. If the Agent tool is not available, fix locally.

## Session End

Print a summary:

```
── TDD Session Complete ──
Cycles: {N} completed
Tests:  {N} passed, 0 failed
Files:  {list of changed files}
Review: APPROVED
```
