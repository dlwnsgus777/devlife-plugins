---
name: devlife-team-starter
description: >
  Use this skill to spawn a multi-agent workspace with an additional Codex pane
  in cmux. Trigger on "개발인생 team", "개발인생 팀 시작", "개발인생 팀 준비",
  "개발인생 팀 시작해", "개발인생 팀 준비해", "devlife team", "devlife team 시작",
  "agent team", "에이전트 팀", "codex 같이", "start agent team", "팀 시작",
  "멀티 에이전트 시작", "codex 같이 띄워", "에이전트 팀 만들어",
  "spawn agents", "launch agents", "에이전트 pane 열어", "agent pane",
  "start multi-agent", "codex pane".
  Also trigger when the user wants Codex running side-by-side in terminal
  panes for parallel work, or asks to set up a multi-agent development environment.
  Do NOT trigger when the user just wants to delegate a single task to codex
  — use codex-delegate for that. This skill is specifically for
  spawning persistent agent panes in cmux.
version: 0.1.0
---

# 개발인생 Agent Team

Spawn Codex (`-a never`) in a cmux pane alongside the current Claude session. Skips creation if it's already running in the same workspace.

## Prerequisites

- cmux must be running (check socket)
- Current terminal must be inside cmux (CMUX_WORKSPACE_ID set)
- `codex` CLI binary must be available

## Workflow

### Step 1: Verify cmux environment

```bash
# Check cmux is available and we're inside it
if [ -z "${CMUX_WORKSPACE_ID:-}" ]; then
  echo "ERROR: Not inside a cmux workspace"
  exit 1
fi
cmux ping
```

If cmux is not available or we're not inside a cmux terminal, inform the user and stop.

### Step 2: Check for existing agent panes and save caller context

Before creating new panes, capture the caller's pane ref and check if Codex is already running.

```bash
# Get caller pane ref directly (caller.pane_ref is always present)
CALLER_PANE=$(cmux identify --json | python3 -c "import json,sys; print(json.load(sys.stdin)['caller']['pane_ref'])")

# Check for existing Codex surface by title in the current workspace
cmux list-pane-surfaces --workspace "${CMUX_WORKSPACE_ID}" --json
```

Parse the `list-pane-surfaces` JSON and check each surface's `title` field:
- `CODEX_RUNNING=true` if any surface title is exactly `"Codex"`

If Codex is already running, inform the user and stop:
> "Codex가 이미 이 workspace에서 실행 중입니다."

### Step 3: Check CLI availability

```bash
# Check codex (only if not already running)
command -v codex &>/dev/null && echo "codex available"
```

If the CLI is not found, inform the user and stop.

### Step 4: Create Codex pane (right split)

`new-split` returns a line like `OK surface:26 workspace:7`. Capture the surface ref to send commands to it.

```bash
# Split right from current pane
CODEX_OUT=$(cmux new-split right)
CODEX_SURFACE=$(echo "$CODEX_OUT" | grep -o 'surface:[0-9]*')

# Wait for shell to initialize, then start codex
sleep 0.5
cmux send --surface "$CODEX_SURFACE" "codex -a never\n"

# Label the pane for future detection
cmux rename-tab --surface "$CODEX_SURFACE" "Codex"
```

### Step 5: Return focus to Claude pane

Use `focus-pane` (not `focus-surface` — that command doesn't exist). Get the caller's pane ref from the `cmux tree --json` output obtained in Step 2.

```bash
# The caller's pane ref was captured in Step 2 from tree output
# Look for the pane where caller.surface_ref matches CMUX_SURFACE_ID
cmux focus-pane --pane <caller_pane_ref>
```

### Step 6: Notify and report

Send a notification and report the result:

```bash
cmux notify --title "Agent Team Ready" --body "Codex is running"
```

Display a summary to the user:

```
Agent Team 구성 완료:
┌─────────────────┬─────────────────┐
│                 │ Codex           │
│  Claude (현재)   │ (-a never)      │

│                 │                 │
└─────────────────┴─────────────────┘
```

## Edge Cases

- **Codex CLI not available**: Inform the user that codex is missing and how to install it.
- **cmux not running**: Tell the user to open cmux first. Do not fall back to tmux.
- **Already in a complex layout**: The skill always splits from the current context. If the layout is already complex, the new pane will be added relative to whatever is currently focused.
