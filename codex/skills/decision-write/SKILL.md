---
name: decision-write
description: Records a decision in a task folder's append-only decisions.md (docs/spec/{ticket}-{slug}/decisions.md) as a Dec-N entry — problem, options, choice, rationale, impact, and who proposed and who chose it. Also handles reversing an earlier decision, which needs the user's approval. Use when plan-creator or a TDD skill records a decision, or when the user says "결정 기록해줘", "결정 추가해줘", "이 결정 바꿔줘", "Dec 추가", or asks to change decisions.md.
---

# Decision Write

`decisions.md` answers "왜 이렇게 했지?" next to the code. Each decision is one `Dec-N` entry, and the file only grows: an entry, once written, is never edited, deleted, or renumbered. A changed decision becomes a new entry that supersedes the old one, so the trial and error stays on record.

## Input

- The task folder path — `docs/spec/{ticket}-{slug}/`, or `docs/spec/{YYYY-MM-DD}-{slug}/` without a ticket. If the caller gives none and the request names no folder, ask which one.
- One or more decisions, each with its problem, options, choice, rationale, source, and impact.

If the folder has no `decisions.md`, create it with the single line `# Decisions` before the first entry.

## Entry Format

Read `assets/decision-template.md` and follow it.

- **Fields**: only the template's lines. No extra field such as `비고` — a note that the user should review a decision is what `ai-selected` already says.
- **Number**: the last `Dec-N` in the file plus one. Never reuse a number.
- **옵션**: list every option that was weighed, including the rejected ones. A decision with only one option considered lists that one.
- **연관 설계**: the earlier Decs this one depends on or affects, with the relation in parentheses, the modules it reaches, and the `plan.md` parts that follow it (e.g., `plan.md Phase 2 스니핏`) — the parts to rewrite if this decision is ever superseded. `없음` if none.
- **변경 히스토리**: only on an entry that supersedes another.

**출처** — who proposed and who chose:

| 출처 | Proposed by | Chosen by |
|---|---|---|
| `user-suggested` | user | user |
| `ai-suggested` | AI | user |
| `ai-selected` | AI | AI |

An `ai-selected` entry is a decision the user never saw. Record every one of them — they are what the user reviews first.

**영향도** — how far the decision spreads:

| 영향도 | Means |
|---|---|
| `foundation` | Framework choice, core structure — other decisions build on it |
| `significant` | Affects several parts of the change |
| `local` | Affects a single unit |

## Adding a Decision

1. Read the whole `decisions.md` and list the entries without a `[SUPERSEDED by Dec-M]` marker — the active ones.
2. Check the new decision against every active entry.
3. **No conflict** → append the entry at the end of the file. No approval needed.
4. **Conflict** — the new decision contradicts an active entry's choice → follow **Reversing a Decision**.

## Reversing a Decision

Reversing an active decision breaks an agreement the work was built on, so stop and let the user decide.

1. Stop. Do not edit the file yet.
2. Report to the user: the active entry, the new information that conflicts with it, and a draft of the new entry.

   > "Dec-2(신규 카테고리 판별 방식 — LLM 분류)를 뒤집어야 할 것 같습니다.
   > 새 정보: LLM 분류만으로는 일 배치 비용 한도를 넘습니다.
   > 초안: Dec-5. 판별 방식 — 키워드 1차 필터 + LLM 분류 (Dec-2 대체)
   > 이대로 기록할까요?"

3. Only after the user approves:
   - append the new entry, with `변경 히스토리 — Dec-M 대체, 사용자 승인`;
   - append ` [SUPERSEDED by Dec-N]` to the end of the old entry's heading line. Change nothing else in the old entry.
4. If the user declines, record nothing and say the active entry still holds.

**Re-discuss only on new information.** A decision already recorded is not reopened because a different option now looks nicer. Reopen it only when there is a fact the original entry didn't have — a measured cost, a constraint discovered in code, a changed requirement — and name that fact in the report.

## Never

- Edit the body of an existing entry — not even a typo. A correction is a new entry.
- Delete an entry, or renumber entries.
- Mark an entry superseded without a new entry that supersedes it.

## Output

After writing, report each recorded entry in one line: `Dec-N. [제목] — [출처] · [영향도]`, and the `decisions.md` path.
