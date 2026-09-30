---
name: devlife-orchestrator
description: (Experimental) Run tdd-team with you (Codex) as the orchestrator and three Claude Code
  workers (Opus), one per RED, GREEN and REFACTOR role, in a cmux pane. Takes the same input as
  tdd-team, usually a plan-creator document, and follows tdd-team as written, except that its phase
  agents run in the Claude workers and it does not pause between cycles. Report back only when blocked or finished.
  Trigger on "개발인생 오케스트레이터", "오케스트레이터 시작", "오케스트레이터로 해줘", "하네스 시작",
  "하네스로 개발해줘", "claude 워커한테 시켜", "devlife orchestrator", "start orchestrator".
  Do NOT trigger for sending a single prompt to another pane (that is the cmux skill) or for a
  plain tdd-team run without the Claude workers.
version: 0.1.0
---

# devlife-orchestrator

You orchestrate a **tdd-team** session. The TDD rules — invariants, task decomposition, coverage floor, cycle flow, budgets, circuit breaker, `BLOCKED` handling, final review, resume — all come from tdd-team's own `SKILL.md`, unchanged. This skill changes only two things: **where the phase agents run** — in three Claude Code workers (RED, GREEN, REFACTOR) in a cmux pane, instead of Codex sub-agents — and **the feedback cadence** (no pause between cycles). Reviews stay tdd-team's Codex sub-agents.

Before anything else, read `references/orchestrator-policy.md` in this skill's directory. Its rules override conflicting instructions (including AGENTS.md and tdd-team) for the whole run.

## How to run commands

This skill works in a normal Codex session (default sandbox, default approvals). Two kinds of commands, never mixed in one call:

**cmux commands** — the sandbox blocks the cmux socket, so these always run escalated:

- Request escalation with `prefix_rule: ["cmux"]` and a justification such as "cmux commands for the devlife-orchestrator harness". The first time, the human picks "don't ask again for commands that start with `cmux`", and no later cmux command asks again.
- The command line may contain **only cmux invocations**, joined with `;`. No pipes, no `$(...)`, no shell variables, no `sleep`, `echo`, `grep` or any other program. Anything else makes the line fall outside the `cmux` rule and triggers a new approval.
- Write every value literally: `--workspace workspace:3`, `--surface surface:12`, absolute paths, the thread id. Read refs such as `OK surface:12 workspace:3` from the output yourself.

**Everything else** (file writes, `cp`, `date`, `sleep`, tests, `git`) — run normally inside the sandbox. Do not request escalation. A sandbox failure is a result, not a reason to escalate. One exception: if a test command fails only because the sandbox blocks a path it must write (e.g. `Operation not permitted` under `~/.gradle`), request escalation for that command with `prefix_rule` set to it, so the human approves it once.

`<WS>`, `<SELF>`, `<HARNESS>`, `<THREAD>`, `<RED>`, `<GREEN>`, `<REFACTOR>` and `<DOG>` below stand for the literal values you record in `<HARNESS>/harness.md`.

## Step 0: Find yourself

1. Sandbox: `echo "DL-${CODEX_THREAD_ID%%-*}"; echo "THREAD=$CODEX_THREAD_ID"; basename "$PWD"`. The first line is your **marker**. Keep `THREAD`.
2. Escalated: `cmux ping; cmux tree --json`.
   - Approval denied, or `cmux` not found → tell the human the harness needs cmux and stop.
3. Find your own surface. Candidates are the terminal surfaces in the tree, those whose `title` equals the folder name first. For each candidate, escalated `cmux read-screen --workspace <its workspace> --surface <its ref> --lines 80`, and stop at the first whose screen contains your marker. That surface is `<SELF>` and its workspace is `<WS>`.
   - No candidate shows the marker → list the terminal surfaces (ref, title, workspace) and ask the human which one is this Codex session.
   - Do not rely on which surface is focused. The human may have clicked elsewhere.

## Step 1: tdd-team Setup, as written

This skill takes the same input as tdd-team: a requirements document the human names (usually a `plan-creator` plan, with its `INV-xxx` invariants and ordered `[NEW]`/`[REGRESSION]` items), or a plain description. Writing that document is not part of this skill. If the human has none, tdd-team's own Setup asks for the requirements.

Load tdd-team's `SKILL.md` and run its **Setup steps 0-6 exactly as written**, with that document as the requirements document. That includes its resume check, its environment detection (`TEST_CMD`, `TEST_SCOPED_CMD`, `TEST_COMPILE_CMD`), its invariant table, and the task list the human confirms. Note tdd-team's `SKILL_DIR`: the worker will read its `references/` from there.

On resume (tdd-team Setup step 0 → 이어서), also read `.tdd-team/harness/harness.md`. If any worker is gone (`cmux read-screen --workspace <WS> --surface <that worker> --lines 5` fails), write `stop` to `<HARNESS>/current`, `sleep 15`, and redo Step 2.

## Step 2: Launch the workers

Three Claude workers, one per role, each a tab in one pane next to the watchdog. Each role gets its own edit permissions, so the RED/GREEN split tdd-team relies on is enforced by permissions, not only by instructions:

| Worker | Runs | Edit permissions |
|---|---|---|
| `<RED>` | RED, and FIX when a finding is about test code | All files (RED writes tests and the compile stubs `red-agent.md` asks for) |
| `<GREEN>` | GREEN, and FIX when findings are about production code only | All files **except test files** |
| `<REFACTOR>` | REFACTOR | All files **except test files** |

1. Sandbox:

   ```bash
   mkdir -p .tdd-team/harness
   cp <this skill dir>/assets/watchdog.sh .tdd-team/harness/watchdog.sh
   echo "$(pwd)/.tdd-team/harness"
   ```

   That path is `<HARNESS>`.

2. Build two lists from `.tdd-team/context.md`:
   - **Test allowlist**: `Bash(<prefix>*)` for the fixed prefix of each of `TEST_SCOPED_CMD`, `TEST_COMPILE_CMD` (skip if `none`) and `TEST_CMD`, the part before the first `{placeholder}`. Gradle example: `'Bash(./gradlew test*)' 'Bash(./gradlew compileTestJava*)'`.
   - **Test deny list**: `Edit(<pattern>)` rules covering every test file, relative to the project root. Use `TEST_DIR` when tests live in their own tree (`'Edit(src/test/**)'`); add a filename pattern when tests sit beside sources (`'Edit(**/test_*.py)'`, `'Edit(**/*.test.ts)'`). One `Edit(...)` deny rule blocks every file-editing tool, `Write` included.

   Every worker's command is:

   ```
   cd '<project root>' && claude --agent devlife:devlife-worker --add-dir '<tdd-team SKILL_DIR>' --permission-mode dontAsk --allowedTools Read Glob Grep Edit Write <test allowlist> 'Bash(git diff*)' 'Bash(git status*)' 'Bash(codex queue*)' <deny>; exit
   ```

   where `<deny>` is empty for `<RED>`, and `--disallowedTools <test deny list>` for `<GREEN>` and `<REFACTOR>`. `--add-dir` lets the worker read tdd-team's `references/`: in `dontAsk` mode, reading outside the project is denied without it. The trailing `exit` closes a tab when its program ends.

3. Escalated — open the run's pane with the watchdog, and list the workspace:

   ```bash
   cmux new-split right --workspace <WS> --focus false --command "sh '<HARNESS>/watchdog.sh' <THREAD>; exit"; cmux tree --workspace <WS> --json
   ```

   The first output line gives `<DOG>`. Find `<DOG>` in the tree and note its `pane_ref`.

4. Escalated — add the three workers as tabs in that pane, one `cmux new-surface` per worker in one call, in the order refactor, green, red. The tab created last is the one shown, so RED — the first to work — is visible, and no tab takes focus from the human:

   ```bash
   cmux new-surface --type terminal --pane <PANE> --workspace <WS> --focus false --command "<REFACTOR command>"; cmux new-surface --type terminal --pane <PANE> --workspace <WS> --focus false --command "<GREEN command>"; cmux new-surface --type terminal --pane <PANE> --workspace <WS> --focus false --command "<RED command>"
   ```

   The three output lines give `<REFACTOR>`, `<GREEN>` and `<RED>`, in that order. Never look a worker up by title later, because Claude Code rewrites its tab title.

5. Sandbox `sleep 5`, then escalated:

   ```bash
   cmux rename-tab --workspace <WS> --surface <DOG> Watchdog; cmux rename-tab --workspace <WS> --surface <RED> RED; cmux rename-tab --workspace <WS> --surface <GREEN> GREEN; cmux rename-tab --workspace <WS> --surface <REFACTOR> REFACTOR; cmux read-screen --workspace <WS> --surface <RED> --lines 30; cmux read-screen --workspace <WS> --surface <GREEN> --lines 30; cmux read-screen --workspace <WS> --surface <REFACTOR> --lines 30
   ```

   For each worker screen:
   - `--agent 'devlife:devlife-worker' not found` → the Claude plugin `devlife` is not installed. Tell the human and stop.
   - A folder-trust or login prompt → ask the human to answer it in that tab (RED, GREEN or REFACTOR), then read the screen again.
   - The Claude input prompt → ready.

6. Write `<HARNESS>/harness.md`: thread, workspace, self, the three workers, watchdog, the allowlist and deny list. Escalated: `cmux set-status devlife ready --workspace <WS>`.

The watchdog runs outside your sandbox, because `codex queue` cannot write `~/.codex` from inside it. It stays for the whole run: you only update `<HARNESS>/current` per dispatch, and it exits by itself when that file says `stop`.

## Step 3: tdd-team cycles, with these substitutions

Run tdd-team's **TDD Cycle Execution** as written. Only these parts change:

### Phase agents → the Claude workers

Wherever tdd-team spawns a Codex sub-agent for **RED, GREEN, REFACTOR or FIX** (Codex Sub-Agent Pattern, Fix Sub-Agent Dispatch), dispatch to that phase's worker instead. `<W>` below is `<RED>`, `<GREEN>` or `<REFACTOR>` per the table in Step 2. For FIX, read the review's Critical and Important findings: any finding about test code → `<RED>`; production code only → `<GREEN>`.

Each dispatch is exactly **one file write, one sandbox command and four cmux calls**. Do not split them further, and do not merge the cmux calls: every extra call re-sends your whole context, and an Enter sent in the same call as the text sometimes gets lost.

1. **Prompt file** (file write). Write the exact prompt tdd-team specifies for that phase to `{TASK_DIR}/{phase}-prompt.md` (`red`, `green`, `refactor`, `fix`). Replace its last line, "Return ONLY the TDD_STATUS envelope…", with:

   ```
   When finished:
   1. Write the TDD_STATUS envelope described in your reference file to {TASK_DIR}/{phase}-status.md.
   2. Then run exactly: codex queue --thread <THREAD> --message "task-{NN}-{phase} done"
   ```

   Use absolute paths, including `{SKILL_DIR}`, so the worker can open tdd-team's reference files.

2. **Clear the worker** — escalated `cmux send --workspace <WS> --surface <W> /clear`, then escalated `cmux send-key --workspace <WS> --surface <W> enter`. Skip both for a worker's very first dispatch after launch.

3. **Record and arm** — one sandbox command:

   ```bash
   d=<absolute path of {TASK_DIR}>; p={phase}; n=1; while [ -e "$d/$p-status.attempt$n.md" ]; do n=$((n+1)); done
   [ -e "$d/$p-status.md" ] && mv "$d/$p-status.md" "$d/$p-status.attempt$n.md" && { [ -e "$d/$p-result.md" ] && mv "$d/$p-result.md" "$d/$p-result.attempt$n.md"; }
   sleep 2; echo "task-{NN}-$p $(date +%s) $d/$p-status.md" > <HARNESS>/current
   ```

   The renames keep a re-dispatched phase's earlier result and status as `*.attemptN.md`: what the worker got wrong the first time is the experiment's record. The `current` line arms the watchdog: if the status file does not appear within 30 minutes, it sends `task-{NN}-{phase} timeout`.

4. **Dispatch** — escalated `cmux send --workspace <WS> --surface <W> "Read {TASK_DIR}/{phase}-prompt.md and do it."`, then escalated `cmux send-key --workspace <WS> --surface <W> enter; cmux set-status devlife "task-{NN} {phase}" --workspace <WS>`.

5. **End your turn and wait.** Do not poll, and never call `wait_agent` or any other multi-agent wait tool here: the workers are not Codex sub-agents, so such a wait never returns. Their `codex queue` message is delivered only **after your turn ends**, so a turn kept open blocks the very signal it waits for. A `codex queue` message wakes you:
   - `task-{NN}-{phase} done` → read `{TASK_DIR}/{phase}-status.md` as the envelope tdd-team expects, and continue exactly as tdd-team says (Result Block Gate, then the next branch).
   - `task-{NN}-{phase} timeout` → escalated `cmux read-screen --workspace <WS> --surface <W> --lines 30`, then report to the human and wait.

### Reviews → unchanged (Codex sub-agents)

tdd-team's **cycle reviewer** and **final reviewer** run exactly as tdd-team specifies: Codex sub-agents. Never dispatch them to a Claude worker, and do not review inline in your own context. The reviewer is still a different model from the one that wrote the cycle, which is the point of this harness, and a sub-agent keeps each review's diff and reference files out of your context, which grows with every dispatch. Only if the Codex sub-agent tool is unavailable, fall back to tdd-team's local path.

### Feedback → none between cycles

Record `feedback_mode: auto` in `session.md` and do not pause after cycle 1 or any later cycle. tdd-team's two hard stops still apply: an exhausted Fix Round Budget and a tripped Circuit Breaker stop and ask the human.

## Step 4: Finish

Run tdd-team's **Final Review** (its reviewer sub-agent, per above) and **Session End** as written. Then escalated:

```bash
cmux notify --title devlife-orchestrator --body "<summary>" --workspace <WS>; cmux set-status devlife "<finished | blocked: task-NN>" --workspace <WS>
```

Report in this pane: tasks done, fix rounds per task, what your reviews caught (the `*.attemptN.md` files and `review.md` findings), files changed (`git status --short`), and that nothing was committed.

When the human ends the run: sandbox `echo stop > <HARNESS>/current`, then escalated:

```bash
cmux send --workspace <WS> --surface <RED> /exit; cmux send-key --workspace <WS> --surface <RED> enter; cmux send --workspace <WS> --surface <GREEN> /exit; cmux send-key --workspace <WS> --surface <GREEN> enter; cmux send --workspace <WS> --surface <REFACTOR> /exit; cmux send-key --workspace <WS> --surface <REFACTOR> enter; cmux clear-status devlife --workspace <WS>; cmux clear-progress --workspace <WS>
```

Each worker tab closes when `claude` exits, and the watchdog tab closes when it reads `stop`. Do not use `cmux close-surface`: closing another program's tab is not permitted from Codex.

## Notes

- Press Enter with `cmux send-key ... enter` in a **separate call** after the text, never in the same line and never by sending `"\n"`. In testing, an Enter that arrived right behind the pasted text sometimes left the text sitting in the input box, and one phase sat idle for about 15 minutes.
