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

**You are the team lead.** Setup (the initial stubs included), creating the Tasks, the Tidy Check, `blocked` reports and user escalations, the Final Verification, and merging the review are yours. When one teammate's output is another's input — a handoff, a stub request, a green task to refactor — the sender sends it straight to the receiver; you never relay it. After Setup you edit no source or test file.

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

1. `git rev-parse --git-common-dir` — prints the git directory whose `info/exclude` git reads (usually `.git`; in a worktree, the main repository's `.git`). If it fails, this is not a git repository; skip the next step.
2. `Read` `{git dir}/info/exclude`. If it has no `_workspace/tdd-agent-team/` line, add one with `Edit` (or `Write` the file if it does not exist).

Use `info/exclude`, never `.gitignore`.

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
- It runs in the final test and is the safety net of the Tidy First and refactor phases.

**Tidy First items** — work that changes structure without changing behavior, *before* the requested change, to make that change easier. It changes no behavior, so it can never be Red: each becomes a **tidy item**, not a task.
- Find such work in the requirements.
- Extracting an abstraction counts: it is extracted from the cases that already exist, and the new case it will receive is a task.
- For each, capture what blocks the change today, the restructuring to apply, and where the change lands afterwards. If the requirements leave one unsaid, ask at Setup 5 rather than guessing.
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
- the tidy items — marking which came from the requirements and which are your **candidates** for the user to approve or drop
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

**Is a team worth it?** With one or two tasks, the team's upkeep outweighs what it buys. In that case, ask this instead of the question above:

> "태스크가 {N}개라 팀을 유지하는 비용(팀원마다 가이드·문맥을 따로 읽고, 대기 알림마다 리드가 응답)이 얻는 이득보다 큽니다. `tdd-subagent`로 전환할까요? (확정한 태스크 목록을 그대로 넘깁니다) / 팀으로 그대로 진행할까요?"

On switch, stop here and invoke `tdd-subagent` with the requirements and the confirmed task list.

After this answer, do not ask again until Final Stage 2 — except the Tidy First commit question, when there are tidy items, and the escalations named under Lead Duties.

### 6. Context, Session, and Task Files

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
{list, IDs verbatim}

## Workspace Rules
Others may have edited this workspace since this file was written. Never revert a change you didn't make.
Do not commit. The lead and the user own the commit history.
Invariant IDs are session bookkeeping — never write them into production or test code.
SendMessage bodies are one line: READ <path> or READ <path>#<section>. Content goes in files.
Your role file is roles/{your name}.md. Never open another teammate's role file.
```

**`{TDD_DIR}/roles/{name}.md`** — one per teammate, holding what only that role needs. The definitions read their own file at start, so the spawn prompt carries nothing; keeping each role's facts in its own file keeps RED from learning what GREEN builds against. The scope and pitfalls are the ones the user confirmed at Setup 5.

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
- Regression set: {test ids}
```

Write `{SKILL_DIR}` resolved to an absolute path, and `Read` each guide path once before writing it — a teammate that cannot read its guide stops and reports `blocked`.

**Test conventions are observed, never invented.** A project convention overrides the test-writing rules (naming included), so record only what the existing tests or project instructions actually show. With no existing tests, there is no project convention — do not make one up; RED and the `review-test` lens then hold to the guide.

**"Signatures RED may call" is RED's only window into production code** — its definition forbids reading production files. Every type, constructor, and method a test will touch must be listed with its exact signature. A missing signature costs a `missing-stub` round trip per task.

**`{TDD_DIR}/session.md`** — you are its only writer:

```
# TDD Agent Team Session: {feature}

| # | task | task_id | status | note |
|---|------|---------|--------|------|
| 1 | {domain rule sentence} | {Task id} | PENDING | - |
```

`status`: `PENDING` | `DONE` | `BLOCKED`. `session.md` stays alongside the Tasks — it is the session's record after the team is gone — and `DONE` is set only by your Final Verification, never by a Task's status alone.

**`{TASK_DIR}/task.md`** per task:

```
# Task {NN}: {domain rule sentence}
invariants: {INV-001, INV-004}
test_class: {FQCN}
scope_production: {relative paths this task changes}
scenarios:
- {scenario sentence}
```

You write only this header. The teammates add their result sections below it — `## red-result`, `## gate`, `## missing-stub`, `## green-result`, `## refactor-result`, `## blocked` — each written by one teammate. The same holds for `tidy.md`: you write the item and `## lead-check`, `tdd-refactor` writes `## tidy-result` and `## blocked`.

Decide `test_class` and `scope_production` here, not in the teammates — the stubs, the per-method commands, and the task order all need them. RED sees `scope_production` as paths only and never opens those files.

## Running the Team

Everything a teammate needs is laid out before it exists: the files from Setup 6, the stubs, and the whole task list. Then the team is spawned and starts on its own — you send no first work.

### Prepare the Work

In this order:

1. **Tidy items, when there are any.** For each, in the order the document gives:
   - **Safety net.** Pick it: the regression set and every existing test class that exercises the files the item touches. Do not run it — `tdd-refactor` runs it before restructuring. A safety net that is already red comes back to you as a `blocked` report: stop and tell the user, since a red baseline cannot prove the restructuring preserved behavior.
   - **Empty safety net.** If no existing test exercises the files the item touches, the restructuring has nothing to prove it preserved behavior. Stop before writing `tidy.md` and ask:

     > "정비 항목 {NN}({요약})이 건드리는 {파일}을 검증하는 기존 테스트가 없습니다. 정비 후 동작이 그대로인지 확인할 수 없습니다. 테스트를 직접 추가한 뒤 계속할까요, 안전망 없이 정비할까요, 이 항목을 뺄까요?"

     Keep the item only on "테스트를 직접 추가한 뒤 계속" (after the user says the tests are in — add them to the safety net) or "안전망 없이 정비". On "이 항목을 뺄까요", drop it from the tidy items.
   - **Write `{TDD_DIR}/tidy/{NN}/tidy.md`** — the item as the document states it (what blocks the change, the restructuring, where the change lands), the in-scope files, and the safety-net test ids.
2. **Stubs — only when there are no tidy items.** With tidy items they wait for the Tidy gate (Tidy First below), so they land in the restructured code. See **Stubs**.
3. **The task list** — every Task of the session, wired with `blockedBy` (see **Creating Tasks**). Write each Task id into `session.md`.

### Spawn

```
Agent({ name: "tdd-red",      subagent_type: "devlife:tdd-red",      description: "TDD RED teammate",      prompt: "Start." })
Agent({ name: "tdd-green",    subagent_type: "devlife:tdd-green",    description: "TDD GREEN teammate",    prompt: "Start." })
Agent({ name: "tdd-refactor", subagent_type: "devlife:tdd-refactor", description: "TDD REFACTOR teammate", prompt: "Start." })
```

All three start now, `tdd-refactor` included — it owns the Tidy items at the front and the refactoring at the back, and nobody is there to spawn it in between.

The role is in the definition and the session facts are in files — `context.md` for everyone, `roles/{name}.md` for each teammate — so a teammate's spawn prompt is just `Start.`. Each rulebook lives in one file that its writer and its reviewer both read: the `test-writing` skill for RED and the `review-test` lens, `references/implementation.md` for GREEN (and as the floor for `tdd-refactor`), `references/refactoring.md` for `tdd-refactor`; the `review-design` lens reads the last two. Reviewers still get their lens and guide paths in the spawn prompt (Final Stage 2). Teammates address each other by these names, so keep them exact. Do not add a model; teammates inherit the session's.

**First report.** `tdd-red`, `tdd-green`, and `tdd-refactor` each open with `READY`. Reviewers do not report: they live for one review and start from their spawn prompt. A teammate without `SendMessage` cannot send that report, so a teammate silent past its first idle notification counts as missing it — stop the team and tell the user rather than letting the cycle start lame.

**Teammates take their own work.** After `READY`, each teammate reads its files and takes its unblocked Tasks from `TaskList` in number order. You never send first work. A blocked Task becomes theirs when the teammate whose work unblocked it sends them `READ` of the Task's file.

### Tidy First (only when there are tidy items)

Structure first, behavior second, in separate commits — the CLAUDE.md Tidy First rule. `tdd-refactor` takes the `Tidy {NN}` Tasks in order; every cycle Task is blocked by the `Tidy gate` Task, which you own, so nothing else runs meanwhile — RED writing new tests against a structure being moved would collide.

- **Test-side follow-up — not yours.** If tests must change mechanically (a moved class, a renamed method), `tdd-refactor` fixes them itself and records them under `test_changes` — assertions untouched.
- **Tidy Check.** When the last item is done, `tdd-refactor` sends you `READ {TDD_DIR}/tidy/tidy-finished.md`. For every item's `tidy-result` section: the safety-net tests pass again; changed files are within the item's in-scope files; `test_changes` are mechanical only — no assertion, input, or test count changed. Any failure → write the `## lead-check` section of `tidy/{NN}/tidy.md` and send it to `tdd-refactor`, reopening its Task to `in_progress` first; after two bounces, ask the user.

When every item passed, ask once ← **user checkpoint (Tidy First only)**:

> "구조 정비(Tidy First)가 끝났습니다: {항목 요약}. 기존 테스트는 정비 전후 모두 통과합니다. 기능 작업과 섞이지 않도록 지금 `refactor` 커밋을 따로 해 두는 게 좋습니다. 제가 커밋할까요, 직접 하실까요, 커밋 없이 진행할까요?"

Commit only on "제가 커밋" — stage just the files the tidy items changed, message `refactor: {summary}`. Then create the **Stubs**, set the `Tidy gate` Task `completed`, and send `tdd-red` `READ {TASK_DIR}/task.md` for the lowest-numbered Task it unblocked.

### Stubs

RED does not write production files, so every production type and method the tests will call must exist before RED starts. Create them from the signatures the document gives (or the task scenarios): bodies `throw new UnsupportedOperationException("Not implemented yet")` — never a silent `null` or default. Then run `TEST_COMPILE_CMD` and confirm it passes. Add each stub's signature to `context.md` "Signatures RED may call".

After this, stubs are not yours: a stub RED finds missing mid-cycle it asks `tdd-green` for through the task's `missing-stub` section, and GREEN adds it and its signature.

### Creating Tasks

One Task per work file, and nothing in it but the pointer:

```
TaskCreate({ subject: "Task {NN}: {domain rule sentence}",
             description: "READ _workspace/tdd-agent-team/tasks/{NN}/task.md",
             metadata: { md: "_workspace/tdd-agent-team/tasks/{NN}/task.md" } })
TaskUpdate({ taskId, owner: "tdd-red", addBlockedBy: [ ... ] })
```

| Work file | subject | Owner | `addBlockedBy` |
|---|---|---|---|
| `tidy/{NN}/tidy.md` | `Tidy {NN}: {summary}` | `tdd-refactor` | the previous `Tidy` |
| `tidy/` (no file — your gate) | `Tidy gate` | `team-lead` | every `Tidy` |
| `tasks/{NN}/task.md` | `Task {NN}: {domain rule sentence}` | `tdd-red` | the `Tidy gate`, if any, and the `Refactor` of every earlier task whose scope overlaps this one |
| `tasks/{NN}/task.md#green-result` | `Refactor {NN}` | `tdd-refactor` | `Task {NN}` |

A task's cycle is two Tasks: `Task {NN}`, shared by RED and GREEN, then `Refactor {NN}`. `Task {NN}`: RED sets it `in_progress` and hands it over by changing `owner` to `tdd-green`; GREEN hands a refused one back to `tdd-red` and sets a finished one `completed`. Each owner change comes with the `READ` message that wakes the new owner. Reviewers get no Task — they start from their spawn prompt — and neither does `fixes.md`, which holds every owner's items in one file.

### Lead Duties During the Cycle

You are off the cycle's path. RED → GREEN → `tdd-refactor` → the next task's RED all go direct, and nothing reaches you per task. After the cycle starts, the only messages you send a teammate are a `blocked` reply, the Tidy gate release, and — when everyone is idle — an order to resend a handoff. What reaches you, and what you do:

| Message | Your action |
|---|---|
| `READY` | Note that the teammate is up. Send nothing — it takes its own work |
| `READ {TDD_DIR}/tidy/tidy-finished.md` | Tidy Check and the Tidy First checkpoint (Tidy First above) |
| `READ {TASK_DIR}/task.md#blocked` / `READ {TDD_DIR}/tidy/{NN}/tidy.md#blocked` / `READ {TDD_DIR}/blocked.md` | A tidy item's safety net is red → stop and tell the user (Prepare the Work). A missing fact → add it to `context.md` or the teammate's role file and reply `READ {TASK_DIR}/task.md` (or the path it was stuck on). A file outside the task's scope is needed → widen `scope_production` in `task.md` and the `blockedBy` of later overlapping Tasks, or ask the user. RED's tests refused twice, or a design problem → **Blocked Task** below, then ask the user — this is the one mid-cycle escalation |
| `READ {TDD_DIR}/cycle-finished.md` | Every `Refactor` is done — run the **Final Verification** |
| Idle notification | **Usually nothing — do not reply, do not inspect files.** Teammates go idle between every message, so idle is normal. Act only when *all* teammates are idle and `cycle-finished.md` has not arrived: then find the handoff that was never sent — from `TaskList` (an open Task whose owner has no message to act on), checked against the result files under `tasks/` — and tell **the sender** to send it again (`READ {TASK_DIR}/task.md` to that teammate). Never send the handoff yourself — the sender owns the file it points to |

**Blocked Task.** A blocked task must not stop the rest. Set its `Task {NN}` `completed` with `metadata: { blocked: true }` and its `Refactor {NN}` `completed` with `metadata: { skipped: true }`, mark it `BLOCKED` in `session.md`, and send `tdd-red` `READ {TASK_DIR'}/task.md` for every Task this just unblocked — a status change wakes no one. If that skip completed the last open `Refactor`, no teammate will send `cycle-finished.md`: write it yourself and go to the Final Verification. Once the user decides, a task to be redone gets a new `Task {NN}` / `Refactor {NN}` pair (same `TASK_DIR`, `task.md` updated), and you send `READ {TASK_DIR}/task.md` to `tdd-red`.

Update `session.md` after every message you act on. It is the record of progress that outlives the team; the Tasks show live status, but a Task's status can lag and is never the evidence — the result files are.

**Every turn you take re-reads this whole conversation, so turns are your cost.** Answer the messages in the table above with the one action listed and end the turn; do not summarize progress, re-read files, or narrate between messages. The user is not waiting on you mid-cycle — they are waiting on the Final Review.

The cycle is finished when `cycle-finished.md` arrives — every `Refactor` Task is `completed`.

## Final Stages

### 1. Final Verification

Nothing outside the teammates enforces the role boundaries, so the finished work gets mechanical checks from you — once, after every task's refactor, not per task. For each task that is not `BLOCKED`, the `green-result` and `refactor-result` sections of its `task.md` carry what checks 1–4 need: read that file and nothing else — no `ls`, never `cat` whole files into your context.

| Check | How (per task) | If it fails |
|---|---|---|
| 1. Red-first evidence | `green-result` has a `red_check_log:` line naming `{TASK_DIR}/red-check.log` | The code is already built, so red can no longer be proven — not a fix item. Note `red-first unverified` in the task's `session.md` row; the `review-test` lens reports it |
| 2. Scope | the `files_modified` lines of `green-result` and `refactor-result` name only paths in the task's scope (`scope_production` and `test_class` in `task.md`) | A fix item for whoever touched the path: revert it, or explain in `blocked.md` why the task needs it |
| 3. Refactor record | `refactor-result`: a technique for each `production_changes` line; one `responsibilities` line per class, and a line naming two responsibilities has a matching Extract Class or a `deferred` entry. You check that the record is there, not whether the design is right — `review-design` judges that | A fix item for `tdd-refactor` |
| 4. Tests unchanged in what they check | `refactor-result`: every `test_changes` line changes no assertion, no input, and no test count | A fix item for `tdd-refactor` — undo that test change |
| 5. Really passes, together | below | A fix item for the owner of the failing behavior |

**Check 5 — one run for the whole session.** A later task's change can break an earlier task's methods, so run every session method in one invocation — all `test_methods` from every `red-result`, plus the regression set — with `TEST_METHOD_RUNNER` and one `TEST_METHOD_CMD` per method. Collect the ids from the `red-result` sections (for a method `test_changes` renamed, use the new id), then **write them out literally in the command**: `{TEST_METHOD_RUNNER} {id1} {id2} …`. Never pass them through a shell variable or `$(…)` — a quoted variable turns the whole list into one argument, and the runner reports a single nonexistent test instead of running yours. Redirect the output to `{TDD_DIR}/final-test.log` and read only the counts and failing names. The executed count must equal the number of ids.

**Already-passing tests.** A `red-result` may list `already_passing` methods — tests that passed before GREEN touched anything, kept because deleting a test is your decision, not RED's. Decide for each: keep it as coverage, or delete it as redundant (a fix item for `tdd-red` naming the id). Note the decision in `session.md`.

**Collect `deferred`.** Copy every `deferred` line other than `none` from the `refactor-result` sections into `{TDD_DIR}/deferred.md`, one line each, prefixed with the task number — the `review-design` lens judges them. If every line is `none`, write no `deferred.md`.

**Failures go back to their owners.** Write `{TDD_DIR}/fixes.md` with the failures split by owner — missing or wrong behavior to `tdd-green`, structure and refactor records to `tdd-refactor`, tests to `tdd-red` — and send each owner its `READ`. When all have reported, run checks 2–5 again for the changed tasks, and check 5 for the whole session. At most 2 rounds, then ask the user. Every task that passes is `DONE` in `session.md`.

### 2. Parallel Final Review ← user checkpoint 2

Build the diff into a file first — it must never pass through your context. One simple command per step:

1. `git diff > _workspace/tdd-agent-team/branch-diff.md` — changes to tracked files.
2. `git ls-files --others --exclude-standard` — the files this session created. Skip build output it lists (`__pycache__/`, `build/`, `target/`, `node_modules/`).
3. For each remaining file, one command: `git diff --no-index /dev/null <file> >> _workspace/tdd-agent-team/branch-diff.md` — new files are untracked, so step 1 alone would hand the reviewers a diff with the new test class missing.
4. `wc -l _workspace/tdd-agent-team/branch-diff.md` — confirm it is not empty.

Spawn three reviewers from the one definition, each owning one lens:

```
Agent({ name: "review-domain", subagent_type: "devlife:tdd-reviewer", description: "Final review: domain",
        prompt: "You are review-domain — the domain lens. TDD_DIR={TDD_DIR}" })
Agent({ name: "review-test",   subagent_type: "devlife:tdd-reviewer", description: "Final review: test",
        prompt: "You are review-test — the test lens. TDD_DIR={TDD_DIR}. TEST_GUIDE={SKILL_DIR}/../test-writing/SKILL.md" })
Agent({ name: "review-design", subagent_type: "devlife:tdd-reviewer", description: "Final review: design",
        prompt: "You are review-design — the design lens. TDD_DIR={TDD_DIR}. IMPL_GUIDE={SKILL_DIR}/references/implementation.md. REFACTOR_GUIDE={SKILL_DIR}/references/refactoring.md" })
```

Each writes `{TDD_DIR}/final-review-{lens}.md`. A reviewer with only Minor findings reports to you at once; one with Critical or Important findings first sends its report to the other two, who rebut **those findings only** in `{TDD_DIR}/rebuttal-{from}-to-{to}.md`, revises once, then reports. The rebuttal round is the slow part of the review — it waits on the slowest reviewer twice — so it runs only where a must-fix finding is at stake. Either way you receive `READ {TDD_DIR}/final-review-{lens}.md` from all three. When all three have reported, merge them into `{TDD_DIR}/final-review.md`: drop findings a rebuttal refuted, keep the rest with their severity. Then send each reviewer a shutdown request right away — their work is done, and nothing later needs them.

Show the user the findings and ask — always, unless there are none at all. **The findings go in the same message as the question**, never in an earlier one that the question points back to ("위의 …"): the reviewers' shutdown notices print between your messages and push an earlier list off the screen.

- **Critical or Important findings** — list them, then any Minor findings below them, one line each, numbered in the same sequence:

  > "최종 리뷰 결과입니다: {Critical/Important 목록} / Minor: {번호. 한 줄 요약}. 어떤 항목을 반영할까요? (전부 / 번호 선택 / 반영 안 함)"

- **Only Minor findings** — ask briefly, one line per finding:

  > "최종 리뷰에서 Minor {N}건이 나왔습니다: {번호. 한 줄 요약}. 반영할까요? (전부 / 번호 선택 / 반영 안 함)"

- **No findings** — skip the question and go to Summarize.

Keep `tdd-red`, `tdd-green`, and `tdd-refactor` running until the answer is in — any of them may own a fix. Apply only what is approved. Write `{TDD_DIR}/fixes.md` with the approved items split by owner — test changes to `tdd-red`, design and readability findings (`review-design`) to `tdd-refactor` — and send each owner its `READ`. Then re-run Final Verification check 5 once.

**A behavior fix starts Red, like every task.** A finding about missing or wrong behavior has no failing test yet, so it is never handed straight to GREEN. List it twice in `fixes.md`: under `tdd-red` as the failing test to write (the domain sentence and the input), and under `tdd-green` as "make RED's new tests pass". Send `READ` only to `tdd-red` (and `tdd-refactor`, if it has items) — RED hands the file on to GREEN when its tests are red, and GREEN reports to you. Everything stays in `fixes.md`: each teammate appends its own section, and GREEN's red check goes to `{TDD_DIR}/fix-red-check.log`. Make no other files for this.

**Deleting a test is your decision, never RED's.** When a behavior fix leaves a test obsolete — it checks behavior the fix removes or replaces — name that test id in `tdd-red`'s items in `fixes.md`, with the reason. RED deletes only the tests listed there.

**Release teammates as soon as their last work is in.** A teammate with no fixes assigned gets its shutdown request now; one with fixes gets it the moment its fix report arrives. If the user approved nothing, shut down `tdd-red`, `tdd-green`, and `tdd-refactor` immediately.

### 3. Summarize

Send a shutdown request to any teammate not yet released, then print the summary **without waiting for shutdown acknowledgements** — a teammate finishes its current turn before it exits, and the harness completes the shutdown on its own:

```
── TDD Agent Team Session Complete ──
Tasks:   {DONE}/{total} ({BLOCKED} blocked)
Tests:   {N} passed, 0 failed
Files:   {changed files}
Review:  {applied}/{proposed} findings applied
Artifacts: _workspace/tdd-agent-team/
```

Append `session: COMPLETE` as the last line of `session.md` — it tells the next run this session finished, so Setup 1 archives it without asking. Leave `_workspace/tdd-agent-team/` in place otherwise — it is excluded from git and is the session's debugging record.
