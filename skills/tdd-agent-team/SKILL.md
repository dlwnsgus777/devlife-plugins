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

Run Red-Green-Refactor with an agent team: a `tdd-red` teammate writes failing tests task after task, a `tdd-green` teammate makes them pass with the minimum code, and the two hand work to each other directly. Tasks whose scopes do not overlap run in parallel; a task that touches the same files as an earlier one waits for it. A `tdd-refactor` teammate owns structure and quality: it applies the plan's Tidy First items before the cycle and refactors GREEN's minimal code after it.

## Execution Rules

**You are the team lead: you integrate results and handle errors.** Setup (the initial stubs included), creating the Tasks, the verification gates (Task Check, Tidy Check, Refactor Check), `blocked.md` and user escalations, the Final Test, and merging the review are yours. Communication is not: when one teammate's output is another's input — a handoff, a stub request, a list of test edits — the sender sends it straight to the receiver. Never relay a file from one teammate to another. After Setup you edit no source or test file.

- Respect system, developer, and project `CLAUDE.md` instructions above this skill.
- The user is asked at task confirmation (Setup 5), after the Tidy First phase when there is one (to commit it separately), and before applying final-review fixes (Final Stage 4). Project instructions that ask for feedback after each stage are honored at these two points — the cycle runs in parallel and has no stage boundary to pause at.
- **Files through file tools, shell commands kept simple — yours too.** Create files with `Write`, change them with `Edit` (a `session.md` status flip is one `Edit`), read them with `Read`. Use Bash only to run commands, one simple command at a time: no `cd …;` prefix, no heredocs, no `sed -i`, no loops, no `$(…)` or `$variables`, no brace expansion. The permission checker cannot analyze those, so each one stops the session on a prompt — the `_workspace/tdd-agent-team/*.md` artifacts pass without one only when written through the file tools.
- **Java is the example, not the target.** Java/JUnit constructs in this skill (`@DisplayName`, `@Nested`, `UnsupportedOperationException`, Gradle commands) are examples. In another stack, use that language's equivalent everywhere — in the files you write and on the screens you show the user (the Other Stacks table in the `test-writing` skill maps the test constructs).
- **Teammate content travels in files, never in messages.** Every `SendMessage` body — yours and every teammate's — is one line: `READ <path>`. The one exception is a teammate's first report, `READY`. The file holds the substance. A message with prose in it skips the checks the files carry and leaks context the reader was not meant to have.
- **The shared task list is required.** The team runs on the Task tools (`TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate`), checked in Setup 0. Every work file handed to a teammate (`tidy/{NN}/tidy.md`, `tasks/{NN}/task.md`, `refactor.md`, `test-refactor.md`) gets exactly one Task, and its `description` is one line: `READ <path>`. The content stays in the file, as with messages.
- **A Task changes owner; a message wakes the new owner.** Changing a Task's `owner` notifies no one, so every handoff is still a `SendMessage READ <path>` to the receiver. The Task records who holds the work; the message moves it.

### Teammate definitions

Each role is a **plugin agent** of the `devlife` plugin — its definition lives in the plugin's `agents/` directory, and the plugin install registers it:

| Teammate name | `subagent_type` | Source | `tools` |
|---|---|---|---|
| `tdd-red` | `devlife:tdd-red` | `{PLUGIN_ROOT}/agents/tdd-red.md` | Read, Write, Edit, Bash, SendMessage |
| `tdd-green` | `devlife:tdd-green` | `{PLUGIN_ROOT}/agents/tdd-green.md` | Read, Write, Edit, Bash, SendMessage |
| `tdd-refactor` | `devlife:tdd-refactor` | `{PLUGIN_ROOT}/agents/tdd-refactor.md` | Read, Write, Edit, Bash, SendMessage |
| `review-domain` / `review-test` / `review-design` | `devlife:tdd-reviewer` | `{PLUGIN_ROOT}/agents/tdd-reviewer.md` | Read, Write, Bash, SendMessage — no `Edit` |

`SKILL_DIR` is this file's parent directory; `PLUGIN_ROOT` is two levels above it (`{SKILL_DIR}/../..`). The definition body becomes the teammate's system prompt and its `tools` list is enforced, so the role is in force from its first turn. Agent teams accept teammate definitions from the plugin scope, so nothing is copied anywhere: spawn with the plugin name in the `subagent_type` column. The teammate's `name` — what everyone addresses with `SendMessage` — stays the bare role name.

**What is and is not enforced.** The tool lists are enforced: reviewers have no `Edit`. Everything finer is the teammates' own discipline — `tools` cannot limit paths, and RED and GREEN both need `Bash` to run tests. So RED not reading production code, GREEN and `tdd-refactor` not editing tests, GREEN not refactoring, and GREEN's red check before implementing all rest on the definitions' instructions. The final test and the `review-test` lens are the independent checks that catch a lapse.

## Setup

### 0. Agent Teams Enabled?

Agent teams need `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Check the **effective** value with `printenv CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` (empty output means unset) — not `echo "$…"`, whose variable the permission checker cannot analyze, so it stops the session on a prompt. Settings files' `env` blocks are applied to the session, and project or local settings override `~/.claude/settings.json`, so reading the user file alone gives the wrong answer. If it is not `1`:

> "이 스킬은 Claude Code agent teams 기능이 필요한데 지금 꺼져 있습니다(`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). `~/.claude/settings.json`의 `env`에 `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"`을 넣어드릴까요? 켜면 이름을 붙인 서브에이전트가 팀원으로 실행되는 등 다른 작업에도 영향이 있습니다. 원치 않으시면 `tdd-subagent`로 진행할 수 있습니다."

Edit the file only on an explicit yes. On no, stop and point to `tdd-subagent`. Agent teams also need an interactive session — in `-p` / SDK mode, teammates never spawn; stop and say so.

**Teammate definitions present?** Check that `devlife:tdd-red`, `devlife:tdd-green`, `devlife:tdd-refactor`, and `devlife:tdd-reviewer` are among the agent types your `Agent` tool lists. If any is missing, the `devlife` plugin is not installed or is out of date — the skill alone (a copy under `~/.claude/skills/`) does not carry the definitions. Stop and say so:

> "팀원 정의(`devlife:tdd-*` 에이전트)를 찾을 수 없습니다. `devlife` 플러그인을 설치하거나 최신으로 갱신한 뒤 다시 실행해주세요."

**Task tools available?** Load `TaskCreate`, `TaskGet`, `TaskList`, and `TaskUpdate` with `ToolSearch`. If they load, continue. They are on by default only on some models; on others they need `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`. If they do not load, ask:

> "이 세션에는 공유 작업 목록(Task 도구)이 없습니다. `~/.claude/settings.json`의 `env`에 `"CLAUDE_CODE_ENABLE_TODO_TOOLS": "1"`을 넣어드릴까요? 이 스킬은 공유 작업 목록 없이는 진행할 수 없습니다."

On yes, add it, then load the tools again — a settings `env` change usually applies to the running session. Only if they are still missing, tell the user to restart Claude Code and run the skill again, and stop. On no, stop and point to `tdd-subagent`.

### 1. Previous Session?

If `_workspace/tdd-agent-team/session.md` exists, teammates from that session are gone — agent teams cannot restore them.

- **It ends with `session: COMPLETE`** — that session finished (Summarize wrote the line), so there is nothing to decide. Archive it without asking and say so in one line:

  > "이전 세션 기록을 `_workspace/tdd-agent-team/archive-{YYYYMMDD-HHMMSS}/`에 보관했습니다."

- **It does not** — the session stopped partway, and the user may want to look at what was left undone first. Ask:

  > "이전 tdd-agent-team 세션 기록이 있습니다({완료}/{전체} 태스크 완료). 팀원은 복원되지 않아 이어서 진행할 수 없습니다. 기록을 보관하고 새로 시작할까요?"

To archive, move everything in `_workspace/tdd-agent-team/` except earlier `archive-*/` folders into `_workspace/tdd-agent-team/archive-{YYYYMMDD-HHMMSS}/`. Never delete an archive.

### 2. Artifact Directory

- `TDD_DIR` = `_workspace/tdd-agent-team` (relative to the project root, where this skill runs)
- `TASK_DIR` = `{TDD_DIR}/tasks/{NN}` — `NN` zero-padded to two digits

1. `mkdir -p _workspace/tdd-agent-team/tasks`
2. `git rev-parse --git-dir` — prints the git directory (usually `.git`). If it fails, this is not a git repository; skip step 3.
3. `Read` `{git dir}/info/exclude`. If it has no `_workspace/tdd-agent-team/` line, add one with `Edit` (or `Write` the file if it does not exist).

Use `.git/info/exclude`, never `.gitignore`.

Create only `tasks/` here. Each `tasks/{NN}/` comes into existence when you `Write` its `task.md` (Setup 6) — never `mkdir` them ahead, since the task count is not settled until Setup 5.

### 3. Detect Environment and Write `roles.env`

From the build files, determine the test commands, then write `{TDD_DIR}/roles.env`. The teammates read their commands from it:

```sh
TEST_COMPILE_CMD='./gradlew compileTestJava --offline'
TEST_METHOD_RUNNER='./gradlew test --offline'
TEST_METHOD_CMD='--tests "{M}"'
```

- **Every test run in this skill is per method.** A test class holds earlier tasks' methods, and tasks running in parallel each have their own; running exactly the ids of the work at hand keeps every result about that work alone. `TEST_METHOD_RUNNER` is the fixed part; `TEST_METHOD_CMD` is the per-method argument with `{M}` standing for one `FQCN.method`, repeated once per method. Maven: runner `mvn -o test`, arg `-Dtest="{M}"` with `{M}` as `Class#method`. jest/vitest: runner `npx vitest run`, arg `-t "{M}"` with the test name.
- `TEST_COMPILE_CMD` compiles test sources without running them. No compile step (plain JS) → `true`.

Then offer once to pre-approve the two test commands, since every teammate runs them dozens of times and each unapproved run can stop the team on a permission prompt:

> "팀원이 테스트 명령을 수십 번 실행합니다. `{TEST_COMPILE_CMD}`와 `{TEST_METHOD_RUNNER}`를 이 프로젝트의 `.claude/settings.local.json` 허용 목록에 추가할까요? (안 하면 실행 중 권한 확인이 자주 뜰 수 있습니다)"

On yes, add `Bash({TEST_COMPILE_CMD}:*)` and `Bash({TEST_METHOD_RUNNER}:*)` to `permissions.allow` in `.claude/settings.local.json`, creating the file if needed and leaving existing entries untouched. On no, continue.

### 4. Invariants, Scope, and Tasks

Everything below comes from the requirements document **when it says so, and from your own exploration when it does not**. A plan-creator document answers most of it; a ticket or a spoken description answers little. Never leave a gap empty or fill it by guessing — derive it, then show it at Setup 5 for confirmation.

**Explore once, here.** Read the feature area a single time — the code the change will modify, its callers, its existing tests. This one pass feeds the invariants, the scope, the regression set, the tidy candidates, and later `context.md`; do not re-explore for each.

**Invariants — requirements document first, code second.** With a spec, plan, or ticket, derive invariants from it and adopt any IDs (`INV-001`, …) verbatim; if it gives none, number them yourself from `INV-001`. With nothing at all, ask "구현할 기능의 요구사항이나 티켓 내용을 공유해주시겠어요?" and wait. Only then add structural constraints the code shows and the document omitted. Write each as a declarative sentence about what must be true.

**Scope.** In-scope files, out-of-scope items, and known pitfalls (defects in the code the change imitates, each with what to do instead) — take them from the document if it lists them; otherwise set them from the tasks and the exploration. In-scope files are what the Task Check and the Refactor Check hold the team to, so they must be concrete paths. They go to GREEN's and `tdd-refactor`'s role files (Setup 6), not to the shared `context.md` — RED has no use for them.

**Regression set.** The existing tests that must keep passing: those the document says already cover part of the requirement (plan-creator tags them `[REGRESSION]`), **plus every existing test class that exercises a file in scope** — find these in the exploration, whatever the document says. The regression set runs in the final test and is the safety net of the Tidy First and refactor phases; without the second half, a refactor that breaks existing behavior has nothing to catch it.

**Tidy First items.** Read the requirements document for work that must change structure without changing behavior, *before* the requested change, to make that change easier — whatever the document calls it (Tidy First, refactor first, 코드 정비) and wherever it puts it. Extracting an abstraction counts: it is extracted from the cases that already exist, and the new case it will receive is a task. Each such item becomes a **tidy item**, not a task — it changes no behavior, so it can never be Red. Recognize items by what they ask, not by their position in the document (a plan-creator document, for example, keeps them in its Section 0 and orders them first in its implementation steps).

For each tidy item, capture what blocks the change today, the restructuring to apply, and where the change lands afterwards. If the document leaves one of these unsaid, ask in Setup 5 rather than guessing.

**No tidy items in the document?** Then look for them yourself: read `{SKILL_DIR}/references/tidy-first-scan.md` and apply it to the code in scope. What it finds are **candidates** — shown at Setup 5, and only the ones the user approves become tidy items. If the document already names tidy items, skip the scan; do not second-guess a plan that made this decision.

**Tasks.** Adopt the document's ordered task list if it has one; otherwise decompose the invariants yourself. Items already covered by existing tests are not tasks — they belong to the regression set. Name each task as a domain rule sentence; RED turns it into `@DisplayName`.

- **Batch scenarios that share one implementation change** into one task — one guard clause, one branch, one small function. A task maps to a unit of implementation work, not to a test method.
- **Coverage floor, never a cap:** per invariant, the case that violates it, the nearest case that satisfies it, and every state the rule itself names; plus one happy path per touched class. An edge case with no test is an unbuilt behavior, because GREEN builds exactly what the tests demand.
- **Before presenting, name the production change behind every task.** "Nothing — it already works" or "an earlier task already makes it pass" means it is coverage, not a task: merge its scenarios into the task that builds the logic. In this skill a task that cannot be Red is not just wasted — GREEN's red check refuses it, and RED stalls on it.
- **Give every task a scope, and order tasks so dependencies come first.** A task's scope is the production files it will change (`scope_production`) and its `test_class`. Two tasks **overlap** when they share a production file or a test class. Overlapping tasks run one after the other in number order — the later one waits for the earlier one (Creating Tasks), so it starts from finished code and two teammates never edit the same file. Tasks that do not overlap run in parallel. So number a task after every task it needs, and if a task needs another one's code without sharing a file, put that file in both scopes so the order holds.

### 5. Confirm Tasks ← user checkpoint 1

Present together, and wait for confirmation: the tidy items — marking which came from the document and which are your **candidates** for the user to approve or drop — the in-scope files, the regression set, the invariants, and the tasks with their test names and scopes:

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

**Is a team worth it?** With one or two tasks, the team's upkeep — every teammate reading its guide, `context.md`, and role file, every idle notification costing you a turn — outweighs what it buys. In that case, ask this instead of the question above:

> "태스크가 {N}개라 팀을 유지하는 비용(팀원마다 가이드·문맥을 따로 읽고, 대기 알림마다 리드가 응답)이 얻는 이득보다 큽니다. `tdd-subagent`로 전환할까요? (확정한 태스크 목록을 그대로 넘깁니다) / 팀으로 그대로 진행할까요?"

On switch, stop here and invoke `tdd-subagent` with the requirements document and the confirmed task list — no teammate has been spawned yet. On continue, proceed as a team.

After this answer, do not ask again until Final Stage 4 — except the Tidy First commit question, when there are tidy items, and the escalations named under Lead Duties.

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
SendMessage bodies are one line: READ <path>. Content goes in files.
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
- In-scope files: {paths this session may modify}
- Out of scope: {what this task deliberately does not change}
- Known pitfalls — do NOT copy: {defect} → {what to do instead}
- Regression set: {test ids}
```

Write `{SKILL_DIR}` resolved to an absolute path, and `Read` each guide path once before writing it — a teammate that cannot read its guide stops on `blocked.md`.

**Test conventions are observed, never invented.** A project convention overrides the test-writing rules (naming included), so record only what the existing tests or project instructions actually show. With no existing tests, there is no project convention — do not make one up; RED and the `review-test` lens then hold to the guide.

**"Signatures RED may call" is RED's only window into production code** — its definition forbids reading production files. Every type, constructor, and method a test will touch must be listed with its exact signature. A missing signature costs a `missing-stub` round trip per task.

**`{TDD_DIR}/session.md`** — you are its only writer:

```
# TDD Agent Team Session: {feature}

| # | task | task_id | status | note |
|---|------|---------|--------|------|
| 1 | {domain rule sentence} | {Task id} | PENDING | - |
```

`status`: `PENDING` | `RED_DONE` | `DONE` | `BLOCKED`. `session.md` stays alongside the Tasks — it is the session's record after the team is gone — and `DONE` is set only by your Task Check, never by a Task's status alone.

**`{TASK_DIR}/task.md`** per task:

```
# Task {NN}: {domain rule sentence}
invariants: {INV-001, INV-004}
test_class: {FQCN}
scope_production: {relative paths this task changes}
scenarios:
- {scenario sentence}
```

Decide `test_class` and `scope_production` here, not in the teammates — the stubs, the per-method commands, and the task order all need them. RED sees `scope_production` as paths only and never opens those files.

## Running the Team

Everything a teammate needs is laid out before it exists: the files from Setup 6, the stubs, and the whole task list. Then the team is spawned and starts on its own — you send no first work.

### Prepare the Work

In this order:

1. **Tidy items, when there are any.** For each, in the order the document gives:
   - **Baseline.** Pick the safety net: the regression set and every existing test class that exercises the files the item touches. Run them — ids written out literally — redirecting to `{TDD_DIR}/tidy/{NN}/baseline.log`. They must pass now; if they do not, stop and tell the user — a red baseline cannot prove the restructuring preserved behavior.
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

The role is in the definition and the session facts are in files — `context.md` for everyone, `roles/{name}.md` for each teammate — so a teammate's spawn prompt is just `Start.`. Each rulebook lives in one file that its writer and its reviewer both read: the `test-writing` skill for RED and the `review-test` lens, `references/implementation.md` for GREEN (and as the floor for `tdd-refactor`), `references/refactoring.md` for `tdd-refactor`; the `review-design` lens reads the last two. Reviewers still get their lens and guide paths in the spawn prompt (Final Stage 4). Teammates address each other by these names, so keep them exact. Do not add a model; teammates inherit the session's.

**First report.** `tdd-red`, `tdd-green`, and `tdd-refactor` each open with `READY`. Reviewers do not report: they live for one review and start from their spawn prompt. A teammate without `SendMessage` cannot send that report, so a teammate silent past its first idle notification counts as missing it — stop the team and tell the user rather than letting the cycle start lame.

**Teammates take their own work.** After `READY`, each teammate reads its files and takes its unblocked Tasks from `TaskList` in number order. You never send first work. A blocked Task becomes theirs when the teammate whose work unblocked it sends them `READ` of the Task's file.

### Tidy First (only when there are tidy items)

Structure first, behavior second, in separate commits — the CLAUDE.md Tidy First rule. `tdd-refactor` takes the `Tidy {NN}` Tasks in order; every cycle Task is blocked by the `Tidy gate` Task, which you own, so nothing else runs meanwhile — RED writing new tests against a structure being moved would collide.

- **Test-side follow-up — not yours.** If tests must change mechanically (a moved class, a renamed method), `tdd-refactor` lists the exact edits in `tidy/{NN}/test-updates.md` and sends them to `tdd-red` itself; RED applies only those edits — assertions untouched — and answers `tdd-refactor`.
- **Tidy Check.** When the last item is done, `tdd-refactor` sends you `READ {TDD_DIR}/tidy/tidy-finished.md`. For every item's `tidy-result.md` (and the `test-updates-result.md` it names, when there was one): the safety-net tests pass again; changed files are within the item's in-scope files; test changes are only the listed mechanical edits. Any failure → write `tidy/{NN}/lead-check.md` to `tdd-refactor`, reopening its Task to `in_progress` first; after two bounces, ask the user.

When every item passed, ask once ← **user checkpoint (Tidy First only)**:

> "구조 정비(Tidy First)가 끝났습니다: {항목 요약}. 기존 테스트는 정비 전후 모두 통과합니다. 기능 작업과 섞이지 않도록 지금 `refactor` 커밋을 따로 해 두는 게 좋습니다. 제가 커밋할까요, 직접 하실까요, 커밋 없이 진행할까요?"

Commit only on "제가 커밋" — stage just the files the tidy items changed, message `refactor: {summary}`. Then create the **Stubs**, set the `Tidy gate` Task `completed`, and send `tdd-red` `READ {TASK_DIR}/task.md` for the lowest-numbered Task it unblocked.

### Stubs

RED does not write production files, so every production type and method the tests will call must exist before RED starts. Create them from the signatures the document gives (or the task scenarios): bodies `throw new UnsupportedOperationException("Not implemented yet")` — never a silent `null` or default. Then run `TEST_COMPILE_CMD` and confirm it passes. Add each stub's signature to `context.md` "Signatures RED may call".

After this, stubs are not yours: a stub RED finds missing mid-cycle it asks `tdd-green` for through `missing-stub.md`, and GREEN adds it and its signature.

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
| `tasks/{NN}/task.md` | `Task {NN}: {domain rule sentence}` | `tdd-red` | the `Tidy gate`, if any, and every earlier task whose scope overlaps this one |

A cycle Task is shared by RED and GREEN: RED sets it `in_progress` and hands it over by changing `owner` to `tdd-green`; GREEN hands a refused one back to `tdd-red` and sets a finished one `completed`. Each owner change comes with the `READ` message that wakes the new owner. Reviewers get no Task — they start from their spawn prompt — and neither does `fixes.md`, which holds every owner's items in one file.

### Lead Duties During the Cycle

You are off the handoff path. RED → GREEN goes direct; GREEN reports to you only when a task is done. What reaches you, and what you do:

| Message | Your action |
|---|---|
| `READY` | Note that the teammate is up. Send nothing — it takes its own work |
| `READ {TDD_DIR}/tidy/tidy-finished.md` | Tidy Check and the Tidy First checkpoint (Tidy First above) |
| `READ {TASK_DIR}/green-result.md` | Run the **Task Check** below, then set the task `DONE` (or bounce it) in `session.md`. GREEN has already set the Task `completed`; on a bounce, reopen it first — `TaskUpdate({ taskId, status: "in_progress", owner: "tdd-green" })` |
| `READ {TASK_DIR}/blocked.md` | If it names a missing fact, add it to `context.md` and reply `READ {TASK_DIR}/task.md`. If RED's tests were refused twice or it is a design problem, set `BLOCKED` (and `metadata: { blocked: true }` on its Task) and ask the user — this is the one mid-cycle escalation |
| `READ {TDD_DIR}/red-finished.md` | RED has written tests for every task. Note it; wait for GREEN |
| Idle notification | **Usually nothing — do not reply, do not inspect files.** Teammates go idle between every message, so idle is normal. Act only when *all* teammates are idle and the cycle is not finished (some task not `DONE`/`BLOCKED`, or no `red-finished.md`): then find the handoff that was never sent — from `TaskList` (an open Task whose owner has no message to act on), checked against the result files under `tasks/` — and tell **the sender** to send it again (`READ {TASK_DIR}/task.md` to that teammate). Never send the handoff yourself — the sender owns the file it points to |

### Task Check (on every `green-result.md`)

Nothing outside the teammates enforces the role boundaries, so each finished task gets three mechanical checks from you — cheap now, expensive once later tasks have been built on top of a bad one. `green-result.md` carries everything the checks need: read it and nothing else — no `red-result.md`, no `ls`, never `cat` whole files into your context.

| Check | How | If it fails |
|---|---|---|
| 1. Red-first evidence | `green-result.md` has a `red_check_log:` line naming `{TASK_DIR}/red-check.log` | The code is already built, so red can no longer be proven — do not bounce. Note `red-first unverified` in the task's `session.md` row; the `review-test` lens reports it |
| 2. Scope | the `files_modified` line of `green-result.md` names only paths under "In-scope files" in `roles/tdd-green.md` | Write `{TASK_DIR}/lead-check.md` naming the out-of-scope paths and send `READ {TASK_DIR}/lead-check.md` to `tdd-green`: revert them, or explain in `blocked.md` why the task needs them |
| 3. Really passes | run the `test_methods` from `green-result.md` yourself, ids written out literally, `\| tail -5` | Write `lead-check.md` with the failing names and send it to `tdd-green` |

All three pass → `DONE`. A bounced task comes back as a new `green-result.md` and is checked again; after two bounces of the same task, set `BLOCKED` and ask the user. Do not judge the code itself here — design and test quality belong to the Final Review.

Update `session.md` after every message you act on. It is the record of progress that outlives the team; the Tasks show live status, but a Task's status can lag and is never the evidence — the result files are.

**Every turn you take re-reads this whole conversation, so turns are your cost.** Answer the messages in the table above with the one action listed and end the turn; do not summarize progress, re-read files, or narrate between messages. The user is not waiting on you mid-cycle — they are waiting on the Final Review.

The cycle is finished when every task is `DONE` or `BLOCKED` and RED has sent `red-finished.md`.

## Final Stages

### 1. Refactor

GREEN wrote only the minimum for each task; now `tdd-refactor` makes it readable and well-designed.

1. Write `{TDD_DIR}/refactor.md`: every production file the session changed (the `files_modified` lines of every `green-result.md`), and the safety net — every session test method plus the regression set, ids written out. Create its Task (owner `tdd-refactor`, blocked by every cycle Task). Send `READ {TDD_DIR}/refactor.md` to `tdd-refactor`.
2. On `refactor-result.md`, run the **Refactor Check**: the safety net passes (run it yourself, ids literal, `\| tail -5`); `files_modified` stays within the session's production files; `changes` names a technique for each change; `responsibilities` has one line per production class the session changed, and a line that names more than one responsibility has a matching Extract Class in `changes` or an entry in `deferred` — you check that the record is there, not whether the split is right (`review-design` judges that). If tests had to follow, `tdd-refactor` sent `refactor-test-updates.md` to `tdd-red` itself and reports only after RED's result came back — check that result the same way (only the listed mechanical edits). Any failure → `lead-check.md` back to the owner, reopening its Task to `in_progress` first; after two bounces, ask the user.

### 2. Test Refactor

Test code has not been touched since RED wrote it, apart from mechanical updates. Write `{TDD_DIR}/test-refactor.md` listing every test class this session created or changed, create its Task (owner `tdd-red`, blocked by the refactor Task), and send `READ {TDD_DIR}/test-refactor.md` to `tdd-red`. RED reports back `READ {TDD_DIR}/test-refactor-result.md` when the session's methods still pass. Production refactoring comes first so RED tidies tests against the final structure.

### 3. Final Test

Each task passed its own Task Check; this run proves they still pass **together** — a later task's change can break an earlier task's methods. Run every session method in one invocation — all `test_methods` from every `red-result.md`, plus the regression set — with `TEST_METHOD_RUNNER` and one `TEST_METHOD_CMD` per method. Collect the ids by reading the `red-result.md` files, then **write them out literally in the command**: `{TEST_METHOD_RUNNER} {id1} {id2} …`. Never pass them through a shell variable or `$(…)` — a quoted variable turns the whole list into one argument, and the runner reports a single nonexistent test instead of running yours. Redirect the output to `{TDD_DIR}/final-test.log` and read only the counts and failing names. If anything fails, write the failures to `{TDD_DIR}/final-test-failures.md` and send `READ` to `tdd-green`; at most 2 rounds, then ask the user.

### 4. Parallel Final Review ← user checkpoint 2

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

Show the user the findings and ask — always, unless there are none at all:

- **Critical or Important findings** — list them, then any Minor findings below them, one line each, numbered in the same sequence:

  > "최종 리뷰 결과입니다: {Critical/Important 목록} / Minor: {번호. 한 줄 요약}. 어떤 항목을 반영할까요? (전부 / 번호 선택 / 반영 안 함)"

- **Only Minor findings** — ask briefly, one line per finding:

  > "최종 리뷰에서 Minor {N}건이 나왔습니다: {번호. 한 줄 요약}. 반영할까요? (전부 / 번호 선택 / 반영 안 함)"

- **No findings** — skip the question and go to Summarize.

Keep `tdd-red`, `tdd-green`, and `tdd-refactor` running until the answer is in — any of them may own a fix. Apply only what is approved. Write `{TDD_DIR}/fixes.md` with the approved items split by owner — test changes to `tdd-red`, design and readability findings (`review-design`) to `tdd-refactor`, other production changes (missing or wrong behavior) to `tdd-green` — and send each its `READ`. Then re-run the Final Test once.

**Release teammates as soon as their last work is in.** A teammate with no fixes assigned gets its shutdown request now; one with fixes gets it the moment its fix report arrives. If the user approved nothing, shut down `tdd-red`, `tdd-green`, and `tdd-refactor` immediately.

### 5. Summarize

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
