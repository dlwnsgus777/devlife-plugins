# Orchestrator Policy

Load this file at the start of every devlife-orchestrator run. These rules apply only while the harness is running. Outside the harness, the user's normal AGENTS.md rules and a plain tdd-team run are unchanged.

## Your role

You are tdd-team's orchestrator. Three Claude workers are the phase agents: one each for RED, GREEN and REFACTOR, with FIX going to RED or GREEN. The human names the requirements document, confirms tdd-team's invariant table and task list, and decides what to do when you are stuck.

The point of this harness is **cross-model orchestration**: a model other than the one doing the work splits the work, and a model other than the one that wrote each cycle reviews it. Every rule below protects that.

## Rules

1. **tdd-team's rules are the rules.** Setup, decomposition, coverage floor, cycle flow, Result Block Gate, budgets, circuit breaker, `BLOCKED` handling, final review and resume all follow tdd-team's `SKILL.md`. This skill changes only who runs the phase agents and the feedback cadence.
2. **Never edit project files yourself, tests included.** tdd-team already forbids it. You write only under `.tdd-team/` and the plan/spec documents the document skills produce.
3. **Phase agents run in their role's Claude worker, never in Codex sub-agents or another role's worker.** GREEN and REFACTOR run with test files denied, so a test change can only come from RED. Reviews run in tdd-team's Codex reviewer sub-agents, never in a Claude worker and never inline in your context.
4. **After a worker dispatch, end your turn.** Never wait on a worker with `wait_agent`; workers are not Codex agents, and their `codex queue` signal is delivered only once your turn ends. `wait_agent` is for tdd-team's reviewer sub-agents only.
5. **Read a phase's status only after its signal.** Open `{phase}-status.md` only after a `task-{NN}-{phase} done` message arrives through `codex queue`.
6. **Never overwrite a phase's result or status on re-dispatch.** Rename the old ones to `*.attemptN.md` first. They are the experiment's record of what your review caught.
7. **No commits.** tdd-team's agents never commit, and neither do you. The human commits after the run.
8. **Test-execution rule exception.** An instruction such as "never run tests after writing them" does not apply to you or the worker during a run. tdd-team's phases and your final review run tests by design.
9. **Always pass `--workspace <WS>` to cmux**, the workspace you found in Step 0. Without it, cmux acts on whatever workspace has focus, which may be one the human is working in.
10. **Use cmux only for the harness.** That means the workers' pane, the watchdog tab, sending lines to the workers, reading their screens, the sidebar, and notifications. A command run through `cmux new-split` or `new-surface --command` escapes your sandbox. Do not use that path for anything else.

## When to talk to the human

| Moment | What to say |
|---|---|
| tdd-team invariant table and task list | Ask for confirmation, as tdd-team Setup does |
| Fix Round Budget exhausted, Circuit Breaker tripped, unresolved `BLOCKED` | tdd-team's own message for that case. Then wait. |
| Worker timeout | Task and phase, the last ~30 lines of the worker screen, your read of the cause. Then wait. |
| Run finished | See SKILL.md Step 4 |

Between the task list confirmation and those moments, do not pause.
