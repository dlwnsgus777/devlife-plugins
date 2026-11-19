---
name: korean-ste
description: >
  Controlled Korean for technical text, adapted from ASD-STE100 (Simplified Technical
  English). Keeps one document consistent — one term per thing, one speech level, one way
  to write units and code identifiers — and, for runbooks, incident reports, error
  messages, release notes, and prompts, makes every instruction short and unambiguous.
  A deterministic linter (scripts/lint.py) checks the measurable rules. Called by
  writing-check, or directly on "용어 통일해줘", "표현 통일해줘", "일관성 맞춰줘",
  "korean-ste", "런북 점검해줘", "장애 보고서 점검해줘", "오류 메시지 다듬어줘",
  "릴리스 노트 점검해줘". Not for marketing copy, blog posts, or tone-only polishing
  (use korean-humanizer).
---

# Korean STE

Controlled Korean for technical text. It does two jobs:

1. **Consistency** — inside one document, the same thing is written the same way.
2. **Sentence rules** — in documents people act on under pressure, each sentence is short and holds one instruction.

Rules a regex can count are checked by `scripts/lint.py`. Rules that need judgment are checked by reading. The linter result is the source of truth for the rules it covers: do not skip a finding because the text "reads fine".

## Rules You Must Keep

- Never change facts, numbers, dates, proper nouns, quotes, or code. Code blocks and inline code are out of scope.
- Never invent a missing condition, value, or time. Mark it `[확인 필요]`.
- In the `strict` profile, short and uniform sentences are intended. Ignore rhythm advice such as "mix short and long sentences".

## Profiles

| Profile | Documents | Rules |
|---|---|---|
| `strict` | Runbook, incident report, error message, release note, prompt or skill instructions | Consistency + all sentence rules |
| `standard` | Slack message, general documents (Confluence, PR description, Jira ticket) | Consistency + `LEN` at 25 어절 |
| `consistency` | Email, review comment, anything else | Consistency only |

When the caller names a profile, use it. Otherwise pick it from the document type. If the type is unclear, ask the user.

## Consistency Rules (every profile)

| Code | Rule | Example fix |
|---|---|---|
| `TERM` | One thing, one term. Use the canonical term from the term map. | "배포 / 릴리스 / 반영" → "배포" |
| `STYLE` | One speech level per document: 합쇼체, 해요체, or 해라체. | "~한다" in a "~합니다" document → "~합니다" |
| `UNIT` | One spelling and one spacing per unit. Thousands separators everywhere or nowhere. | "10분, 30 min" → "10분, 30분" |
| `CODE` | An identifier written in backticks once is written in backticks everywhere. | userId → `userId` |

One word, one meaning: do not use one term for two different things in the same document (e.g. "배포" for both the build artifact and the release action). The linter cannot see this — check it while building the term map.

## Sentence Rules

| Code | Rule | Profile |
|---|---|---|
| `LEN` | A sentence has at most 20 어절 (`standard`: 25). Split long sentences. | `strict`, `standard` |
| `MULTI` | One action per sentence, in instructions and descriptions alike. "재시작하고 로그를 확인한 뒤 알림을 보낸다" becomes three numbered steps; "원인을 찾고 롤백했다" becomes two timeline entries. A chain that is not a sequence of actions ("값이 크고 느리다") stays, with its reason listed in step 5. | `strict` |
| `COND` | The condition comes before the instruction. "X를 실행한다. 단, Y이면 실행하지 않는다" → "Y이면 X를 실행하지 않는다. 그 밖에는 X를 실행한다." | `strict` |
| `VAGUE` | Replace vague qualifiers (적절히, 필요 시, 가능하면, 하도록 한다) with the real condition and action. If the real condition is unknown, mark `[확인 필요]`. | `strict` |

When splitting a sentence:

- Keep the manner and the object of an action (순차적으로, 즉시, which pod) in the same sentence as that action. "파드를 재시작한다. 파드는 순차적으로 재시작한다." → "파드를 하나씩 순차적으로 재시작한다."
- Do not add a step or an instruction the original does not have. If one seems needed, mark `[확인 필요]` instead.

Also check by reading, in `strict`:

- Each instruction names its object. "재시작한다" → "`api` 서버를 재시작한다".
- An incident report states time, scope with numbers, cause, and the time of each action (e.g. rollback).
- An error message states what failed, the value involved, and what the reader changes to fix it.

## Process

1. **Pick the profile** from the table above.
2. **Build the term map.** Read the whole document. Group the expressions that refer to the same thing. The canonical term is the one the project glossary `docs/glossary.md` defines; if it has none, the one the document uses first. Write the groups to a temporary file, one line per group:

   ```
   - 배포: 릴리스, 반영
   - 사용자: 유저, 회원
   ```

   Show the map to the user and apply it only after they confirm or edit it. Skip this step when no group has a variant.
3. **Run the linter.** If the text is not a file yet (a Slack draft), write it to a temporary file first. Pass `docs/glossary.md` too when it exists.

   ```bash
   python3 <this skill's directory>/scripts/lint.py --profile <profile> --terms docs/glossary.md --terms <term map> <document>
   ```

4. **Fix every finding**, then the reading checks of the profile.
5. **Run the linter again.** Repeat until it prints `total 0`, or every remaining finding has a reason to stay (e.g. a quoted log line). List those reasons.
6. **Report.** Under the fixed text, list each change in the writing-check format:

   ```
   - "원문 구절" → "수정 구절" (TERM)
   - [확인 필요] "필요 시 롤백한다" (VAGUE — 롤백 조건 없음)
   ```

7. **Propose glossary entries.** When a group from the term map is likely to recur in other documents of the project, propose adding it to `docs/glossary.md`. Add it only after the user approves.
