---
name: tdd-agent-team
description: >
  Use this skill when the user wants Test-Driven Development run by a Claude Code
  agent team — a persistent RED teammate and GREEN teammate working in parallel and
  handing work to each other directly, with role boundaries enforced by hooks.
  Trigger on "TDD 팀으로", "TDD 팀으로 개발해줘", "에이전트 팀으로 TDD", "agent team으로 TDD",
  "병렬 TDD", "팀원끼리 TDD", "tdd-agent-team", "TDD with an agent team", "parallel TDD".
  Trigger only when the request names a team or parallel teammates. For plain
  "TDD로 개발해줘" / "TDD 시작" requests without a team, use tdd-subagent instead.
  Do NOT trigger for writing tests after implementation, running existing tests, or
  debugging test failures.
---

# TDD Agent Team

Run Red-Green-Refactor with an agent team: a `tdd-red` teammate writes failing tests task after task, a `tdd-green` teammate makes them pass, and the two hand work to each other directly. RED for task N+1 runs while GREEN works on task N.

## Execution Rules

**You are the team lead.** Setup, the two user checkpoints, unblocking, and the final stages are yours. The cycle itself is not: once the teammates are running, RED and GREEN pass work between themselves and you stay off that path. Never relay a handoff, never re-run a teammate's test to double-check it. After Setup, the only source edits you make are stubs a teammate asks for in `missing-stub.md`; you never edit test files.

- Respect system, developer, and project `CLAUDE.md` instructions above this skill.
- The user is asked exactly twice: at task confirmation (Setup 5) and before applying final-review fixes (Final Review 3). Project instructions that ask for feedback after each stage are honored at these two points — the cycle runs in parallel and has no stage boundary to pause at.
- **Teammate content travels in files, never in messages.** Every `SendMessage` body — yours and every teammate's — is one line: `READ <path>`. The file holds the substance. A message with prose in it skips the gates below and leaks context the reader was not meant to have.

### What enforces the rules

Three mechanisms live outside the teammates, in the devlife plugin's hooks. You rely on them; you do not re-implement them.

| Mechanism | Where | What it does |
|---|---|---|
| Role paths | `hooks/enforce-tdd-roles.sh` (`PreToolUse` on Read/Write/Edit/Grep) | `tdd-red` cannot read or write production paths. `tdd-green` cannot write test paths |
| Handoff gate | `hooks/gate-tdd-handoff.sh` (`PreToolUse` on SendMessage) | `tdd-red` → `tdd-green` `READ <task_dir>/red-result.md` is delivered only if the tests compile **and fail**. `tdd-green` → `team-lead` `READ <task_dir>/green-result.md` only if they **pass**. `tdd-red` can send `tdd-green` nothing else, and `tdd-green` cannot message `tdd-red` at all |
| Artifact access | `hooks/allow-tdd-artifact.sh` | No permission prompts for `.tdd-agent-team/**/*.md` |

The hooks identify a teammate by its **name** — they see `agent_type: "tdd-red"`. Spawn the teammates with exactly the names `tdd-red` and `tdd-green`, or nothing is enforced. They act only in a project that has `.tdd-agent-team/roles.env`, so they never touch other sessions.

### Teammate definitions

Every teammate's role lives in a devlife plugin agent definition, spawned by its scoped type:

| Teammate name | `subagent_type` | Definition |
|---|---|---|
| `tdd-red` | `devlife:tdd-red` | `agents/tdd-red.md` |
| `tdd-green` | `devlife:tdd-green` | `agents/tdd-green.md` |
| `review-domain` / `review-test` / `review-design` | `devlife:tdd-reviewer` | `agents/tdd-reviewer.md` (lens named in the spawn prompt) |

The definition body becomes the teammate's system prompt, so the role is in force from its first turn — not only once it decides to read a file. The definitions carry no `hooks`: Claude Code ignores that field for plugin agents, which is why enforcement lives in the plugin's `hooks/hooks.json` and keys on the teammate **name**.

Definitions and hooks both ship with the devlife plugin; without it there is no team to spawn. Check during Setup 0: `devlife:tdd-red`, `devlife:tdd-green`, and `devlife:tdd-reviewer` must appear among the agent types your `Agent` tool lists. That holds however the plugin was loaded — marketplace install or `--plugin-dir` — and the hooks come with the same plugin. If any is missing, stop:

> "이 스킬은 devlife 플러그인의 팀원 정의(`agents/`)와 hook이 필요한데 찾지 못했습니다. 플러그인을 설치하거나 `tdd-subagent`로 진행해 주세요."

## Setup

### 0. Agent Teams Enabled?

Agent teams need `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Check the **effective** value with `echo "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"` — settings files' `env` blocks are applied to the session, and project or local settings override `~/.claude/settings.json`, so reading the user file alone gives the wrong answer. If it is not `1`:

> "이 스킬은 Claude Code agent teams 기능이 필요한데 지금 꺼져 있습니다(`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). `~/.claude/settings.json`의 `env`에 `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"`을 넣어드릴까요? 켜면 이름을 붙인 서브에이전트가 팀원으로 실행되는 등 다른 작업에도 영향이 있습니다. 원치 않으시면 `tdd-subagent`로 진행할 수 있습니다."

Edit the file only on an explicit yes. On no, stop and point to `tdd-subagent`. Agent teams also need an interactive session — in `-p` / SDK mode, teammates never spawn; stop and say so.

### 1. Previous Session?

If `.tdd-agent-team/session.md` exists, teammates from that session are gone — agent teams cannot restore them. Ask:

> "이전 tdd-agent-team 세션 기록이 있습니다({완료}/{전체} 태스크 완료). 팀원은 복원되지 않아 이어서 진행할 수 없습니다. 기록을 보관하고 새로 시작할까요?"

On yes, move everything in `.tdd-agent-team/` into `.tdd-agent-team/archive-{YYYYMMDD-HHMMSS}/`, leaving earlier archives in place. Never delete an archive.

### 2. Artifact Directory

- `TDD_DIR` = `.tdd-agent-team` (relative to the project root, where this skill runs)
- `TASK_DIR` = `{TDD_DIR}/tasks/{NN}` — `NN` zero-padded to two digits

```bash
mkdir -p .tdd-agent-team/tasks
git rev-parse --git-dir >/dev/null 2>&1 \
  && ! grep -qxF '.tdd-agent-team/' "$(git rev-parse --git-dir)/info/exclude" 2>/dev/null \
  && echo '.tdd-agent-team/' >> "$(git rev-parse --git-dir)/info/exclude"
```

Use `.git/info/exclude`, never `.gitignore`.

### 3. Detect Environment and Write `roles.env`

From the build files, determine the commands and path patterns, then write `{TDD_DIR}/roles.env`. The hooks source this file, so it must be valid `sh`:

```sh
TEST_COMPILE_CMD='./gradlew compileTestJava --offline'
TEST_METHOD_RUNNER='./gradlew test --offline'
TEST_METHOD_CMD='--tests "{M}"'
TEST_PATH_GLOBS='*/src/test/*'
SOURCE_PATH_GLOBS='*/src/main/*'
```

- **Every test run in this skill is per method.** RED adds failing tests for task N+1 to a class while GREEN is finishing task N, so a class-level run hands GREEN someone else's failure. `TEST_METHOD_RUNNER` is the fixed part; `TEST_METHOD_CMD` is the per-method argument with `{M}` standing for one `FQCN.method`, repeated once per method. Maven: runner `mvn -o test`, arg `-Dtest="{M}"` with `{M}` as `Class#method`. jest/vitest: runner `npx vitest run`, arg `-t "{M}"` with the test name.
- `TEST_COMPILE_CMD` compiles test sources without running them. No compile step (plain JS, Python) → `true`.
- The globs are matched against absolute paths, space-separated, shell `case` patterns. Include every source and test root the feature touches. `.tdd-agent-team/` must match neither.

### 4. Invariants and Tasks

**Invariants — requirements document first, code second.** With a spec, plan, or ticket, derive invariants from it and adopt any IDs (`INV-001`, …) verbatim. With nothing, ask "구현할 기능의 요구사항이나 티켓 내용을 공유해주시겠어요?" and wait. Only then scan code for structural constraints the document omitted. Write each as a declarative sentence about what must be true.

**Tasks.** Adopt the document's ordered task list if it has one; `[REGRESSION]` items are not tasks — they run in the final test. Name each task as a domain rule sentence; RED turns it into `@DisplayName`.

- **Batch scenarios that share one implementation change** into one task — one guard clause, one branch, one small function. A task maps to a unit of implementation work, not to a test method.
- **Coverage floor, never a cap:** per invariant, the case that violates it, the nearest case that satisfies it, and every state the rule itself names; plus one happy path per touched class. An edge case with no test is an unbuilt behavior, because GREEN builds exactly what the tests demand.
- **Before presenting, name the production change behind every task.** "Nothing — it already works" or "an earlier task already makes it pass" means it is coverage, not a task: merge its scenarios into the task that builds the logic. In this skill a task that cannot be Red is not just wasted — the handoff gate refuses it, and RED stalls on it.
- **Order tasks so dependencies come first.** RED runs ahead of GREEN, so task N+1's tests may be written while task N is still unbuilt — they fail for both reasons and the gate lets them through, which is fine because GREEN works in order and reaches N+1 after N. What breaks is the reverse: a later task listed before the task it needs. Record each dependency in `task.md` (`depends_on:`).

### 5. Confirm Tasks ← user checkpoint 1

Present invariants and tasks together, with the test names, and wait for confirmation:

```
TDD 태스크 목록

  ┌─────┬──────────────────────────────────────────────────────────────┐
  │  #  │ 태스크 → @DisplayName                                         │
  ├─────┼──────────────────────────────────────────────────────────────┤
  │ 1   │ {domain rule sentence} (+ {sentence} if batched)             │
  └─────┴──────────────────────────────────────────────────────────────┘
```

> "태스크를 확정하면 팀원이 끝까지 자동으로 진행하고, 최종 리뷰 결과가 나오면 다시 확인받습니다. 이대로 진행할까요?"

After this answer, do not ask again until Final Review 3 — except for the escalations named under Lead Duties.

### 6. Context, Session, and Task Files

**`{TDD_DIR}/context.md`** — explore the feature area once and write only what you verified this session:

```
# TDD Session Context

## Environment
- Project root: {absolute path}
- Commands and path rules: .tdd-agent-team/roles.env
- Test framework: {framework}

## Project Context (captured once — do NOT re-explore the codebase)
- Package / directory layout: {source & test packages}
- Test conventions: {JUnit version, assertion style, // arrange·act·assert, @Nested usage}
- Fixture pattern: {builder location & usage}
- Signatures RED may call: {ClassName → public method signatures, including the stubs from Setup 7}
- Domain anchors: {aggregate/entity files + invariants that apply here}
- In-scope files: {paths this session may modify}
- Out of scope: {what this task deliberately does not change}
- Known pitfalls — do NOT copy: {defect} → {what to do instead}

## Domain Invariants
{list, IDs verbatim}

## Workspace Rules
Others may have edited this workspace since this file was written. Never revert a change you didn't make.
Do not commit. The lead and the user own the commit history.
Invariant IDs are session bookkeeping — never write them into production or test code.
SendMessage bodies are one line: READ <path>. Content goes in files.
```

**"Signatures RED may call" is RED's only window into production code** — the hook blocks it from reading production files. Every type, constructor, and method a test will touch must be listed with its exact signature. A missing signature costs a `missing-stub` round trip per task.

**`{TDD_DIR}/session.md`** — you are its only writer:

```
# TDD Agent Team Session: {feature}

| # | task | status | note |
|---|------|--------|------|
| 1 | {domain rule sentence} | PENDING | - |
```

`status`: `PENDING` | `RED_DONE` | `DONE` | `BLOCKED`.

**`{TASK_DIR}/task.md`** per task:

```
# Task {NN}: {domain rule sentence}
invariants: {INV-001, INV-004}
test_class: {FQCN}
depends_on: {task numbers, or none}
scenarios:
- {scenario sentence}
```

Decide `test_class` here, not in RED — the stubs below and the per-method commands both need it.

### 7. Stubs

RED cannot write production paths, so every production type and method the tests will call must exist before RED starts. Create them now from the plan document's signatures (or the task scenarios): bodies `throw new UnsupportedOperationException("Not implemented yet")` — never a silent `null` or default. Then run `TEST_COMPILE_CMD` and confirm it passes. Add each stub's signature to `context.md` "Signatures RED may call".

After this, you add a stub only when RED asks for one through `missing-stub.md`.

## Running the Team

### Spawn

```
Agent({
  name: "tdd-red",
  subagent_type: "devlife:tdd-red",
  description: "TDD RED teammate",
  prompt: "TDD_DIR={TDD_DIR}. Start with task 01 under {TDD_DIR}/tasks/ and continue in number order."
})

Agent({
  name: "tdd-green",
  subagent_type: "devlife:tdd-green",
  description: "TDD GREEN teammate",
  prompt: "TDD_DIR={TDD_DIR}. Wait for READ messages from tdd-red."
})
```

The role is in the definition; the prompt carries only the session facts. The names are load-bearing — the hooks key on them. Do not add a model; teammates inherit the session's.

**First report.** Each teammate's first message is `READ .tdd-agent-team/tools-{name}.md`, listing the tools it actually received. A teammate without `SendMessage`, `Write`, `Edit`, or `Bash` cannot do its role — and a missing `SendMessage` means it cannot even send that report, so a teammate silent past its first idle notification counts as missing it. Stop the team and tell the user which tool was missing rather than letting the cycle start lame.

### Lead Duties During the Cycle

You are off the handoff path. RED → GREEN goes direct; GREEN reports to you only when a task is done. What reaches you, and what you do:

| Message | Your action |
|---|---|
| `READ .tdd-agent-team/tools-{name}.md` | Check the role's tools are all there (see First report). Nothing else |
| `READ {TASK_DIR}/green-result.md` (gate already passed) | Set the task `DONE` in `session.md`. Nothing else |
| `READ {TASK_DIR}/missing-stub.md` | Add the stub, run `TEST_COMPILE_CMD`, add the signature to `context.md`, reply `READ {TASK_DIR}/task.md` to the sender |
| `READ {TASK_DIR}/blocked.md` | If it names a missing fact, add it to `context.md` and reply `READ {TASK_DIR}/task.md`. If it is a gate that failed twice or a design problem, set `BLOCKED` and ask the user — this is the one mid-cycle escalation |
| `READ {TDD_DIR}/red-finished.md` | RED has written tests for every task. Note it; wait for GREEN |
| Idle notification | Compare it against `session.md` and the result files under `tasks/`. A teammate idle with work still owed means a handoff was never sent: tell **the sender** to send it again (`READ {TASK_DIR}/task.md` to that teammate). Never send the handoff yourself — your message would bypass the gate |

Update `session.md` after every message you act on. It is the only record of progress — there is no shared task list.

The cycle is finished when every task is `DONE` or `BLOCKED` and RED has sent `red-finished.md`.

## Final Stages

### 1. Test Refactor

GREEN refactored production code as it went; test code has not been touched since RED wrote it. Write `{TDD_DIR}/test-refactor.md` listing every test class this session created or changed, and send `READ {TDD_DIR}/test-refactor.md` to `tdd-red`. RED reports back `READ {TDD_DIR}/test-refactor-result.md` when the session's methods still pass.

### 2. Final Test

Run every session method in one invocation — all `test_methods` from every `red-result.md`, plus the `[REGRESSION]` classes — with `TEST_METHOD_RUNNER` and one `TEST_METHOD_CMD` per method. Redirect the output to `{TDD_DIR}/final-test.log` and read only the counts and failing names. If anything fails, write the failures to `{TDD_DIR}/final-test-failures.md` and send `READ` to `tdd-green`; at most 2 rounds, then ask the user.

### 3. Parallel Final Review ← user checkpoint 2

Build the diff into a file first — it must never pass through your context:

```bash
git diff > .tdd-agent-team/branch-diff.md
git ls-files --others --exclude-standard | while read -r f; do
  git diff --no-index /dev/null "$f" >> .tdd-agent-team/branch-diff.md
done
wc -l < .tdd-agent-team/branch-diff.md
```

Spawn three reviewers from the one definition, each owning one lens:

```
Agent({ name: "review-domain", subagent_type: "devlife:tdd-reviewer", description: "Final review: domain",
        prompt: "You are review-domain — the domain lens. TDD_DIR={TDD_DIR}" })
Agent({ name: "review-test",   subagent_type: "devlife:tdd-reviewer", description: "Final review: test",
        prompt: "You are review-test — the test lens. TDD_DIR={TDD_DIR}" })
Agent({ name: "review-design", subagent_type: "devlife:tdd-reviewer", description: "Final review: design",
        prompt: "You are review-design — the design lens. TDD_DIR={TDD_DIR}" })
```

Each writes `{TDD_DIR}/final-review-{lens}.md`, sends it to the other two, rebuts what it receives in `{TDD_DIR}/rebuttal-{from}-to-{to}.md`, revises its own report once, and sends you `READ {TDD_DIR}/final-review-{lens}.md`. When all three have reported, merge them into `{TDD_DIR}/final-review.md`: drop findings a rebuttal refuted, keep the rest with their severity.

Show the user the Critical and Important findings and ask:

> "최종 리뷰 결과입니다: {Critical/Important 목록}. 어떤 항목을 반영할까요? (전부 / 번호 선택 / 반영 안 함)"

Apply only what is approved. Write `{TDD_DIR}/fixes.md` with the approved items split by owner — production changes to `tdd-green`, test changes to `tdd-red` — and send each its `READ`. GREEN's report goes through the green gate as usual. Then re-run the Final Test once.

### 4. Shut Down and Summarize

Ask each teammate and reviewer to shut down. Then print:

```
── TDD Agent Team Session Complete ──
Tasks:   {DONE}/{total} ({BLOCKED} blocked)
Tests:   {N} passed, 0 failed
Files:   {changed files}
Review:  {applied}/{proposed} findings applied
Artifacts: .tdd-agent-team/
```

Leave `.tdd-agent-team/` in place — it is excluded from git and is the session's debugging record.
