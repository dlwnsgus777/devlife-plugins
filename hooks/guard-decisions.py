"""PreToolUse hook: keep docs/spec/*/decisions.md append-only.

Allowed without a prompt:
- creating the file
- appending text after the existing content
- adding " [SUPERSEDED by Dec-N]" to the end of a "### Dec-M." heading line

Anything else — editing, deleting, or reordering an existing entry, or removing
a SUPERSEDED marker — asks the user for approval.
"""
import json
import os
import re
import sys

TARGET = re.compile(r"(^|/)docs/spec/[^/]+/decisions\.md$")
MARKER = re.compile(r"^(### Dec-\d+\..*?) \[SUPERSEDED by Dec-\d+\][ \t]*$", re.MULTILINE)
SUPERSEDED_HEADING = re.compile(r"^### (Dec-\d+)\..* \[SUPERSEDED by Dec-\d+\][ \t]*$", re.MULTILINE)


def resulting_content(tool_name, tool_input, current):
    if tool_name == "Write":
        return tool_input.get("content", "")
    edits = tool_input.get("edits") if tool_name == "MultiEdit" else [tool_input]
    content = current
    for edit in edits or []:
        old, new = edit.get("old_string", ""), edit.get("new_string", "")
        if old == "":
            content = new + content
        elif edit.get("replace_all"):
            content = content.replace(old, new)
        else:
            content = content.replace(old, new, 1)
    return content


def only_appends_or_supersedes(current, updated):
    if MARKER.sub(r"\1", updated).startswith(MARKER.sub(r"\1", current).rstrip()):
        kept = set(SUPERSEDED_HEADING.findall(current)) <= set(SUPERSEDED_HEADING.findall(updated))
        return kept
    return False


def main():
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return
    tool_name = event.get("tool_name", "")
    tool_input = event.get("tool_input") or {}
    path = tool_input.get("file_path", "")
    if tool_name not in ("Edit", "Write", "MultiEdit") or not TARGET.search(path):
        return
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as f:
        current = f.read()
    if only_appends_or_supersedes(current, resulting_content(tool_name, tool_input, current)):
        return
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": "decisions.md의 기존 Dec를 고치거나 지우는 변경입니다. 결정 변경은 devlife:decision-write로 새 Dec를 덧붙이고 옛 Dec에 [SUPERSEDED by Dec-N]만 붙이세요.",
        }
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
