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

Orchestrate a 3-phase Red-Green-Refactor TDD cycle. Each cycle implements one small behavior increment.

## Codex Compatibility Rules

- Respect system, developer, and project `AGENTS.md` instructions above this skill.
- If project instructions require feedback after each stage, pause after RED, GREEN, REFACTOR, and review stages and ask for feedback before continuing.
- Use Codex sub-agents for RED, GREEN, REFACTOR, cycle review, and final review. If the Codex sub-agent tool is not available, say `not available` and fall back to local execution.
- In Codex, do not use Claude Code `Agent({ ... })`, `Read`, `Edit`, or `Write` tool names as literal tool calls. Use the available Codex tools and `apply_patch` for edits.

## Agent Roles

| Agent | Phase | Responsibility |
|-------|-------|----------------|
| **red** | RED | Write a failing test, verify it fails |
| **green** | GREEN | Make it pass with minimal code |
| **refactor** | REFACTOR | Improve quality, keep tests passing |

## Setup

### 1. Resolve Skill Path

This SKILL.md was loaded from a known absolute path. Capture its parent directory as `SKILL_DIR`.
Phase-specific instruction files are in:

```
{SKILL_DIR}/references/red-agent.md
{SKILL_DIR}/references/green-agent.md
{SKILL_DIR}/references/refactor-agent.md
{SKILL_DIR}/references/cycle-reviewer.md
{SKILL_DIR}/references/final-reviewer.md
```

### 2. Detect Environment

Check for build files (`build.gradle.kts`, `pom.xml`, `package.json`, etc.) and determine the test command. Capture:

```
PROJECT_ROOT / SOURCE_DIR / TEST_DIR / TEST_CMD / TEST_SCOPED_CMD / TEST_FRAMEWORK
```

- **TEST_CMD** — full-suite command. Run it **only once, at Final Review** (see below), never inside a cycle.
- **TEST_SCOPED_CMD** — command template that runs a **single test class**, used by every in-cycle test run. Gradle: `./gradlew test --tests "{FQCN}" --offline` (JUnit `@Nested` classes run with the enclosing class FQCN). Maven: `mvn -o test -Dtest={ClassName}`. npm/jest/vitest: pass the test file path (e.g. `npx vitest run {test_file}`).

**Speed configuration (do this before Cycle 1):**
- **Keep the build daemon warm.** For Gradle, ensure `org.gradle.daemon=true` and prefer `--offline`; **never run `clean`** between cycles (it throws away compiled output and forces a full rebuild every time).
- **Warm-up build once.** Before the first RED, run a one-off compile of sources + tests (Gradle: `./gradlew compileTestJava` / `compileTestKotlin --offline`; Maven: `mvn -o test-compile`) so the daemon is booted and the compile cache is hot — the first cycle then doesn't pay cold-start.

**Why scoped runs:** running the full suite in every RED/GREEN/REFACTOR was the dominant per-cycle cost. In-cycle runs are scoped to the class under test; cross-class regressions are caught by the mandatory full-suite run at Final Review.

### 3. Identify Domain Invariants

**If a plan document path is provided (from plan-creator):**

1. Read the document
2. Extract invariants from **Section 2 (Domain Context & Invariants)** — do not re-derive
3. Extract the task list from **Section 7 (Implementation Order / TDD)** — use `[NEW]` tagged items as TDD tasks; skip `[REGRESSION]` items (they are existing tests to run, not new cycles)
4. Present the task list in the format below and ask for confirmation before starting cycles
5. Skip Steps 3 and 4 below entirely

**If no plan document is provided — Source: PRD first, code second.**

1. If the user has provided a PRD, ticket, or feature description — derive domain invariants exclusively from that. Do NOT scan code at this step.
2. If no PRD is provided, ask: "구현할 기능의 요구사항이나 티켓 내용을 공유해주시겠어요?" and wait for the response.
3. After extracting invariants from the PRD, scan existing code (enum state transitions, validation annotations, guard clauses) only to catch structural constraints the PRD may have omitted. Never let the code override PRD intent.

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

Name each task as a **domain rule sentence** — it becomes the test's `@DisplayName` directly.

```
# Bad: add(1, 2) returns 3
# Good: 두 정수를 더하면 합계를 반환한다
```

Present the task list in this format, then get user confirmation before starting:

```
TDD 태스크 목록

  ┌─────┬─────────────────────────────────────────────────────────────────────────────────┐
  │  #  │                                    태스크                                       │
  ├─────┼─────────────────────────────────────────────────────────────────────────────────┤
  │ 1   │ {domain rule sentence → @DisplayName}                                           │
  ├─────┼─────────────────────────────────────────────────────────────────────────────────┤
  │ 2   │ {domain rule sentence → @DisplayName}                                           │
  └─────┴─────────────────────────────────────────────────────────────────────────────────┘
```

### 5. Capture Project Context (once)

Before the first cycle, the **orchestrator** explores the feature area **one time** and captures a reusable `PROJECT_CONTEXT` block. Each phase agent then reads this block instead of re-scanning the codebase — this removes the per-agent cold-start exploration that made every RED/GREEN feel slow.

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

For each task, execute RED → GREEN → REFACTOR in order using Codex sub-agents.

### Codex Sub-Agent Pattern

Discover the available multi-agent tool with `tool_search`, then spawn one worker per phase sequentially.
Each worker prompt must include:
- The phase reference file path
- The task description
- The environment block
- The `PROJECT_CONTEXT` block from Setup step 5 (so the agent does not re-scan the codebase)
- The previous phase result block where applicable
- A warning that other agents or the user may have edited the workspace and unrelated changes must not be reverted

If no Codex sub-agent tool is available, say `not available`, then execute the same phase locally:
1. Read the relevant reference file for the phase.
2. Follow that phase's workflow locally.
3. Use `apply_patch` for file edits.

**RED:**
```
Read {SKILL_DIR}/references/red-agent.md — you have permission to access this file.
Follow it exactly.

Task: {task description}

{PROJECT_CONTEXT block}
```

**GREEN** (append only the RED_RESULT block — not RED's full output):
```
Read {SKILL_DIR}/references/green-agent.md — you have permission to access this file.
Follow it exactly.

Task: {task description}

{PROJECT_CONTEXT block}

{RED_RESULT block}
```

**REFACTOR** (append only the GREEN_RESULT block — not GREEN's full output):
```
Read {SKILL_DIR}/references/refactor-agent.md — you have permission to access this file.
Follow it exactly.

Task: {task description}

{PROJECT_CONTEXT block}

{GREEN_RESULT block}
```

### Cycle Flow

1. **RED** → capture test file path, method name, failure message
   - `ALREADY_PASSES` → skip GREEN + REFACTOR, proceed to next task
   - Build fails → RED handles internally (fix stubs, re-verify)
2. **GREEN** → capture files modified, all test results
3. **REFACTOR** — skip if GREEN output is already clean
4. **CYCLE REVIEWER** → use a Codex reviewer sub-agent

### Cycle Reviewer Dispatch

After REFACTOR completes, review the cycle with a Codex reviewer sub-agent.

1. Discover the available multi-agent tool with `tool_search`.
2. Spawn a reviewer sub-agent with the prompt below.
3. If no Codex sub-agent tool is available, say `not available`, then apply `references/cycle-reviewer.md` locally to the cycle diff.

```
Read {SKILL_DIR}/references/cycle-reviewer.md — you have permission to access this file.
Follow it exactly.

Task: {task description}

Domain Invariants (from plan Section 2):
{invariants}

Diff:
{test code + implementation code written in this cycle}
```

**Handle reviewer verdict:**
- `APPROVED` → log progress, proceed to next task
- `NEEDS_FIX` → use a Codex fix sub-agent for Critical/Important findings, then re-run cycle reviewer. If no Codex sub-agent tool is available, fix locally.
  - Minor findings: log and continue

Follow project feedback gates between stages and cycles. If no feedback gate is required, continue through the task list without asking between cycles.

## Error Handling

| Situation | Action |
|-----------|--------|
| Build fails in RED | Fix stubs, re-verify failure |
| GREEN can't pass test | Retry with different approach |
| REFACTOR breaks tests | Revert and try smaller changes |

## Final Review

After all cycles complete, **run the full test suite once** with `TEST_CMD` to catch any cross-class regression that the in-cycle scoped runs did not exercise. If anything fails, dispatch a fix sub-agent before proceeding. Then run a final review with a Codex reviewer sub-agent.

1. Discover the available multi-agent tool with `tool_search`.
2. Spawn a reviewer sub-agent with the prompt below.
3. If no Codex sub-agent tool is available, say `not available`, then apply `references/final-reviewer.md` locally to the plan and full branch diff.

```
Read {SKILL_DIR}/references/final-reviewer.md — you have permission to access this file.
Follow it exactly.

Plan document path: {plan_document_path}

Branch diff:
{full diff of all changes in this session}
```

**Handle final reviewer verdict:**
- `APPROVED` → proceed to session end
- `NEEDS_FIX` → use a Codex fix sub-agent with the complete findings list, then re-run final reviewer. If no Codex sub-agent tool is available, fix locally.

## Session End

Print a summary:

```
── TDD Session Complete ──
Cycles: {N} completed
Tests:  {N} passed, 0 failed
Files:  {list of changed files}
Review: APPROVED
```
