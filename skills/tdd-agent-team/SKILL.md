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

Run Red-Green-Refactor with an agent team: a `tdd-red` teammate writes failing tests task after task, a `tdd-green` teammate makes them pass, and the two hand work to each other directly. RED for task N+1 runs while GREEN works on task N.

## Execution Rules

**You are the team lead.** Setup, the two user checkpoints, unblocking, the per-task check, and the final stages are yours. The handoffs are not: once the teammates are running, RED and GREEN pass work between themselves and you stay off that path. Never relay a handoff. After Setup, the only source edits you make are stubs a teammate asks for in `missing-stub.md`; you never edit test files.

- Respect system, developer, and project `CLAUDE.md` instructions above this skill.
- The user is asked at task confirmation (Setup 5), after the Tidy First phase when there is one (to commit it separately), and before applying final-review fixes (Final Review 3). Project instructions that ask for feedback after each stage are honored at these two points — the cycle runs in parallel and has no stage boundary to pause at.
- **Files through file tools, shell commands kept simple — yours too.** Create files with `Write`, change them with `Edit` (a `session.md` status flip is one `Edit`), read them with `Read`. Use Bash only to run commands, one simple command at a time: no `cd …;` prefix, no heredocs, no `sed -i`, no loops, no `$(…)` or `$variables`, no brace expansion. The permission checker cannot analyze those, so each one stops the session on a prompt — the `.tdd-agent-team/*.md` artifacts pass without one only when written through the file tools.
- **Teammate content travels in files, never in messages.** Every `SendMessage` body — yours and every teammate's — is one line: `READ <path>`. The file holds the substance. A message with prose in it skips the checks the files carry and leaks context the reader was not meant to have.

### Teammate definitions

Each role is a **user-scope** agent definition that ships with this skill and is installed into `~/.claude/agents/` (Setup 0):

| Teammate name | `subagent_type` | Source | `tools` |
|---|---|---|---|
| `tdd-red` | `tdd-red` | `{SKILL_DIR}/agents/tdd-red.md` | Read, Write, Edit, Bash, SendMessage |
| `tdd-green` | `tdd-green` | `{SKILL_DIR}/agents/tdd-green.md` | Read, Write, Edit, Bash, SendMessage |
| `review-domain` / `review-test` / `review-design` | `tdd-reviewer` | `{SKILL_DIR}/agents/tdd-reviewer.md` | Read, Write, Bash, SendMessage — no `Edit` |

`SKILL_DIR` is this file's parent directory. The definition body becomes the teammate's system prompt, so the role is in force from its first turn. User scope is deliberate: agent teams accept teammate definitions from the project, user, or managed scope only — a definition shipped as a plugin agent is silently ignored, and the teammate spawns as a default agent with no role and no tool limit.

**What is and is not enforced.** The tool lists are enforced: reviewers have no `Edit`. Everything finer is the teammates' own discipline — `tools` cannot limit paths, and RED and GREEN both need `Bash` to run tests. So RED not reading production code, GREEN not editing tests, and GREEN's red check before implementing all rest on the definitions' instructions. The final test and the `review-test` lens are the independent checks that catch a lapse.

## Setup

### 0. Agent Teams Enabled?

Agent teams need `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Check the **effective** value with `echo "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"` — settings files' `env` blocks are applied to the session, and project or local settings override `~/.claude/settings.json`, so reading the user file alone gives the wrong answer. If it is not `1`:

> "이 스킬은 Claude Code agent teams 기능이 필요한데 지금 꺼져 있습니다(`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). `~/.claude/settings.json`의 `env`에 `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"`을 넣어드릴까요? 켜면 이름을 붙인 서브에이전트가 팀원으로 실행되는 등 다른 작업에도 영향이 있습니다. 원치 않으시면 `tdd-subagent`로 진행할 수 있습니다."

Edit the file only on an explicit yes. On no, stop and point to `tdd-subagent`. Agent teams also need an interactive session — in `-p` / SDK mode, teammates never spawn; stop and say so.

**Install the teammate definitions.** For each file in `{SKILL_DIR}/agents/`, compare it with `~/.claude/agents/{same name}`. If any is missing or differs, ask once:

> "팀원 정의 파일({목록})을 `~/.claude/agents/`에 설치(또는 갱신)해야 합니다. 진행할까요?"

On yes, copy them, then **look before you conclude anything**: Claude Code picks up new files in `~/.claude/agents/` while the session runs, and announces them as newly available agent types. Check that `tdd-red`, `tdd-green`, and `tdd-reviewer` are now among the agent types your `Agent` tool lists — usually they are, and you continue straight to Setup 1 with no restart. Only if they are still missing after the copy, tell the user to restart Claude Code and run the skill again, and stop. Never ask for a restart on the assumption that the list is stale. On no, stop: without the definitions the teammates spawn with no role.

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

From the build files, determine the test commands, then write `{TDD_DIR}/roles.env`. The teammates read their commands from it:

```sh
TEST_COMPILE_CMD='./gradlew compileTestJava --offline'
TEST_METHOD_RUNNER='./gradlew test --offline'
TEST_METHOD_CMD='--tests "{M}"'
```

- **Every test run in this skill is per method.** RED adds failing tests for task N+1 to a class while GREEN is finishing task N, so a class-level run hands GREEN someone else's failure. `TEST_METHOD_RUNNER` is the fixed part; `TEST_METHOD_CMD` is the per-method argument with `{M}` standing for one `FQCN.method`, repeated once per method. Maven: runner `mvn -o test`, arg `-Dtest="{M}"` with `{M}` as `Class#method`. jest/vitest: runner `npx vitest run`, arg `-t "{M}"` with the test name.
- `TEST_COMPILE_CMD` compiles test sources without running them. No compile step (plain JS) → `true`.

Then offer once to pre-approve the two test commands, since every teammate runs them dozens of times and each unapproved run can stop the team on a permission prompt:

> "팀원이 테스트 명령을 수십 번 실행합니다. `{TEST_COMPILE_CMD}`와 `{TEST_METHOD_RUNNER}`를 이 프로젝트의 `.claude/settings.local.json` 허용 목록에 추가할까요? (안 하면 실행 중 권한 확인이 자주 뜰 수 있습니다)"

On yes, add `Bash({TEST_COMPILE_CMD}:*)` and `Bash({TEST_METHOD_RUNNER}:*)` to `permissions.allow` in `.claude/settings.local.json`, creating the file if needed and leaving existing entries untouched. On no, continue.

### 4. Invariants and Tasks

**Invariants — requirements document first, code second.** With a spec, plan, or ticket, derive invariants from it and adopt any IDs (`INV-001`, …) verbatim. With nothing, ask "구현할 기능의 요구사항이나 티켓 내용을 공유해주시겠어요?" and wait. Only then scan code for structural constraints the document omitted. Write each as a declarative sentence about what must be true.

**Tidy First items.** If the plan has a Tidy First section (plan-creator `0-1`), each entry — the blocker, the restructuring technique, and where the requirement lands afterwards — becomes a **tidy item**, not a task. A tidy item changes structure and no behavior, so it can never be Red; it runs in the Tidy First phase before the cycle. Take only what the plan names: the team does not invent restructuring.

**Tasks.** Adopt the document's ordered task list if it has one; `[REGRESSION]` items are not tasks — they run in the final test, and in the Tidy First phase as the safety net. Name each task as a domain rule sentence; RED turns it into `@DisplayName`.

- **Batch scenarios that share one implementation change** into one task — one guard clause, one branch, one small function. A task maps to a unit of implementation work, not to a test method.
- **Coverage floor, never a cap:** per invariant, the case that violates it, the nearest case that satisfies it, and every state the rule itself names; plus one happy path per touched class. An edge case with no test is an unbuilt behavior, because GREEN builds exactly what the tests demand.
- **Before presenting, name the production change behind every task.** "Nothing — it already works" or "an earlier task already makes it pass" means it is coverage, not a task: merge its scenarios into the task that builds the logic. In this skill a task that cannot be Red is not just wasted — GREEN's red check refuses it, and RED stalls on it.
- **Order tasks so dependencies come first.** RED runs ahead of GREEN, so task N+1's tests may be written while task N is still unbuilt — they fail for both reasons and the red check lets them through, which is fine because GREEN works in order and reaches N+1 after N. What breaks is the reverse: a later task listed before the task it needs. Record each dependency in `task.md` (`depends_on:`).

### 5. Confirm Tasks ← user checkpoint 1

Present the tidy items (if any), invariants, and tasks together, with the test names, and wait for confirmation:

```
TDD 태스크 목록

  ┌─────┬──────────────────────────────────────────────────────────────┐
  │  #  │ 태스크 → @DisplayName                                         │
  ├─────┼──────────────────────────────────────────────────────────────┤
  │ 1   │ {domain rule sentence} (+ {sentence} if batched)             │
  └─────┴──────────────────────────────────────────────────────────────┘
```

> "태스크를 확정하면 팀원이 끝까지 자동으로 진행하고, 최종 리뷰 결과가 나오면 다시 확인받습니다. 이대로 진행할까요?"

After this answer, do not ask again until Final Review 3 — except the Tidy First commit question, when there are tidy items, and the escalations named under Lead Duties.

### 6. Context, Session, and Task Files

**`{TDD_DIR}/context.md`** — explore the feature area once and write only what you verified this session:

```
# TDD Session Context

## Environment
- Project root: {absolute path}
- Commands: .tdd-agent-team/roles.env
- Production code: {source roots} — tdd-red never reads these
- Test code: {test roots} — tdd-green never writes these
- Test framework: {framework}

## Project Context (captured once — do NOT re-explore the codebase)
- Package / directory layout: {source & test packages}
- Test conventions: {JUnit version, assertion style, // arrange·act·assert, @Nested usage}
- Fixture pattern: {builder location & usage}
- Signatures RED may call: {ClassName → public method signatures, including the stubs from Stubs and Start}
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

**"Signatures RED may call" is RED's only window into production code** — its definition forbids reading production files. Every type, constructor, and method a test will touch must be listed with its exact signature. A missing signature costs a `missing-stub` round trip per task.

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

Decide `test_class` here, not in RED — the stubs (Stubs and Start) and the per-method commands both need it.

## Running the Team

### Spawn

```
Agent({
  name: "tdd-red",
  subagent_type: "tdd-red",
  description: "TDD RED teammate",
  prompt: "TDD_DIR={TDD_DIR}. TEST_GUIDE={SKILL_DIR}/references/test-writing.md. Wait for READ messages from team-lead."
})

Agent({
  name: "tdd-green",
  subagent_type: "tdd-green",
  description: "TDD GREEN teammate",
  prompt: "TDD_DIR={TDD_DIR}. IMPL_GUIDE={SKILL_DIR}/references/implementation.md. Wait for READ messages."
})
```

The role is in the definition; the prompt carries only the session facts. `TEST_GUIDE` and `IMPL_GUIDE` point at the rules in this skill's `references/` — `test-writing.md` for RED and the `review-test` lens, `implementation.md` for GREEN and the `review-design` lens. A path rather than a copy, so each rulebook lives in one file that its writer and its reviewer both read. Teammates address each other by these names, so keep them exact. Do not add a model; teammates inherit the session's.

**First report.** `tdd-red` and `tdd-green` each open with `READ .tdd-agent-team/tools-{name}.md`, listing the tools they actually received. Reviewers do not report: they live for one review, and a reviewer whose definition failed to apply loses only its missing `Edit` — not worth three extra messages on every run. A list that includes tools outside its definition (`Agent`, `Skill`, MCP tools) means the definition did not apply — stop and re-check the install. A teammate without `SendMessage`, `Write`, `Edit`, or `Bash` cannot do its role — and a missing `SendMessage` means it cannot even send that report, so a teammate silent past its first idle notification counts as missing it. Stop the team and tell the user which tool was missing rather than letting the cycle start lame.

### Tidy First (only when the plan has tidy items)

Structure first, behavior second, in separate commits — the CLAUDE.md Tidy First rule. The team does the restructuring; nothing else runs meanwhile, because RED writing new tests against a structure GREEN is moving would collide.

For each tidy item, in plan order:

1. **Baseline.** Pick the safety net: the `[REGRESSION]` test classes and every existing test class that exercises the files the item touches. Run them — ids written out literally — redirecting to `{TDD_DIR}/tidy/{NN}/baseline.log`. They must pass now; if they do not, stop and tell the user — a red baseline cannot prove the restructuring preserved behavior.
2. **Hand it to GREEN.** Write `{TDD_DIR}/tidy/{NN}/tidy.md` — the plan entry verbatim (blocker, technique, landing spot), the in-scope files, and the safety-net test ids — and send `READ {TDD_DIR}/tidy/{NN}/tidy.md` to `tdd-green`.
3. **Test-side follow-up.** If GREEN reports that tests must change mechanically (a moved class, a renamed method), it lists the exact edits in `tidy/{NN}/test-updates.md`. Send `READ {TDD_DIR}/tidy/{NN}/test-updates.md` to `tdd-red`. RED applies only those edits — assertions untouched.
4. **Tidy Check.** On `tidy-result.md` (and RED's `test-updates-result.md` when there was one): the safety-net tests pass again; changed files are within the item's in-scope files; test changes are only the listed mechanical edits. Any failure → write `tidy/{NN}/lead-check.md` to the owner; after two bounces, ask the user.

When every item passed, ask once ← **user checkpoint (Tidy First only)**:

> "구조 정비(Tidy First)가 끝났습니다: {항목 요약}. 기존 테스트는 정비 전후 모두 통과합니다. 기능 작업과 섞이지 않도록 지금 `refactor` 커밋을 따로 해 두는 게 좋습니다. 제가 커밋할까요, 직접 하실까요, 커밋 없이 진행할까요?"

Commit only on "제가 커밋" — stage just the files the tidy items changed, message `refactor: {summary}`. Then continue.

### Stubs and Start

RED does not write production files, so every production type and method the tests will call must exist before RED starts. Create them now — after the Tidy First phase, so they land in the restructured code — from the plan document's signatures (or the task scenarios): bodies `throw new UnsupportedOperationException("Not implemented yet")` — never a silent `null` or default. Then run `TEST_COMPILE_CMD` and confirm it passes. Add each stub's signature to `context.md` "Signatures RED may call".

After this, you add a stub only when RED asks for one through `missing-stub.md`.

Start the cycle: send `READ {TDD_DIR}/tasks/` to `tdd-red`. RED begins with task 01 and continues in number order; GREEN takes each task as RED hands it over.

### Lead Duties During the Cycle

You are off the handoff path. RED → GREEN goes direct; GREEN reports to you only when a task is done. What reaches you, and what you do:

| Message | Your action |
|---|---|
| `READ .tdd-agent-team/tools-{name}.md` | Check the role's tools are all there (see First report). Nothing else |
| `READ {TASK_DIR}/green-result.md` | Run the **Task Check** below, then set the task `DONE` (or bounce it) in `session.md` |
| `READ {TASK_DIR}/missing-stub.md` | Add the stub, run `TEST_COMPILE_CMD`, add the signature to `context.md`, reply `READ {TASK_DIR}/task.md` to the sender |
| `READ {TASK_DIR}/blocked.md` | If it names a missing fact, add it to `context.md` and reply `READ {TASK_DIR}/task.md`. If RED's tests were refused twice or it is a design problem, set `BLOCKED` and ask the user — this is the one mid-cycle escalation |
| `READ {TDD_DIR}/red-finished.md` | RED has written tests for every task. Note it; wait for GREEN |
| Idle notification | **Usually nothing — do not reply, do not inspect files.** Teammates go idle between every message, so idle is normal. Act only when *all* teammates are idle and the cycle is not finished (some task not `DONE`/`BLOCKED`, or no `red-finished.md`): then compare `session.md` with the result files under `tasks/`, find the handoff that was never sent, and tell **the sender** to send it again (`READ {TASK_DIR}/task.md` to that teammate). Never send the handoff yourself — the sender owns the file it points to |

### Task Check (on every `green-result.md`)

Nothing outside the teammates enforces the role boundaries, so each finished task gets three mechanical checks from you — cheap now, expensive once later tasks have been built on top of a bad one. Read only what each check needs; never `cat` whole files into your context.

| Check | How | If it fails |
|---|---|---|
| 1. Red-first evidence | `{TASK_DIR}/red-check.log` exists (`ls {TASK_DIR}`) | The code is already built, so red can no longer be proven — do not bounce. Note `red-first unverified` in the task's `session.md` row; the `review-test` lens reports it |
| 2. Scope | the `files_modified` line of `green-result.md` names only paths under "In-scope files" in `context.md` | Write `{TASK_DIR}/lead-check.md` naming the out-of-scope paths and send `READ {TASK_DIR}/lead-check.md` to `tdd-green`: revert them, or explain in `blocked.md` why the task needs them |
| 3. Really passes | run the task's `test_methods` yourself, ids written out literally, `\| tail -5` | Write `lead-check.md` with the failing names and send it to `tdd-green` |

All three pass → `DONE`. A bounced task comes back as a new `green-result.md` and is checked again; after two bounces of the same task, set `BLOCKED` and ask the user. Do not judge the code itself here — design and test quality belong to the Final Review.

Update `session.md` after every message you act on. It is the only record of progress — there is no shared task list.

**Every turn you take re-reads this whole conversation, so turns are your cost.** Answer the messages in the table above with the one action listed and end the turn; do not summarize progress, re-read files, or narrate between messages. The user is not waiting on you mid-cycle — they are waiting on the Final Review.

The cycle is finished when every task is `DONE` or `BLOCKED` and RED has sent `red-finished.md`.

## Final Stages

### 1. Test Refactor

GREEN refactored production code as it went; test code has not been touched since RED wrote it. Write `{TDD_DIR}/test-refactor.md` listing every test class this session created or changed, and send `READ {TDD_DIR}/test-refactor.md` to `tdd-red`. RED reports back `READ {TDD_DIR}/test-refactor-result.md` when the session's methods still pass.

### 2. Final Test

Each task passed its own Task Check; this run proves they still pass **together** — a later task's change can break an earlier task's methods. Run every session method in one invocation — all `test_methods` from every `red-result.md`, plus the `[REGRESSION]` classes — with `TEST_METHOD_RUNNER` and one `TEST_METHOD_CMD` per method. Collect the ids by reading the `red-result.md` files, then **write them out literally in the command**: `{TEST_METHOD_RUNNER} {id1} {id2} …`. Never pass them through a shell variable or `$(…)` — a quoted variable turns the whole list into one argument, and the runner reports a single nonexistent test instead of running yours. Redirect the output to `{TDD_DIR}/final-test.log` and read only the counts and failing names. If anything fails, write the failures to `{TDD_DIR}/final-test-failures.md` and send `READ` to `tdd-green`; at most 2 rounds, then ask the user.

### 3. Parallel Final Review ← user checkpoint 2

Build the diff into a file first — it must never pass through your context. One simple command per step:

1. `git diff > .tdd-agent-team/branch-diff.md` — changes to tracked files.
2. `git ls-files --others --exclude-standard` — the files this session created. Skip build output it lists (`__pycache__/`, `build/`, `target/`, `node_modules/`).
3. For each remaining file, one command: `git diff --no-index /dev/null <file> >> .tdd-agent-team/branch-diff.md` — new files are untracked, so step 1 alone would hand the reviewers a diff with the new test class missing.
4. `wc -l .tdd-agent-team/branch-diff.md` — confirm it is not empty.

Spawn three reviewers from the one definition, each owning one lens:

```
Agent({ name: "review-domain", subagent_type: "tdd-reviewer", description: "Final review: domain",
        prompt: "You are review-domain — the domain lens. TDD_DIR={TDD_DIR}" })
Agent({ name: "review-test",   subagent_type: "tdd-reviewer", description: "Final review: test",
        prompt: "You are review-test — the test lens. TDD_DIR={TDD_DIR}. TEST_GUIDE={SKILL_DIR}/references/test-writing.md" })
Agent({ name: "review-design", subagent_type: "tdd-reviewer", description: "Final review: design",
        prompt: "You are review-design — the design lens. TDD_DIR={TDD_DIR}. IMPL_GUIDE={SKILL_DIR}/references/implementation.md" })
```

Each writes `{TDD_DIR}/final-review-{lens}.md`. A reviewer with only Minor findings reports to you at once; one with Critical or Important findings first sends its report to the other two, who rebut **those findings only** in `{TDD_DIR}/rebuttal-{from}-to-{to}.md`, revises once, then reports. The rebuttal round is the slow part of the review — it waits on the slowest reviewer twice — so it runs only where a must-fix finding is at stake. Either way you receive `READ {TDD_DIR}/final-review-{lens}.md` from all three. When all three have reported, merge them into `{TDD_DIR}/final-review.md`: drop findings a rebuttal refuted, keep the rest with their severity. Then send each reviewer a shutdown request right away — their work is done, and nothing later needs them.

Show the user the Critical and Important findings and ask:

> "최종 리뷰 결과입니다: {Critical/Important 목록}. 어떤 항목을 반영할까요? (전부 / 번호 선택 / 반영 안 함)"

Apply only what is approved. Write `{TDD_DIR}/fixes.md` with the approved items split by owner — production changes to `tdd-green`, test changes to `tdd-red` — and send each its `READ`. Then re-run the Final Test once.

**Release teammates as soon as their last work is in.** A teammate with no fixes assigned gets its shutdown request now; one with fixes gets it the moment its fix report arrives. If the user approved nothing, shut down `tdd-red` and `tdd-green` immediately.

### 4. Summarize

Send a shutdown request to any teammate not yet released, then print the summary **without waiting for shutdown acknowledgements** — a teammate finishes its current turn before it exits, and the harness completes the shutdown on its own:

```
── TDD Agent Team Session Complete ──
Tasks:   {DONE}/{total} ({BLOCKED} blocked)
Tests:   {N} passed, 0 failed
Files:   {changed files}
Review:  {applied}/{proposed} findings applied
Artifacts: .tdd-agent-team/
```

Leave `.tdd-agent-team/` in place — it is excluded from git and is the session's debugging record.
