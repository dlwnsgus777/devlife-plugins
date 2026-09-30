#!/bin/sh
# One watchdog per run. Runs outside the Codex sandbox, in a tab of the worker pane.
#   sh <harness dir>/watchdog.sh <orchestrator thread id> [timeout seconds, default 1800]
# The harness dir is the directory this script lives in.
# The orchestrator writes "<label> <start epoch> <status file>" to <harness>/current on each
# dispatch, and "stop" when the run ends. If the status file does not appear within the
# timeout, this sends "<label> timeout" once through codex queue.

HARNESS=$(cd "$(dirname "$0")" && pwd); THREAD="$1"; LIMIT="${2:-1800}"; SENT=""

while :; do
  CURRENT=$(cat "$HARNESS/current" 2>/dev/null)
  [ "$CURRENT" = stop ] && exit 0
  set -- $CURRENT
  LABEL="$1"; STARTED="$2"; STATUS_FILE="$3"
  if [ -n "$LABEL" ] && [ "$LABEL $STARTED" != "$SENT" ] && [ ! -f "$STATUS_FILE" ] \
     && [ $(( $(date +%s) - STARTED )) -ge "$LIMIT" ]; then
    codex queue --thread "$THREAD" --message "$LABEL timeout"
    SENT="$LABEL $STARTED"
  fi
  sleep 10
done
