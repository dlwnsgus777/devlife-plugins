---
name: TDD Team
version: 0.4.0
description: >
  Use this skill when the user wants to develop features using Test-Driven Development
  with an agentic Red-Green-Refactor cycle. Trigger on "start TDD", "do TDD",
  "TDD로 개발해줘", "TDD 시작", "TDD 팀 만들어", "테스트 주도 개발",
  "red green refactor", "test-driven development", "테스트 먼저 작성하고 싶어",
  "write tests first then implement", "테스트부터 짜줘", "TDD 방식으로 구현해줘".
  Also trigger when a user describes a feature and says they want it built incrementally
  with tests, e.g. "이 기능 테스트 먼저 만들고 하나씩 구현하자", "build this with
  failing tests first", or "한 단계씩 테스트 작성하면서 개발하고 싶어".
  Do NOT trigger for simply writing unit tests after implementation, running existing
  tests, or debugging test failures — those are not TDD workflows.
---

# TDD Team

Orchestrate a 3-phase Red-Green-Refactor TDD cycle using sequential Agent calls. Each cycle implements one small behavior increment: write a failing test, make it pass with minimal code, then clean up.

## Agent Roles

| Agent | Phase | Responsibility |
|-------|-------|----------------|
| **red** | RED — Write failing test | Create a test that compiles but fails, then verify the failure |
| **green** | GREEN — Make it pass | Implement the simplest code to make the test pass |
| **refactor** | REFACTOR — Clean up | Improve code quality while keeping all tests passing |

## Setup

### 0. cmux (Optional)

If cmux is available, read `references/cmux-integration.md` to set up a 3-pane split layout (RED / GREEN / REFACTOR) on the right side and sidebar status indicators. Capture `RED_PANE`, `GREEN_PANE`, `REFACTOR_PANE` surface IDs for use throughout the session. Skip if cmux is not detected.

### 1. Detect Environment

Check for build files (`build.gradle.kts`, `pom.xml`, `package.json`, etc.) and determine the test command. Capture as environment context:

```
PROJECT_ROOT / SOURCE_DIR / TEST_DIR / TEST_CMD / TEST_FRAMEWORK
CMUX_ENABLED (true/false) / RED_PANE / GREEN_PANE / REFACTOR_PANE
```

### 2. Decompose into TDD Tasks

Break the feature into small, incremental behaviors — each becomes one TDD cycle. Name each as a behavior statement: "returns X when Y". Example for "Calculator 클래스":

```
1. add(1, 2) returns 3
2. subtract(5, 3) returns 2
3. divide(10, 0) throws ArithmeticException
```

Present the task list and get user confirmation before starting.

## TDD Cycle Execution

For each task, run three sequential Agent calls. Read `references/agent-prompts.md` for the full system prompts.

### RED Phase

Spawn agent with Red prompt + environment context + task description. Key inputs/outputs:
- **Input**: task description, existing file paths
- **Output**: test file path, method name, failure message
- If test already passes → skip GREEN. If build fails → fix stubs, re-verify.

### GREEN Phase

Spawn agent with Green prompt + RED's failure output. Key inputs/outputs:
- **Input**: failing test path, failure message
- **Output**: files modified, all test results
- Write the minimum code to pass. If still failing, retry with different approach.

### REFACTOR Phase

**조건부 실행**: GREEN 단계에서 코드가 이미 깔끔하다고 판단되면 이 페이즈를 건너뜁니다. 단순한 행동(단순 연산, 단순 반환 등)은 리팩터링이 거의 불필요합니다.

Spawn agent with Refactor prompt + current source/test files. Key inputs/outputs:
- **Input**: summary of RED+GREEN changes
- **Output**: what changed and why (or "no refactoring needed"), final test results
- Agent identifies ALL opportunities first, applies them in one batch, then runs tests once. Only falls back to incremental if the batch fails.

### Cycle Summary and User Checkpoint

After each cycle, present:

```
── TDD Cycle {N} Complete ──
RED:      ✅ Test written: {method name}
GREEN:    ✅ Implementation: {summary}
REFACTOR: ✅ {what changed / "no refactoring needed"}
Tests: {N} passed, 0 failed

[x] 1. {done}   [>] 2. {current}   [ ] 3. {next}

Continue with task 2? (or modify remaining tasks)
```

If cmux is available: `cmux notify` on cycle complete (see `references/cmux-integration.md`).

## Key Principles

**Strict phase separation** — RED writes tests only, GREEN writes production code only, REFACTOR changes no behavior. This ensures tests genuinely validate behavior rather than passing alongside code written at the same time.

**Simplest implementation first** — GREEN can hardcode values. Elegance comes from REFACTOR. If hardcoding passes the test, the test probably needs a stricter assertion.

**One behavior per cycle** — Small steps build confidence and keep the feedback loop tight.

## Error Handling

| Situation | Action |
|-----------|--------|
| Build fails in RED | Fix stubs, re-verify failure |
| GREEN can't pass test | Retry with different approach |
| REFACTOR breaks tests | Revert and try smaller changes |

## Session End

Provide a final summary: cycles completed, files changed, final test count, next steps.
If cmux was used, run cleanup from `references/cmux-integration.md`.

## Reference Files

- **`references/agent-prompts.md`** — Full prompts for Red, Green, and Refactor agents
- **`references/cmux-integration.md`** — cmux pane layout and status commands (read only if cmux available)
