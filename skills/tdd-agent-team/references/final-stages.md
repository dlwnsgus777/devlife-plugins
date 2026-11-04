# Final Stages

The lead's steps after the last `Refactor` is done: verify, review, summarize.

## 1. Final Verification

Check, once after every task's refactor, that the teammates kept their role rules — mechanically. For each task that is not `BLOCKED`, read its `task.md` and nothing else: its `green-result` and `refactor-result` sections carry what checks 1–4 need. Never `ls` or `cat` other files into your context.

| Check | How (per task) | If it fails |
|---|---|---|
| 1. Red-first evidence | `green-result` has a `red_check_log:` line naming `{TASK_DIR}/red-check.log` | The code is already built, so red can no longer be proven — not a fix item. Note `red-first unverified` in the task's `session.md` row; the `review-test` lens reports it |
| 2. Scope | the `files_modified` lines of `green-result` and `refactor-result` name only paths in the task's scope (`scope_production` and `test_class` in `task.md`), or a new file `refactor-result` created by moving in-scope code | A fix item for whoever touched the path: revert it, or explain in `{TDD_DIR}/blocked.md` why the task needs it |
| 3. Refactor record | `refactor-result`: a technique for each `production_changes` line; one `responsibilities` line per class, and a line naming two responsibilities has a matching Extract Class or a `deferred` entry | A fix item for `tdd-refactor` |
| 4. Tests unchanged in what they check | `refactor-result`: every `test_changes` line changes no assertion, no input, and no test count | A fix item for `tdd-refactor` — undo that test change |
| 5. Really passes, together | below | A fix item for the owner of the failing behavior |

Check 3 looks only for the record; whether the design is right is `review-design`'s to judge.

**Check 5 — every test of this session, in one run.** A later task's change can break an earlier task's methods.
- Run all `test_methods` from every `red-result` plus the regression set in one invocation; for a method `test_changes` renamed, use the new id.
- Write the ids out literally: `{TEST_METHOD_RUNNER} {id1} {id2} …`. Never through a shell variable or `$(…)` — a quoted variable turns the list into one argument, and the runner reports a single nonexistent test.
- Redirect the output to `{TDD_DIR}/final-test.log` and read only the counts and failing names. The executed count must equal the number of ids.

**Already-passing tests.** A `red-result` may list `already_passing` methods — tests that passed before GREEN touched anything. Deleting a test is your decision, so RED kept them. For each, keep it as coverage or delete it as redundant (a fix item for `tdd-red` naming the id), and note the decision in `session.md`.

**When a check fails**
- Write `{TDD_DIR}/fixes.md` with the failures split by owner, and send each owner its `READ`: missing or wrong behavior to `tdd-green`, structure and refactor records to `tdd-refactor`, tests to `tdd-red`.
- When all have reported, rerun checks 2–4 for the changed tasks and check 5 once. If per-task commits are on, then commit these fixes by kind, as in Final Stage 2 — before `fixes.md` is rewritten for the review.
- At most 2 rounds, then ask the user.
- Every task that passes is `DONE` in `session.md`.

## 2. Parallel Final Review ← user checkpoint 2

Build the diff into a file first — it must never pass through your context. One simple command per step:

1. `git diff {base} > _workspace/tdd-agent-team/branch-diff.md` — every change to tracked files since the session started, the tidy commit included.
2. `git ls-files --others --exclude-standard` — the files this session created. Skip build output it lists (`__pycache__/`, `build/`, `target/`, `node_modules/`).
3. For each remaining file, one command: `git diff --no-index /dev/null <file> >> _workspace/tdd-agent-team/branch-diff.md` — new files do not appear in step 1's diff.
4. `wc -l _workspace/tdd-agent-team/branch-diff.md` — confirm it is not empty.

**Not a git repository** — write `{TDD_DIR}/branch-diff.md` as a list of changed files instead: every `files_modified` path from the `tidy-result`, `green-result`, and `refactor-result` sections, one per line, without duplicates. The reviewers read those files directly.

Spawn three reviewers from the one definition, each owning one lens:

```
Agent({ name: "review-domain", subagent_type: "devlife:tdd-reviewer", description: "Final review: domain",
        prompt: "You are review-domain — the domain lens. TDD_DIR={TDD_DIR}" })
Agent({ name: "review-test",   subagent_type: "devlife:tdd-reviewer", description: "Final review: test",
        prompt: "You are review-test — the test lens. TDD_DIR={TDD_DIR}. TEST_GUIDE={SKILL_DIR}/../test-writing/SKILL.md" })
Agent({ name: "review-design", subagent_type: "devlife:tdd-reviewer", description: "Final review: design",
        prompt: "You are review-design — the design lens. TDD_DIR={TDD_DIR}. IMPL_GUIDE={SKILL_DIR}/references/implementation.md. REFACTOR_GUIDE={SKILL_DIR}/references/refactoring.md" })
```

Each writes `{TDD_DIR}/final-review-{lens}.md`. A reviewer with Critical or Important findings exchanges one rebuttal round with the other two before reporting (the reviewer definition's Protocol).
- Wait for `READ {TDD_DIR}/final-review-{lens}.md` from all three.
- **All reviewers idle and one has not reported** — a rebuttal handoff was lost. Find which `rebuttal-{you}-to-{them}.md` the silent reviewer still lacks and send its owner `READ {TDD_DIR}/final-review-{them}.md` once. If the reviewers go idle again without that report, merge the silent reviewer's `final-review-{lens}.md` as it stands and tell the user its rebuttal round did not finish.
- Merge them: drop findings a rebuttal refuted, keep the rest with their severity. That merged list is what you show the user.
- Then send each reviewer a shutdown request right away.

Whenever there is at least one finding, show the findings to the user and ask. **The findings go in the same message as the question** — the reviewers' shutdown notices print between your messages and push an earlier list off the screen.

- **Critical or Important findings** — list them, then any Minor findings below them, one line each, numbered in the same sequence:

  > "최종 리뷰 결과입니다: {Critical/Important 목록} / Minor: {번호. 한 줄 요약}. 어떤 항목을 반영할까요? (전부 / 번호 선택 / 반영 안 함)"

- **Only Minor findings** — ask briefly, one line per finding:

  > "최종 리뷰에서 Minor {N}건이 나왔습니다: {번호. 한 줄 요약}. 반영할까요? (전부 / 번호 선택 / 반영 안 함)"

- **No findings** — skip the question and go to Summarize.

Keep `tdd-red`, `tdd-green`, and `tdd-refactor` running until the answer is in — any of them may own a fix.
- Write `{TDD_DIR}/fixes.md` with only the approved items, split by owner, and send each owner its `READ`: test changes to `tdd-red`, design and readability findings (`review-design`) to `tdd-refactor`, behavior fixes as below.
- If per-task commits are on, commit by kind, staging only each result section's `files_modified` paths: once RED and GREEN have reported, `git commit -m "fix: {summary}"`; only then send `tdd-refactor` its `READ`, and when it reports, `git commit -m "refactor: {summary}"`. Behavior and structure never share a commit.
- When all have reported, re-run Final Verification check 5 once.

**A behavior fix starts Red, like every task.**
- List it twice in `fixes.md`: under `tdd-red` as the failing test to write (the domain sentence and the input), and under `tdd-green` as "make RED's new tests pass".
- Send `READ` only to `tdd-red` (`tdd-refactor` follows the commit order above). RED hands the file on to GREEN when its tests are red, and GREEN reports to you.
- Everything stays in `fixes.md`: each teammate appends its result section (`## red-result`, `## green-result`, `## refactor-result`), and GREEN's red check goes to `{TDD_DIR}/fix-red-check.log`. Make no other files for this.

**Deleting a test is your decision.** When a behavior fix leaves a test obsolete — it checks behavior the fix removes or replaces — name that test id in `tdd-red`'s items in `fixes.md`, with the reason. RED deletes only the tests listed there.

**Release teammates as soon as their last work is in.**
- A teammate with no fixes assigned → send its shutdown request now.
- A teammate with fixes → the moment its fix report arrives. In a behavior fix GREEN reports for RED too, so that report releases both.
- If the user approved nothing → shut down `tdd-red`, `tdd-green`, and `tdd-refactor` immediately.

## 3. Summarize

Send a shutdown request to any teammate not yet shut down, then print the summary **without waiting for shutdown acknowledgements** — a teammate finishes its current turn before it exits:

```
── TDD Agent Team Session Complete ──
Tasks:   {DONE}/{total} ({BLOCKED} blocked)
Tests:   {N} passed, 0 failed
Files:   {changed files}
Review:  {applied}/{proposed} findings applied
Artifacts: _workspace/tdd-agent-team/
```

- Append `session: COMPLETE` as the last line of `session.md`; the next run's Setup 1 sees it and archives without asking.
- Leave `_workspace/tdd-agent-team/` in place — it is the session's debugging record.
