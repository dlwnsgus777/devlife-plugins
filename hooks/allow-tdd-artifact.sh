#!/bin/sh
# Grants permission for the md files tdd-team's agents use to talk to each other.
#
# Every artifact the skill writes lives under a .tdd-team/ directory: the session
# file, the shared context, per-task specs, phase results and review reports. They
# are scratch files excluded from git, so prompting for each one only interrupts
# the cycle. Anything else is left to the normal permission flow.

payload=$(tr -d '\n')

file_path=$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

case "$file_path" in
  */.tdd-team/*.md | .tdd-team/*.md) ;;
  *) exit 0 ;;
esac

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"tdd-team artifact file"}}\n'
