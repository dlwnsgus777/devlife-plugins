---
name: tdd-agent-team
description: >
  Use this skill when the user wants Test-Driven Development run by a Claude Code
  agent team — a persistent RED teammate and GREEN teammate working in parallel and
  handing work to each other directly, each role's tools limited by its agent definition.
  Trigger on "TDD 팀으로", "TDD 팀으로 개발해줘", "에이전트 팀으로 TDD", "agent team으로 TDD",
  "병렬 TDD", "팀원끼리 TDD", "tdd-agent-team", "TDD with an agent team", "parallel TDD".
  Trigger only when the request names a team or parallel teammates. For plain
  "TDD로 개발해줘" / "TDD 시작" requests without a team, use tdd-subagent instead.
  Do NOT trigger for writing tests after implementation, running existing tests, or
  debugging test failures.
---

# TDD Agent Team

Run Red-Green-Refactor with an agent team: `tdd-red` writes failing tests, `tdd-green` makes them pass with the minimum code, and the two hand work to each other directly. Tasks whose scopes do not overlap run in parallel; a task that touches the same files waits until the earlier task's refactor is done. `tdd-refactor` owns structure and quality. It applies the confirmed Tidy First items before the cycle, and each time a task turns green, it refactors the code and tests that task worked on.

## Execution Rules

**You are the team lead.** Setup (the initial stubs included), creating the Tasks, the Tidy Check, `blocked` reports and user escalations, the Final Verification, and merging the review are yours. When one teammate's output is another's input — a handoff, a stub request, a green task to refactor — the sender sends it straight to the receiver; you never relay it, except to resend a lost handoff (Lead Duties). After Setup you edit no source or test file.

- Respect system, developer, and project `CLAUDE.md` instructions above this skill.
- The user is asked three times: at task confirmation (Setup 5), after the Tidy First phase when there is one (to commit it separately), and before applying final-review fixes (Final Stage 2). Project instructions that ask for feedback after each stage are honored at these points; between them the team runs without pausing.
- **Files through file tools, shell commands kept simple — yours too.** Create files with `Write`, change them with `Edit` (a `session.md` status flip is one `Edit`), read them with `Read`. Use Bash only to run commands, one simple command at a time: no `cd …;` prefix, heredocs, `sed -i`, loops, `$(…)`, `$variables`, or brace expansion. The permission checker cannot analyze those and stops the session on a prompt; `_workspace/tdd-agent-team/*.md` artifacts pass without one only when written through the file tools.
- **Java is only an example — use the project's language.** The Java/JUnit constructs in this skill (`@DisplayName`, `@Nested`, `UnsupportedOperationException`, Gradle commands) are examples. In another stack, use that language's equivalent in your files and on the screens you show the user (see the Other Stacks table in the `test-writing` skill).
- **Teammate content travels in files, never in messages.** Every `SendMessage` body — yours and every teammate's — is one line, `READ <path>` or `READ <path>#<section>` (e.g. `READ _workspace/tdd-agent-team/tasks/03/task.md#red-result`); the only exception is a teammate's first report, `READY`. A `#section` is a `## <section>` heading in that file. One task's results all live in its `task.md`, one section per writer; rewriting a section replaces it in place, never adds a second copy. A message with prose in it skips the checks the files carry and leaks context the reader was not meant to have.
- **The shared task list is required.** The team runs on the Task tools (`TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate`), checked in Setup 0. Every piece of work handed to a teammate (`tidy/{NN}/tidy.md`, `tasks/{NN}/task.md`, `tasks/{NN}/task.md#green-result`) gets exactly one Task, whose `description` is one line, `READ <path>`. Changing a Task's `owner` notifies no one, so every handoff is still a `SendMessage READ <path>` to the receiver: the Task records who holds the work, the message moves it.

### Teammate definitions

Each role is a **plugin agent** of the `devlife` plugin — its definition lives in the plugin's `agents/` directory, and the plugin install registers it:

| Teammate name | `subagent_type` | Source | `tools` |
|---|---|---|---|
| `tdd-red` | `devlife:tdd-red` | `{PLUGIN_ROOT}/agents/tdd-red.md` | Read, Write, Edit, Bash, SendMessage |
| `tdd-green` | `devlife:tdd-green` | `{PLUGIN_ROOT}/agents/tdd-green.md` | Read, Write, Edit, Bash, SendMessage |
| `tdd-refactor` | `devlife:tdd-refactor` | `{PLUGIN_ROOT}/agents/tdd-refactor.md` | Read, Write, Edit, Bash, SendMessage |
| `review-domain` / `review-test` / `review-design` | `devlife:tdd-reviewer` | `{PLUGIN_ROOT}/agents/tdd-reviewer.md` | Read, Write, Bash, SendMessage — no `Edit` |

`SKILL_DIR` is the directory this file is in; `PLUGIN_ROOT` is two levels above it (`{SKILL_DIR}/../..`). Nothing is copied anywhere: spawn with the plugin name in the `subagent_type` column. The teammate's `name` — what everyone addresses with `SendMessage` — stays the bare role name.

**What tools can and cannot prevent.** Tools can only limit which tools a teammate has: reviewers have no `Edit`, so they cannot change files. Tools cannot limit which files a teammate reads or writes, so the teammates must keep these rules themselves:

- RED does not read production code.
- GREEN does not edit tests, does not refactor, and red-checks before it implements.
- `tdd-refactor` does not change what a test checks.

If someone breaks one, the Final Verification and the `review-test` lens catch it.

## Setup

### 0. Agent Teams Enabled?

Confirm this session has what a team needs: the agent teams feature, the teammate definitions, and the Task tools.

Agent teams need `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Check the **effective** value with `printenv CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` (empty output means unset) — not `echo "$…"`, whose variable the permission checker cannot analyze, so it stops the session on a prompt. Settings files' `env` blocks are applied to the session, and project or local settings override `~/.claude/settings.json`, so reading the user file alone gives the wrong answer. If it is not `1`:

> "이 스킬은 Claude Code agent teams 기능이 필요한데 지금 꺼져 있습니다(`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). `~/.claude/settings.json`의 `env`에 `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"`을 넣어드릴까요? 켜면 이름을 붙인 서브에이전트가 팀원으로 실행되는 등 다른 작업에도 영향이 있습니다."

Edit the file only on an explicit yes. On no, stop.

**Teammate definitions present?** Check that `devlife:tdd-red`, `devlife:tdd-green`, `devlife:tdd-refactor`, and `devlife:tdd-reviewer` are among the agent types your `Agent` tool lists. If any is missing, the `devlife` plugin is not installed or is out of date. Stop and say so:

> "팀원 정의(`devlife:tdd-*` 에이전트)를 찾을 수 없습니다. `devlife` 플러그인을 설치하거나 최신으로 갱신한 뒤 다시 실행해주세요."

**Task tools available?** Load `TaskCreate`, `TaskGet`, `TaskList`, and `TaskUpdate` with `ToolSearch`. On some models they need `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`. If they do not load, ask:

> "이 세션에는 공유 작업 목록(Task 도구)이 없습니다. `~/.claude/settings.json`의 `env`에 `"CLAUDE_CODE_ENABLE_TODO_TOOLS": "1"`을 넣어드릴까요? 이 스킬은 공유 작업 목록 없이는 진행할 수 없습니다."

On yes, add it, then load the tools again (a settings `env` change usually applies to the running session). If they are still missing, tell the user to restart Claude Code and run the skill again, and stop. On no, stop.

### 1. Previous Session?

Archive an earlier run's records so they do not mix with this session's files.

If `_workspace/tdd-agent-team/session.md` exists, teammates from that session are gone — agent teams cannot restore them.

- **It ends with `session: COMPLETE`** — that session finished, so archive it without asking and say so in one line:

  > "이전 세션 기록을 `_workspace/tdd-agent-team/archive-{YYYYMMDD-HHMMSS}/`에 보관했습니다."

- **It does not** — the session stopped partway, and the user may want to look at what was left undone first. Ask:

  > "이전 tdd-agent-team 세션 기록이 있습니다({완료}/{전체} 태스크 완료). 팀원은 복원되지 않아 이어서 진행할 수 없습니다. 기록을 보관하고 새로 시작할까요?"

  On no, stop.

To archive, move everything in `_workspace/tdd-agent-team/` except earlier `archive-*/` folders into `_workspace/tdd-agent-team/archive-{YYYYMMDD-HHMMSS}/`. Never delete an archive.

### 2. Artifact Directory

Set where the session's files live, and exclude that folder from git so it stays out of diffs and commits.

- `TDD_DIR` = `_workspace/tdd-agent-team` (relative to the project root, where this skill runs)
- `TASK_DIR` = `{TDD_DIR}/tasks/{NN}` — `NN` zero-padded to two digits (e.g. `01`)

1. `git rev-parse --git-common-dir` — prints the git directory whose `info/exclude` git reads (usually `.git`; in a worktree, the main repository's `.git`). If it fails, this is not a git repository; skip the next two steps.
2. `Read` `{git dir}/info/exclude`. If it has no `_workspace/tdd-agent-team/` line, add one with `Edit` (or `Write` the file if it does not exist).
3. `git rev-parse HEAD` — the commit this session starts from. Record it as `base` in `session.md` (Setup 6); the final review diffs against it.

Use `info/exclude`, never `.gitignore`.

**Files under `{TDD_DIR}`** — every file the session creates:

| File | Written by | Read by | Holds |
|---|---|---|---|
| `roles.env` | lead (Setup 3) | everyone | Compile and test commands |
| `context.md` | lead (Setup 6); `tdd-green` adds stub signatures | everyone | Shared session facts, "Signatures RED may call" |
| `roles/{name}.md` | lead (Setup 6) | that teammate only | What only that role needs |
| `session.md` | lead only | lead, reviewers, next run's Setup 1 | Task list, base commit, progress |
| `tidy/{NN}/tidy.md` | lead (header, `lead-check`); `tdd-refactor` (`tidy-result`, `blocked`) | lead, `tdd-refactor` | One Tidy First item |
| `tasks/{NN}/task.md` | lead (header); each teammate its own sections | lead, teammates | One task and all its results |
| `tasks/{NN}/red-check.log` | `tdd-green` | reviewers | Proof the task's tests failed first |
| `blocked.md` | `tdd-refactor` | lead | A block outside any task |
| `final-test.log` | lead | reviewers | Final run of every session method |
| `branch-diff.md` | lead | reviewers | The session's whole diff |
| `final-review-{lens}.md` | each reviewer | lead, other reviewers | One lens's findings |
| `rebuttal-{you}-to-{them}.md` (lens names, e.g. `rebuttal-design-to-domain.md`) | each reviewer | lead | Rebuttal of another lens |
| `fixes.md` | lead (`## tdd-red`/`tdd-green`/`tdd-refactor` items); each owner its `## red-result`/`green-result`/`refactor-result` | assigned owners | Approved fixes |
| `fix-red-check.log` | `tdd-green` | lead | Red check of fix tests |
| `archive-{YYYYMMDD-HHMMSS}/` | lead (Setup 1) | — | A previous session, never deleted |

### 3. Detect Environment and Write `roles.env`

Decide the test commands the teammates will run and write them to `roles.env`.

From the build files, determine the test commands, then write `{TDD_DIR}/roles.env`. The teammates read their commands from it:

```sh
TEST_COMPILE_CMD='./gradlew compileTestJava --offline'
TEST_METHOD_RUNNER='./gradlew test --offline'
TEST_METHOD_CMD='--tests "{M}"'
```

- **Every test run in this skill is per method.** A test class holds other tasks' methods too, so run exactly the ids of the work at hand and every result is about that work alone.
- `TEST_METHOD_RUNNER` is the fixed part; `TEST_METHOD_CMD` is the argument added once per method, with `{M}` standing for one method id.
- `TEST_COMPILE_CMD` compiles test sources without running them. No compile step (plain JS) → `true`.

| Stack | `TEST_METHOD_RUNNER` | `TEST_METHOD_CMD` | `{M}` |
|---|---|---|---|
| Gradle | `./gradlew test --offline` | `--tests "{M}"` | `FQCN.method` |
| Maven | `mvn -o test` | `-Dtest="{M}"` | `Class#method` |
| jest/vitest | `npx vitest run` | `-t "{M}"` | test name |

Then, unless both test commands are already in `permissions.allow` of `.claude/settings.json` or `.claude/settings.local.json`, offer once to pre-approve them:

> "팀원이 테스트 명령을 수십 번 실행합니다. `{TEST_COMPILE_CMD}`와 `{TEST_METHOD_RUNNER}`를 이 프로젝트의 `.claude/settings.local.json` 허용 목록에 추가할까요? (안 하면 실행 중 권한 확인이 자주 뜰 수 있습니다)"

On yes, add `Bash({TEST_COMPILE_CMD}:*)` and `Bash({TEST_METHOD_RUNNER}:*)` to `permissions.allow` in `.claude/settings.local.json`, creating the file if needed and leaving existing entries untouched. On no, continue.

### 4. Invariants, Scope, and Tasks

Everything below comes from the requirements (a document, or what the user described in this session) **when they say so, and from your own exploration when they do not**. Never leave a gap empty or fill it by guessing — derive it, then show it at Setup 5 for confirmation.

**Explore once, here.** Read the code the change will modify, its callers, and its existing tests a single time; that one pass feeds the invariants, the scope, the regression set, the tidy candidates, and later `context.md`.

**Invariants** — the rules this feature must keep. Tasks are derived from them, and the final review checks that each one has tests.
- The requirements can be a document (spec, plan, ticket) or what the user described in this session. With neither, ask "구현할 기능의 요구사항이나 티켓 내용을 공유해주시겠어요?" and wait.
- Derive them from the requirements and number them from `INV-001` (keep the requirements' own numbers if they have them).
- Then add structural constraints the code shows and the requirements omitted.
- Write each as a declarative sentence about what must be true.

**Scope** — the boundary between what this work changes and what it leaves alone; it keeps teammates from touching anything outside it.
- Set the in-scope files, out-of-scope items, and known pitfalls (defects in the code the change imitates, each with what to do instead) — from the requirements, or from the tasks and the exploration.
- In-scope files are concrete paths; GREEN and `review-domain` check the boundary against them.
- They go only to GREEN's and `tdd-refactor`'s role files (Setup 6) — RED must not know them.

**Regression set** — the existing tests related to this work. They must keep passing throughout.
- Find every existing test class that exercises a file in scope; add any existing tests the requirements mention.
- It runs in the final test and is the safety net of the Tidy First phase. A task's refactor runs only the part of it on that task's `regression:` line (Setup 6).

**Tidy First items** — work that changes structure without changing behavior, *before* the requested change, to make that change easier. It changes no behavior, so it can never be Red: each becomes a **tidy item**, not a task.
- Find such work in the requirements.
- Extracting an abstraction counts: it is extracted from the cases that already exist, and the new case it will receive is a task.
- For each, capture what blocks the change today, the restructuring to apply, and where the change lands afterwards. If the requirements leave one unsaid, ask at Setup 5 rather than guessing.
- For each, pick its safety net: the regression set and every existing test class that exercises the files the item touches. If none does, the item has an **empty safety net** — mark it for Setup 5.
- If the requirements do not address tidying, read `{SKILL_DIR}/references/tidy-first-scan.md` and apply it to the code in scope. What it finds are **candidates** — shown at Setup 5, and only the ones the user approves become tidy items.
- If the requirements name tidy items, or state with a reason that none are needed, skip the scan — do not second-guess that decision.

**Tasks** — the units of implementation work. For each, RED writes the failing tests and GREEN makes them pass.
- Adopt the requirements' ordered task list if they have one; otherwise decompose the invariants.
- Items already covered by existing tests are not tasks — they go to the regression set.
- Name each task as a domain rule sentence (RED turns it into `@DisplayName`).
- **Batch scenarios that share one implementation change** into one task — one guard clause, one branch, one small function.
- **Coverage floor, never a cap.** Include at least the following; an edge case with no test is a behavior GREEN never builds.
  - Per invariant: the case that violates it, the nearest case that satisfies it, and every state the rule itself names.
  - Per touched class: one happy path.
- **Every task needs a production change behind it.** A scenario that already works, or that an earlier task already makes pass, cannot be Red — merge it into the task that builds the logic.
- **Give every task a scope, and number tasks so dependencies come first.**
  - A task's scope is the production files it will change (`scope_production`) and its `test_class`.
  - Two tasks overlap when they share a production file or a test class. Overlapping tasks run one after the other in number order (so two teammates never edit the same file at once); others run in parallel (Creating Tasks).
  - If a task needs another one's code without sharing a file, put that file in both scopes so the order holds.

### 5. Confirm Tasks ← user checkpoint 1

Present together, and wait for confirmation:
- the tidy items — marking which came from the requirements and which are your **candidates** for the user to approve or drop, and which have an empty safety net
- the in-scope files
- the regression set
- the invariants
- the tasks with their test names and scopes:

```
TDD 태스크 목록

  ┌─────┬──────────────────────────────────────────────┬──────────────────────┐
  │  #  │ 태스크 → @DisplayName                         │ 영향 범위 (선행)       │
  ├─────┼──────────────────────────────────────────────┼──────────────────────┤
  │ 1   │ {domain rule sentence} (+ {sentence} if batched) │ {files} (-)       │
  │ 2   │ {domain rule sentence}                       │ {files} (1)          │
  └─────┴──────────────────────────────────────────────┴──────────────────────┘
```

> "태스크를 확정하면 팀원이 끝까지 자동으로 진행하고, 최종 리뷰 결과가 나오면 다시 확인받습니다. 이대로 진행할까요?"

**Empty safety net.** For each tidy item with no existing test behind it, ask this together with the confirmation:

> "정비 항목 {NN}({요약})이 건드리는 {파일}을 검증하는 기존 테스트가 없습니다. 정비 후 동작이 그대로인지 확인할 수 없습니다. 테스트를 직접 추가한 뒤 계속할까요, 안전망 없이 정비할까요, 이 항목을 뺄까요?"

- "테스트를 직접 추가한 뒤 계속" → wait for the user to write the tests. Once they say the tests are in, add those test ids to the safety net and keep the item.
- "안전망 없이 정비" → keep the item.
- "이 항목을 뺄까요" → drop it from the tidy items.

**Is a team worth it?** With one or two tasks, the team's upkeep outweighs what it buys. In that case, ask this instead of the question above:

> "태스크가 {N}개라 팀을 유지하는 비용(팀원마다 가이드·문맥을 따로 읽고, 대기 알림마다 리드가 응답)이 얻는 이득보다 큽니다. `tdd-subagent`로 전환할까요? (확정한 태스크 목록을 그대로 넘깁니다) / 팀으로 그대로 진행할까요?"

On switch, stop here and invoke `tdd-subagent` with the requirements and the confirmed task list.

**Per-task commits.** Ask this together with the confirmation:

> "태스크마다 사이클이 끝나면 커밋할까요? (테스트·구현·리팩터링을 태스크당 커밋 하나로, `git add`·`git commit` 허용 목록 추가 포함) / 커밋하지 않고 진행할까요?"

On yes, add `Bash(git add:*)` and `Bash(git commit:*)` to `permissions.allow` in `.claude/settings.local.json`, and write `Commit per task: yes` in `roles/tdd-refactor.md` (Setup 6). On no, write `Commit per task: no`.

After this answer, do not ask again until Final Stage 2 — except the Tidy First commit question, when there are tidy items, and the escalations named under Lead Duties.

### 6. Context, Session, and Task Files

Write the files the teammates read when they start; they learn the session's facts and their own work from these files, not from messages.

**`{TDD_DIR}/context.md`** — the facts every teammate shares. Write it from the Setup 4 exploration, only what you verified this session:

```
# TDD Session Context

## Environment
- Project root: {absolute path}
- Commands: _workspace/tdd-agent-team/roles.env
- Production code: {source roots} — tdd-red never reads these
- Test code: {test roots} — tdd-green never writes these
- Test framework: {framework}

## Project Context (captured once — do NOT re-explore the codebase)
- Package / directory layout: {source & test packages}
- Test conventions: {only what existing tests or project instructions show — JUnit version, assertion style, naming, // arrange·act·assert, @Nested usage; none → "none — follow the test-writing rules"}
- Fixture pattern: {builder location & usage}
- Signatures RED may call: {ClassName → public method signatures, including the stubs from Stubs}
- Domain anchors: {aggregate/entity files + invariants that apply here}

## Domain Invariants
{list, numbered as in Setup 4}

## Workspace Rules
Others may have edited this workspace since this file was written. Never revert a change you didn't make.
Do not commit unless your role file says so. The lead and the user own the commit history.
Session bookkeeping — invariant IDs, task numbers, workspace paths, teammate names — never goes into production or test code.
SendMessage bodies are one line: READ <path> or READ <path>#<section>. Content goes in files.
Your role file is roles/{your name}.md. Never open another teammate's role file.
```

When filling it in:
- **Test conventions** — a project convention overrides the test-writing rules (naming included), so record one only when project instructions state it or at least three existing tests share it. Fewer tests show a habit, not a convention. None → `none`; RED and the `review-test` lens then hold to the guide.
- **Signatures RED may call** — RED's only window into production code. List every type, constructor, and method a test will touch with its exact signature; each one missing costs a `missing-stub` round trip.

**`{TDD_DIR}/roles/{name}.md`** — one per teammate, holding what only that role needs. Separate files keep RED from learning what GREEN builds against. The scope and pitfalls are the ones the user confirmed at Setup 5.

`roles/tdd-red.md`:
```
# Role context: tdd-red
- Test-writing rules: {SKILL_DIR}/../test-writing/SKILL.md
- Test roots: {test roots}
```

`roles/tdd-green.md`:
```
# Role context: tdd-green
- Implementation guide: {SKILL_DIR}/references/implementation.md
- In-scope files: {paths this session may modify}
- Out of scope: {what this task deliberately does not change}
- Known pitfalls — do NOT copy: {defect} → {what to do instead}
```

`roles/tdd-refactor.md`:
```
# Role context: tdd-refactor
- Refactoring guide: {SKILL_DIR}/references/refactoring.md
- Implementation guide: {SKILL_DIR}/references/implementation.md
- Test-writing rules: {SKILL_DIR}/../test-writing/SKILL.md
- In-scope files: {paths this session may modify}
- Out of scope: {what this task deliberately does not change}
- Known pitfalls — do NOT copy: {defect} → {what to do instead}
- Regression set (Tidy First safety net and final verification only — a task's refactor runs its `regression:` line): {test ids}
- Commit per task: {yes | no}
```

Write `{SKILL_DIR}` resolved to an absolute path, and `Read` each guide path once before writing it — a teammate that cannot read its guide stops and reports `blocked`.

**`{TDD_DIR}/session.md`** — the session's progress record, which outlives the team. You are its only writer:

```
# TDD Agent Team Session: {feature}
base: {commit from Setup 2, or none}

| # | task | task_id | status | note |
|---|------|---------|--------|------|
| 1 | {domain rule sentence} | {Task id} | PENDING | - |
```

`status`: `PENDING` | `DONE` | `BLOCKED`. Set `DONE` only when your Final Verification passes, never from a Task's status.

**`{TASK_DIR}/task.md`** — one task's spec, and where its results collect. Per task:

```
# Task {NN}: {domain rule sentence}
invariants: {INV-001, INV-004}
test_class: {FQCN}
scope_production: {relative paths this task changes}
regression: {test ids, or none}
scenarios:
- {scenario sentence}
```

- You write this header. Decide `test_class` and `scope_production` here, not in the teammates — the stubs, the per-method commands, and the task order all use them.
- `regression:` is `tdd-refactor`'s safety net for this task, beside its own methods. List the regression-set entries that exercise this task's `scope_production`; none → `none`. A class that is also any task's `test_class` goes in as its existing method ids — run whole, it would pick up another task's new, still-red tests.
- The teammates add their result sections below it: `## red-result`, `## gate`, `## missing-stub`, `## green-result`, `## compile-error`, `## refactor-result`, `## blocked`, each written by one teammate.
- `tidy.md` works the same way: you write the item and `## lead-check`, `tdd-refactor` writes `## tidy-result` and `## blocked`.
- RED sees `scope_production` as paths only and never opens those files.

## Running the Team

Everything a teammate needs is laid out before it exists: the files from Setup 6, the stubs, and the whole task list. Then the team is spawned and starts on its own — you send no first work.

### Prepare the Work

In this order:

1. **Tidy items, when there are any.** For each, in the order the requirements give, write the header of `{TDD_DIR}/tidy/{NN}/tidy.md`: the item as the requirements state it (what blocks the change, the restructuring, where the change lands), the in-scope files, and the safety-net test ids from Setup 4. `tdd-refactor` runs the safety net before restructuring; one already red comes back to you as `blocked`: stop and tell the user.
2. **Stubs — only when there are no tidy items.** With tidy items they wait for the Tidy gate (Tidy First below), so they land in the restructured code. See **Stubs**.
3. **The task list** — every Task of the session, wired with `blockedBy` (see **Creating Tasks**). Write each Task id into `session.md`.

### Spawn

```
Agent({ name: "tdd-red",      subagent_type: "devlife:tdd-red",      description: "TDD RED teammate",      prompt: "Start." })
Agent({ name: "tdd-green",    subagent_type: "devlife:tdd-green",    description: "TDD GREEN teammate",    prompt: "Start." })
Agent({ name: "tdd-refactor", subagent_type: "devlife:tdd-refactor", description: "TDD REFACTOR teammate", prompt: "Start." })
```

All three start now, `tdd-refactor` included — it owns the tidy items before the cycle and the refactors after each task, so there is no later point to spawn it.

- **The spawn prompt is just `Start.`** The role is in the definition; the session facts are in `context.md` and `roles/{name}.md`. Only reviewers get their lens and guide paths in the spawn prompt (Final Stage 2).
- **Keep the names exact** — teammates address each other by them.
- **Do not add a model**; teammates inherit the session's.

**First report.** `tdd-red`, `tdd-green`, and `tdd-refactor` each open with `READY`. Reviewers do not report. A teammate still silent past its first idle notification (it may lack `SendMessage`) — stop the team and tell the user.

**Teammates take their own work.** After `READY`, each teammate reads its files and takes its unblocked Tasks from `TaskList` in number order. A blocked Task is woken by the teammate whose work unblocked it, with a `READ` to its owner.

### Tidy First (only when there are tidy items)

Restructure before the requested change, and commit it separately so it never mixes with the feature work. `tdd-refactor` takes the `Tidy {NN}` Tasks in order; every cycle Task is blocked by the `Tidy gate` Task, which you own, so nothing else runs meanwhile — RED writing new tests against a structure being moved would collide.

**Tidy Check.** When the last item is done, `tdd-refactor` sends you that item's `READ {TDD_DIR}/tidy/{NN}/tidy.md#tidy-result`. Check every item's `tidy-result` section:
- the safety-net tests pass again;
- changed files are within the item's in-scope files;
- `test_changes` are mechanical only — no assertion, input, or test count changed.

Any failure → reopen its Task to `in_progress`, write the `## lead-check` section of `tidy/{NN}/tidy.md`, and send `tdd-refactor` its `READ`. After two bounces of the same item, ask the user.

When every item passed, ask once ← **user checkpoint (Tidy First only)**:

> "구조 정비(Tidy First)가 끝났습니다: {항목 요약}. 기존 테스트는 정비 전후 모두 통과합니다. 기능 작업과 섞이지 않도록 지금 `refactor` 커밋을 따로 합니다. 제가 커밋할까요, 직접 하실까요?"

- "제가 커밋" → stage just the files the tidy items changed and commit with `refactor: {summary}`.
- "직접 하실까요" → wait until the user says it is committed.

In a project that is not a git repository, skip the question.

Once the commit is handled, create the **Stubs**, set the `Tidy gate` Task `completed`, and send `tdd-red` `READ {TASK_DIR}/task.md` for the lowest-numbered Task it unblocked.

### Stubs

RED does not write production files, so create every production type and method the tests will call before RED starts.
- Use the signatures the requirements give, or derive them from the task scenarios.
- Bodies throw "not implemented yet" (`throw new UnsupportedOperationException("Not implemented yet")` in Java) — never a silent `null` or default, which would let a test pass without the behavior.
- Run `TEST_COMPILE_CMD` and confirm it passes.
- Add each stub's signature to `context.md` "Signatures RED may call".

After this, stubs are not yours: a stub RED finds missing mid-cycle it asks `tdd-green` for through the task's `missing-stub` section, and GREEN adds it and its signature.

### Creating Tasks

One Task per piece of work, and nothing in it but the pointer:

```
TaskCreate({ subject: "Task {NN}: {domain rule sentence}",
             description: "READ _workspace/tdd-agent-team/tasks/{NN}/task.md",
             metadata: { md: "_workspace/tdd-agent-team/tasks/{NN}/task.md" } })
TaskUpdate({ taskId, owner: "tdd-red", addBlockedBy: [ ... ] })
```

| Work | subject | Owner | `addBlockedBy` |
|---|---|---|---|
| `tidy/{NN}/tidy.md` | `Tidy {NN}: {summary}` | `tdd-refactor` | the previous `Tidy` |
| `tidy/` (no file — your gate) | `Tidy gate` | `team-lead` | every `Tidy` |
| `tasks/{NN}/task.md` | `Task {NN}: {domain rule sentence}` | `tdd-red` | the `Tidy gate`, if any, and the `Refactor` of every earlier task whose scope overlaps this one |
| `tasks/{NN}/task.md#green-result` | `Refactor {NN}` | `tdd-refactor` | `Task {NN}` |

- A task's cycle is two Tasks: `Task {NN}`, shared by RED and GREEN, then `Refactor {NN}`.
- RED sets `Task {NN}` `in_progress` and hands it over by changing `owner` to `tdd-green`; GREEN hands a refused one back to `tdd-red` and sets a finished one `completed`.
- Reviewers (they start from their spawn prompt) and `fixes.md` (one file for every owner's items) get no Task.

### Lead Duties During the Cycle

You are off the cycle's path. `tdd-red` → `tdd-green` → `tdd-refactor` → the next task's `tdd-red` all go direct, and nothing reaches you per task. After the cycle starts, the only messages you send a teammate are a `blocked` reply, the Tidy gate release, and — when everyone is idle — a lost handoff sent again. What reaches you, and what you do:

| Message | Your action |
|---|---|
| `READY` | Note that the teammate is up. Send nothing — it takes its own work |
| `READ {TDD_DIR}/tidy/{NN}/tidy.md#tidy-result` | The last Tidy item is done — Tidy Check and the Tidy First checkpoint (Tidy First above) |
| `READ …#blocked` / `READ {TDD_DIR}/blocked.md` | See **Handling `blocked`** below |
| `READ {TASK_DIR}/task.md#refactor-result` | The last `Refactor` is done — run the **Final Verification** |
| Idle notification | **Usually nothing — do not reply, do not inspect files.** Teammates go idle between every message. The exception is under **When everyone is idle** |

**Handling `blocked`** — by cause:
- A tidy item's safety net is red → stop and tell the user.
- A refactor's safety net was red before the refactor (`tdd-refactor` reverted its batch and is waiting) → tell the user.
- A missing fact → add it to `context.md` or the teammate's role file, and reply `READ {TASK_DIR}/task.md` (or the path it was stuck on).
- A file outside the task's scope is needed → widen `scope_production` in `task.md` and the `blockedBy` of later overlapping Tasks, or ask the user.
- RED's tests refused twice, or a design problem → handle the **Blocked Task** below, then ask the user.

**When everyone is idle** — all teammates idle while a `Refactor` Task is still open means a handoff was never sent: a result section is written, but its receiver never got the message. Find it by matching the open Tasks in `TaskList` against the result sections in each `task.md`, and send that `READ {TASK_DIR}/task.md#{section}` to the receiver yourself — for example `READ {TASK_DIR}/task.md#red-result` to `tdd-green`.

**Blocked Task.** A blocked task must not stop the rest:
1. Set its `Task {NN}` `completed` with `metadata: { blocked: true }` and its `Refactor {NN}` `completed` with `metadata: { skipped: true }`.
2. Mark it `BLOCKED` in `session.md`.
3. For every Task this just unblocked, send `tdd-red` `READ {TASK_DIR}/task.md`.
4. If that skip completed the last open `Refactor`, no teammate will report the end: go to the Final Verification yourself.
5. If the user decides to redo the task, create a new `Task {NN}` / `Refactor {NN}` pair (same `TASK_DIR`), update the header of `task.md` and clear its result sections, then send `tdd-red` `READ {TASK_DIR}/task.md`.

Update `session.md` after every message you act on. A Task's status can lag; the evidence is always the result sections in `task.md`.

**Turns are your cost** — every turn re-reads this whole conversation. Answer each message with the one action in the table and end the turn: no progress summaries, no re-reading files, no narration (mid-cycle, the user is waiting on the Final Review).

## Final Stages

When the last `Refactor` is done, read `{SKILL_DIR}/references/final-stages.md` and follow it: 1. Final Verification, 2. Parallel Final Review ← user checkpoint 2, 3. Summarize.
