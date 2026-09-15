#!/usr/bin/env python3
# tdd-team 세션의 단계별 소요 시간을 Claude Code 트랜스크립트에서 뽑는다.
#
#   ./scripts/tdd-timing.py ~/Desktop/develop/acuvue-posm   프로젝트의 최신 세션
#   ./scripts/tdd-timing.py <경로>.jsonl                    트랜스크립트 직접 지정
#   ./scripts/tdd-timing.py                                 최근 세션 목록만 출력
#
# 병목이 명령 실행이 아니라 에이전트 왕복 횟수라서, 단계별 벽시계 시간과
# 승인 대기 의심 구간을 함께 본다. 스킬을 고치기 전후로 같은 출력을 비교한다.

import datetime
import json
import os
import re
import sys

PROJECTS = os.path.expanduser("~/.claude/projects")

# 서브에이전트 프롬프트 캐시 기본 TTL. 디스패치 간격이 이보다 길면 다음 에이전트는
# 콜드 캐시로 시작한다.
CACHE_TTL_MIN = 5

# 측정된 명령 자체는 수 초 단위다. 이보다 오래 걸린 Bash 는 승인 대기를 의심한다.
APPROVAL_SUSPECT_SEC = 60


def transcript_dir(project_path):
    slug = re.sub(r"[^a-zA-Z0-9]", "-", os.path.abspath(os.path.expanduser(project_path)))
    return os.path.join(PROJECTS, slug)


def latest_transcript(directory):
    if not os.path.isdir(directory):
        return None
    files = [os.path.join(directory, f) for f in os.listdir(directory) if f.endswith(".jsonl")]
    return max(files, key=os.path.getmtime) if files else None


def parse(path):
    """tool_use 와 tool_result 를 id 로 짝지어 (호출시각, 이름, 입력, 소요초) 목록을 만든다."""
    def ts(s):
        return datetime.datetime.fromisoformat(s.replace("Z", "+00:00"))

    calls, results, last_seen, sidechain = {}, {}, None, 0
    with open(path) as fh:
        for line in fh:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if entry.get("isSidechain"):
                sidechain += 1
            stamp = entry.get("timestamp")
            content = (entry.get("message") or {}).get("content")
            if not stamp or not isinstance(content, list):
                continue
            last_seen = ts(stamp)
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "tool_use":
                    calls[block["id"]] = (ts(stamp), block.get("name"), block.get("input") or {})
                elif block.get("type") == "tool_result":
                    results.setdefault(block.get("tool_use_id"), ts(stamp))

    rows = []
    for tid, (started, name, payload) in calls.items():
        done = results.get(tid)
        rows.append((started, name, payload, (done - started).total_seconds() if done else None))
    rows.sort(key=lambda r: r[0])
    return rows, last_seen, sidechain


def phase_durations(rows, last_seen):
    """에이전트가 비동기로 기동되면 디스패치 간격이 곧 그 단계의 소요 시간이다."""
    dispatches = [(t, p.get("description", "?")) for t, n, p, _ in rows if n == "Agent"]
    out = []
    for i, (started, label) in enumerate(dispatches):
        ends = dispatches[i + 1][0] if i + 1 < len(dispatches) else last_seen
        out.append((label, (ends - started).total_seconds() / 60, i + 1 == len(dispatches)))
    return out


def main():
    if len(sys.argv) < 2:
        print("최근 세션 (프로젝트 경로나 .jsonl 을 인자로 주세요)\n")
        entries = []
        for name in os.listdir(PROJECTS):
            newest = latest_transcript(os.path.join(PROJECTS, name))
            if newest:
                entries.append((os.path.getmtime(newest), name))
        for mtime, name in sorted(entries, reverse=True)[:12]:
            when = datetime.datetime.fromtimestamp(mtime).strftime("%m-%d %H:%M")
            print(f"  {when}  {name}")
        return 0

    target = os.path.expanduser(sys.argv[1])
    path = target if target.endswith(".jsonl") else latest_transcript(transcript_dir(target))
    if not path or not os.path.exists(path):
        print(f"트랜스크립트를 찾을 수 없습니다: {target}", file=sys.stderr)
        return 1

    rows, last_seen, sidechain = parse(path)
    print(f"세션: {path}")
    print(f"툴 호출 {len(rows)}건 · sidechain {sidechain}건"
          f"{' (에이전트 비동기 기동 — 작업 내역은 별도 트랜스크립트)' if not sidechain else ''}\n")

    phases = phase_durations(rows, last_seen)
    if phases:
        print("단계별 소요 (디스패치 간격)")
        for label, minutes, is_last in phases:
            mark = " ← 캐시 TTL 초과" if minutes > CACHE_TTL_MIN else ""
            tail = " (마지막 — 세션 끝까지)" if is_last else ""
            print(f"  {label[:44]:<44} {minutes:>6.1f}분{mark}{tail}")
        over = sum(1 for _, m, _ in phases if m > CACHE_TTL_MIN)
        print(f"  └ {len(phases)}개 중 {over}개가 {CACHE_TTL_MIN}분 초과\n")
    else:
        print("Agent 디스패치가 없습니다 — tdd-team 세션이 아닐 수 있습니다.\n")

    totals = {}
    for _, name, _, secs in rows:
        if secs is None:
            continue
        count, total = totals.get(name, (0, 0.0))
        totals[name] = (count + 1, total + secs)
    if totals:
        print(f"{'툴':<16}{'횟수':>6}{'총 초':>10}{'평균 초':>10}")
        for name, (count, total) in sorted(totals.items(), key=lambda kv: -kv[1][1]):
            print(f"{name:<16}{count:>6}{total:>10.0f}{total / count:>10.1f}")
        print()

    slow = [(s, (p.get("command") or "").split("\n")[0])
            for _, n, p, s in rows if n == "Bash" and s and s > APPROVAL_SUSPECT_SEC]
    if slow:
        print(f"승인 대기 의심 — {APPROVAL_SUSPECT_SEC}초 넘게 걸린 Bash")
        for secs, command in sorted(slow, reverse=True)[:10]:
            print(f"  {secs:>6.0f}s  {command[:62]}")
        print(f"  └ 합계 {sum(s for s, _ in slow):.0f}초")
    return 0


if __name__ == "__main__":
    sys.exit(main())
