#!/bin/sh
# Keeps the tdd-agent-team roles apart: tdd-red can neither read nor write
# production code, tdd-green cannot write tests.
#
# Teammates are identified by name — a teammate's hook payload carries its name
# in agent_type. Anything else (the main session, other agents, tdd-subagent)
# passes through, and so does every call in a project without
# .tdd-agent-team/roles.env, which holds the path patterns for this session.
# Glob is not checked: it returns file names, not contents.

payload=$(tr -d '\n')
field() { printf '%s' "$payload" | sed -En "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p"; }

agent_type=$(field agent_type)
case "$agent_type" in
  tdd-red | tdd-green) ;;
  *) exit 0 ;;
esac

cwd=$(field cwd)
[ -f "$cwd/.tdd-agent-team/roles.env" ] || exit 0
. "$cwd/.tdd-agent-team/roles.env"

tool=$(field tool_name)
target=$(field file_path)
[ -n "$target" ] || target=$(field path)
[ -n "$target" ] || target=$cwd          # Grep/Glob without a path search the whole project
case "$target" in /*) ;; *) target="$cwd/$target" ;; esac

# A directory target is checked with a trailing slash too, so "src/test" matches "*/src/test/*".
matches() {
  for glob in $1; do
    case "$target" in $glob) return 0 ;; esac
    case "$target/" in $glob) return 0 ;; esac
  done
  return 1
}

case "$agent_type:$tool" in
  tdd-red:Write | tdd-red:Edit)
    matches "$SOURCE_PATH_GLOBS" && { echo "tdd-red cannot modify production code: $target" >&2; exit 2; } ;;
  tdd-red:Grep)
    # Grep returns file contents, so tdd-red may only search inside test paths or the artifacts.
    case "$target/" in */.tdd-agent-team/*) exit 0 ;; esac
    matches "$TEST_PATH_GLOBS" || { echo "tdd-red can grep only test paths or .tdd-agent-team/ — production code is closed to you: $target" >&2; exit 2; } ;;
  tdd-red:Read)
    matches "$SOURCE_PATH_GLOBS" && { echo "tdd-red cannot read production code — use the signatures in .tdd-agent-team/context.md: $target" >&2; exit 2; } ;;
  tdd-green:Write | tdd-green:Edit)
    matches "$TEST_PATH_GLOBS" && { echo "tdd-green cannot modify test code: $target" >&2; exit 2; } ;;
esac
exit 0
