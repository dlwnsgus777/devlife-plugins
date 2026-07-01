---
name: TDD Team
version: 0.5.0
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

## Agent Roles

| Agent | Phase | Responsibility |
|-------|-------|----------------|
| **red** | RED | Write a failing test, verify it fails |
| **green** | GREEN | Make it pass with minimal code |
| **refactor** | REFACTOR | Improve quality, keep tests passing |

## Setup

### 1. Resolve Skill Path

This SKILL.md was loaded from a known absolute path. Capture its parent directory as `SKILL_DIR`. The agent prompts file is at:

```
{SKILL_DIR}/references/agent-prompts.md
```

### 2. Detect Environment

Check for build files (`build.gradle.kts`, `pom.xml`, `package.json`, etc.) and determine the test command. Capture:

```
PROJECT_ROOT / SOURCE_DIR / TEST_DIR / TEST_CMD / TEST_FRAMEWORK
```

### 3. Identify Domain Invariants

**Source: PRD first, code second.**

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

## TDD Cycle Execution

> **BLOCKING REQUIREMENT — ORCHESTRATOR ONLY**: You are the orchestrator. After user confirmation, you MUST use the `Agent` tool for every RED / GREEN / REFACTOR step. Do NOT call `Edit`, `Write`, or `Read` on source or test files yourself. If you find yourself about to edit a file directly — stop and spawn an Agent instead.

For each task, call the `Agent` tool three times sequentially (RED → GREEN → REFACTOR). Each agent reads only its own prompt file.

### Agent Tool Call Pattern

**RED:**
```
Agent({
  description: "RED: {task description}",
  prompt: """
Read {SKILL_DIR}/references/red-agent.md — you have permission to access this file.
Follow it exactly.

Task: {task description}
"""
})
```

**GREEN** (append only the RED_RESULT block — not RED's full output):
```
Agent({
  description: "GREEN: {task description}",
  prompt: """
Read {SKILL_DIR}/references/green-agent.md — you have permission to access this file.
Follow it exactly.

Task: {task description}

{RED_RESULT block}
"""
})
```

**REFACTOR** (append only the GREEN_RESULT block — not GREEN's full output):
```
Agent({
  description: "REFACTOR: {task description}",
  prompt: """
Read {SKILL_DIR}/references/refactor-agent.md — you have permission to access this file.
Follow it exactly.

Task: {task description}

{GREEN_RESULT block}
"""
})
```

### Cycle Flow

1. **RED** → capture test file path, method name, failure message
   - `ALREADY_PASSES` → skip GREEN + REFACTOR, go to checkpoint
   - Build fails → RED handles internally (fix stubs, re-verify)
2. **GREEN** → capture files modified, all test results
3. **REFACTOR** — skip if GREEN output is already clean

### Cycle Summary and User Checkpoint

⛔ **MANDATORY STOP after every task — including task 1.**

Before presenting the summary, verify the cycle is genuinely complete:

- [ ] Every new function/method has a test
- [ ] The test was watched to fail before implementation
- [ ] The failure was for the expected reason (missing feature, not a typo or compile error)
- [ ] Only minimal code was written to pass the test
- [ ] All tests pass with pristine output (no warnings or noise)
- [ ] Mocks were used only when unavoidable

If any box is unchecked → do not present the summary. Escalate the gap to the relevant agent first.

Present:

```
── TDD Cycle {N} Complete ──
RED:      ✅ Test written: {method name}
GREEN:    ✅ Implementation: {summary}
REFACTOR: ✅ {what changed / "no refactoring needed"}
Tests: {N} passed, 0 failed

[x] 1. {done}   [>] 2. {current}   [ ] 3. {next}
```

Request feedback:

> "이 구현에 대한 피드백을 주실 수 있으신가요?
> 특히 [테스트 커버리지 / 구현 방식 / 설계 결정] 부분에 대한 의견을 주시면 반영하겠습니다."

**Wait silently.** Do NOT proceed until the user sends explicit approval ("진행해", "다음", "계속", "LGTM", "ok", "좋아"). No exceptions — even if the next task is trivial.

## Error Handling

| Situation | Action |
|-----------|--------|
| Build fails in RED | Fix stubs, re-verify failure |
| GREEN can't pass test | Retry with different approach |
| REFACTOR breaks tests | Revert and try smaller changes |

## Session End

Final summary: cycles completed, files changed, final test count, next steps.
