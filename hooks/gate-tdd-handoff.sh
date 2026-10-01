#!/bin/sh
# Gates the two tdd-agent-team handoffs on a real test run, so a teammate cannot
# pass work on by claiming a result:
#
#   tdd-red   -> tdd-green  "READ <task_dir>/red-result.md"    tests must compile and FAIL
#   tdd-green -> team-lead  "READ <task_dir>/green-result.md"  tests must PASS
#
# A refused handoff is not delivered; the reason goes back to the sender.
# tdd-red may send tdd-green nothing but that handoff, and tdd-green may not
# message tdd-red at all — the two roles meet only through the gated files.
# Every other message passes through, so a teammate can always reach the lead.

payload=$(tr -d '\n')
field() { printf '%s' "$payload" | sed -En "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p"; }

from=$(field agent_type)
to=$(field to)
case "$from>$to" in
  "tdd-red>tdd-green")   role=red ;;
  "tdd-green>team-lead") role=green ;;
  "tdd-green>tdd-red")   role=none ;;
  *) exit 0 ;;
esac

cwd=$(field cwd)
cd "$cwd" 2>/dev/null || exit 0
[ -f .tdd-agent-team/roles.env ] || exit 0

if [ "$role" = none ]; then
  echo "tdd-green does not message tdd-red. Write the problem to <task_dir>/blocked.md and send READ <task_dir>/blocked.md to team-lead." >&2
  exit 2
fi

body=$(field message | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
task_dir=$(printf '%s' "$body" | sed -En "s|^READ (.+)/$role-result\.md$|\1|p")
if [ -z "$task_dir" ]; then
  [ "$role" = green ] && exit 0          # any other report to the lead passes
  echo "tdd-red sends tdd-green exactly one kind of message: READ <task_dir>/red-result.md" >&2
  exit 2
fi
. ./.tdd-agent-team/roles.env
case "$task_dir" in "$cwd"/*) task_dir=${task_dir#"$cwd"/} ;; esac

log="$task_dir/$role-gate.log"
attempts="$task_dir/$role-gate-attempts"

[ -d "$task_dir" ] || { echo "GATE FAIL: $task_dir does not exist" >&2; exit 2; }

fail() {
  n=$(( $(cat "$attempts" 2>/dev/null || echo 0) + 1 ))
  echo "$n" > "$attempts"
  echo "GATE FAIL ($n/2): $1 — details in $log" >&2
  [ "$n" -ge 2 ] && echo "Second refusal: write $task_dir/blocked.md and send READ $task_dir/blocked.md to team-lead." >&2
  exit 2
}

[ -f "$task_dir/red-result.md" ] || fail "$task_dir/red-result.md not found"
methods=$(sed -n 's/^test_methods:[[:space:]]*//p' "$task_dir/red-result.md")
[ -n "$methods" ] || fail "red-result.md has no test_methods line"

cmd="$TEST_METHOD_RUNNER"
for m in $(printf '%s' "$methods" | tr ',' ' '); do
  cmd="$cmd $(printf '%s' "$TEST_METHOD_CMD" | sed "s|{M}|$m|g")"
done

no_tests() { grep -qiE 'no tests found|no tests were found|no test files found|0 tests completed' "$log"; }

case "$role" in
  red)
    eval "$TEST_COMPILE_CMD" > "$log" 2>&1 || fail "tests do not compile"
    if eval "$cmd" >> "$log" 2>&1; then
      fail "tests already pass — not Red"
    fi
    no_tests && fail "the test_methods filter matched no tests" ;;
  green)
    eval "$cmd" > "$log" 2>&1 || fail "the task's tests do not pass"
    no_tests && fail "the test_methods filter matched no tests" ;;
esac

rm -f "$attempts"
exit 0
