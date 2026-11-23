---
name: plan-write
description: Writes or updates a task folder's plan.md (docs/spec/{ticket}-{slug}/plan.md) — intent, scope (in / out), existing-code pitfalls, phase goals with completion criteria and status, and for code work each phase's files, logic, and code snippets, then verification, prerequisites, glossary, backlog. Use when plan-creator hands over its gathered context to write the plan, when a TDD skill finishes a phase and updates its status, or when the user says "plan.md 작성", "plan.md 갱신", "Phase 완료 표시", "Backlog에 추가".
---

# Plan Write

`plan.md` answers "무엇을 하나" and, for code work, "어떻게 만드나": the intent, what is in and out of scope, the phases with their completion criteria and implementation detail, and how the work is verified. It is reread before every coding step and updated as the work moves, so every sentence should be read once and understood. The phase detail — files, logic, code snippets — is what keeps two runs of the same plan producing the same code, and what the user reviews before any code exists.

## Modes

| Mode | Caller | What it changes |
|---|---|---|
| **Write** | plan-creator, or the user with the content in hand | Creates or rewrites `plan.md` from the template |
| **Update** | a TDD skill, or the user during the work | Only the places listed under **Update Mode** |

## Write Mode

**Input**: the task folder path, and the content for each section — usually plan-creator's code exploration results and clarifying-question answers.

1. Read `assets/plan-template.md` and follow it.
2. Write `plan.md` in the task folder. If one exists, keep its 3. Plan `상태` values, its checked boxes, and its 7. Backlog entries.
3. Every section stays. A section with nothing to write says `없음`.
4. Never guess. Write only what the input shows. Anything else goes to 7. Backlog as a question.

### Section Rules

- **1. Context — 외부 제약**: conditions given from outside this work — a batch schedule, an external API limit, a response format to keep, a definition that can't change. Domain rules go under 도메인 불변성, not here.
- **2. Scope**: every `Out` item points to a 7. Backlog entry (`→ 7-N`). An `Out` item states what is out and, in one sentence, why.
- **1. Context — 기존 코드의 함정**: see **기존 코드의 함정** below. Never omitted for code work — with nothing to write, it says `해당 없음`.
- **3. Plan**: the phase table holds each phase's goal, a completion criterion that names 4. Verification items (`4-2 통과`), and its status. Every phase starts as `todo`. A Tidy First phase comes first, and its criterion includes `동작 변경 없음`.
- **3. Plan — phase detail** (code work only): one `### Phase N.` subsection per phase, below the table.
  - **Tidy First phase**: only the structure the user chose, pointing to its `Dec-N`. When the current structure takes the change by adding alone, there is no Tidy First phase; write `정비 해당 없음 — [how the change goes in]` below the table. Modifying existing code never leaves this unsaid.
  - **Feature phase**: 구현 대상 파일, API (omit when the phase has no endpoint), 비즈니스 로직, 코드 스니핏. Omit a part only when the input has nothing for it — a part left out because nobody looked is a blind spot.
  - **코드 스니핏**: class declaration, `private final` fields, and method bodies with the call order, a guard clause per invariant, exceptions, and the return shape. Inject the classes the reuse scan found. Leave out logging, transaction settings, and defensive null checks. Write enough that coding can start without rereading the requirements. A snippet body is never empty or `// TODO`.
  - Class and method names match across the file table, the snippets, and 4. Verification.
  - Table cells: the decision in one sentence, plus at most one sentence of reason. A procedure goes in 비즈니스 로직, and the cell points to it.
- **4. Verification**: tests grouped by phase, then by feature inside each phase under a `#### [feature name]` heading — kept even when a phase has one feature. Numbered across the whole section. 수동 확인 lists what a person checks by hand.
  - **수동 확인**: a checklist grouped by feature — the unit the person checking recognizes — not by phase.
    - Each item states an action and the visible result: the response value, the rows saved, whether a message is sent. Never write "기존대로 동작한다" or "정상 동작한다".
    - List only behavior this change alters. Of unchanged behavior, keep only what touches this change — e.g., using a coupon already issued.
    - Write when and where to check once, in the line at the top, never inside an item. DB checks run on a set date go in their own group.
    - A limit on how to check — e.g., the clock can't be changed on stage — goes in 5. Prerequisites, not in the checklist.
  - **Boundary values**: a test of a rule with a boundary — a threshold, a cap, a range — lists, as sub-bullets under the test item, the input on each side of every boundary with its expected result: the boundary value and the value one unit before it. Example: a 3만원 cap reached at 200,000원 lists `199,999원 → 29,999원` and `200,000원 → 30,000원`. A value only inside or far beyond the boundary doesn't count — a rule that starts at the wrong point still passes it.
- **5. Prerequisites**: what must hold before the work runs. 배포 전 작업 lists steps that must happen before deploy.
- **6. Glossary**: terms whose meaning was settled for this work, with the code name that carries each.
- **7. Backlog**: later work and open questions, each with its source. A decision with its options and reasoning belongs in `decisions.md`, not here.

### Domain Invariants

**Business invariants**: one declarative rule, then its violation consequence. If the input doesn't show the consequence, put the question in 7. Backlog instead of writing the invariant.

> Bad: `승인 후 금액 변경 불가`
> Good: `승인된 계약의 금액은 변경할 수 없다. 변경하면 정산 금액이 승인 금액과 달라진다.`

Tag each invariant with its 출처. Do not number invariants — the TDD skill assigns its own IDs when it imports them.

| 출처 | Means | Review priority |
|------|-------|-----------------|
| `[문서]` | Stated in the requirements document as written | Lowest — already agreed |
| `[사용자확인]` | The user answered a question about it in this conversation | Low |
| `[코드추론]` | Read off code. The reason is not confirmed | **Highest** |

Use `[사용자확인]` only when the user actually answered. Without that answer, keep a code-derived invariant as `[코드추론]`.

**Isolation invariants.** When the input says a new implementation must stay separate from an existing one that is still in service, write the separation as two invariants:

> `신규 코드는 기존 테이블을 읽거나 쓰지 않는다.`
> `기존 코드는 신규 테이블을 읽거나 쓰지 않는다.`

### 기존 코드의 함정

**Purpose**: stop the new code from copying defects in the code it follows or calls. An agent treats existing code as the right answer, so a defect left unwritten ships again.

- One `#### 함정 N.` entry per defect, in the template's order: `현재 코드` → `왜 문제인가` → table → `→ 신규는` → `기존 코드`. No summary table above the entries.
- **`현재 코드`**: one location per line.
- **Table**: only when the defect gives a wrong result for some input — condition / current / expected. The test takes this shape later. Otherwise omit it.
- **`→ 신규는`**: required in every entry — the concrete alternative. Without it, the agent invents its own. Number multiple instructions.
- **`기존 코드`**: fix the existing defect in this ticket or split it out, and why, in one sentence, with the `Dec-N` that decided it. Left empty, the agent fixes legacy code outside this change.
- `왜 문제인가` and the `기존 코드` reason each stay one sentence.

### Writing Style

- **One fact per sentence.** Split facts joined by `~지만`, `~며`, `~고`, `그래서`.
- **No parenthetical asides.** An aside that matters becomes its own sentence; otherwise drop it. Code identifiers, literal values, and `4-x` references in parentheses are fine.
- **No vague words.** Replace `적절히`, `필요 시`, `등`, `관련`, `처리한다` with the value, condition, or name they stand for. If the input doesn't say, ask.
- **No filler.** Drop `기본적으로`, `참고로`, `~하는 것이 좋다`, `~할 수 있도록 한다`.
- **Table cells**: the content in one sentence, plus at most one sentence of reason.

> Bad: `PartitionStrategy(999건) 단위로 나눠 조회해 조립 — MSSQL 파라미터 2,100개 제한 대비(목록 size 상한 없음). 빈 목록이면 쿼리 없이 빈 리스트`
> Good: `` `PartitionStrategy`의 999건 단위로 나눠 조회한다. 목록 `size`에 상한이 없어 MSSQL 파라미터 2,100개 제한에 걸릴 수 있다. 목록이 비면 쿼리 없이 빈 리스트를 반환한다. ``

## Update Mode

Change only these places. Leave every other line as it is.

| Change | How |
|---|---|
| Phase status | Set 3. Plan `상태` to `doing` when the phase starts and `done` when all of its 4. Verification items pass |
| Verification check | Change `[ ]` to `[x]` for an item that passed |
| Backlog entry | Append `- [ ] 7-N. [할 일] — 출처: [where it came from]` with the next number |
| Superseded decision | After `decision-write` recorded a `Dec-M` that supersedes an earlier one, rewrite the parts that followed the old decision — pitfall `→ 신규는`, phase detail, snippets, tests — to follow `Dec-M`, and mark each rewritten part `(Dec-M)` |

The superseded-decision row is what keeps the plan rerunnable: the next run reads the snippets, so a snippet left on the old decision rebuilds the old design.

Do not sync names or expressions a refactor changed — a renamed constant, an if turned into a ternary. The plan states the design; the code is the truth for its own wording.

Any other change to Context, Scope, the phase goals, or the tests is a change of plan, not an update. Stop and tell the caller; when the change comes from a reversed decision, it goes through `decision-write` first.

## Output

Report the `plan.md` path and what changed, in one line per section touched.
