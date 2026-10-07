#!/bin/sh
# Grants permission for the md files the TDD skills (tdd-subagent, tdd-agent-team) use to talk to each other.
#
# Every artifact those skills write lives under _workspace/tdd-subagent/ or _workspace/tdd-agent-team/: the session
# file, the shared context, per-task specs, phase results and review reports. They
# are scratch files excluded from git, so prompting for each one only interrupts
# the cycle. Anything else is left to the normal permission flow.

ARTIFACT_DIRS="_workspace/tdd-subagent _workspace/tdd-agent-team"

payload=$(tr -d '\n')

file_path=$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

for dir in $ARTIFACT_DIRS; do
  case "$file_path" in
    */"$dir"/*.md | "$dir"/*.md)
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"tdd-subagent artifact file"}}\n'
      exit 0 ;;
  esac
done
exit 0
