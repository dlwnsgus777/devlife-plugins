---
name: plan-creator
description: Writes the plan for any task, feature, or project as a task folder — docs/spec/{ticket}-{slug}/ (or {date}-{slug}/ without a ticket) with plan.md (what, and how for code work) and decisions.md (why).
  Use when the user requests a "계획 문서", "구현 계획", "실행 계획", "계획서 작성", or "plan document",
  or writes any Korean sentence combining "계획" with a writing intent verb
  ("작성", "써줘", "정리", "만들어줘") — even if no specific file is mentioned.
---

# Plan Creator

<!-- Chain: devlife-brainstorming → spec-creator → plan-creator → tdd-subagent | tdd-agent-team -->

## Process

### Requirements Document (Optional)

A requirements document is any document that states what this task must do — a spec, a design document, or a ticket. If one is provided, read it before anything else.

- Take its domain context, invariants, and scope as given. Do not re-derive them in Step 1.
- Identify which part of the document this plan covers. If it covers several tasks and the request names none, ask before Step 1.
- Skip any Step 2 question the document already answers.
- If Step 1 finds code that contradicts the document, raise it in Step 2 instead of silently following either side.

### Existing Task Folder

Each task has one folder, `docs/spec/{ticket}-{slug}/` — `{YYYY-MM-DD}-{slug}` when there is no ticket. If the request names a folder, or one for the same ticket or feature already exists under `docs/spec/`, read its `plan.md` and `decisions.md` before Step 1 and continue in that folder.

- Decisions in `decisions.md` without a `[SUPERSEDED by Dec-M]` marker are active. Take them as settled and skip any Step 2 question they answer.
- Reopen an active decision only when Step 1 finds a fact the entry didn't have. Raise it in Step 2 with that fact; the reversal goes through `decision-write`.

### Step 1: Context Gathering

**Purpose**: ground the plan in the code before writing it. Step 1 finds the packages and classes the new code joins, the business invariants it must keep, the code to reuse, the defects not to copy, and — when modifying existing code — the restructuring that makes the change easy. What the code cannot settle, such as the business reason behind a rule or the choice of target structure, becomes a Step 2 question.

**Widen the scope as needed; never shrink the category list.**

- **Scope** — start at the narrowest scope that contains the target the request names: the target file and its direct callers, then its package, then its domain. Discovery output takes up more of this skill's context window than anything else, and an unscoped sweep of a domain with a lot of existing code returns far more than the plan can use. A scope that turns out too small costs only one more sweep, so widen it on the signals below.
- **Categories** — request every category on every sweep. The only exception is skipping category 6 when a requirements document already fixed the invariants: re-deriving them from guard clauses only restates what the document settled, as weaker `[코드추론]` evidence. A category never requested leaves no trace in the results, so you cannot tell later that it is missing.

1. Spawn a sub-agent via `Agent({ subagent_type: "Explore", ... })` with the prompt below.
2. If the Explore agent is unavailable, tell the user `not available`, then run the same sweep yourself — same scope, same categories — with the Glob, Grep, and Read tools.

Widen the scope one step — file, then package, then domain — and run the sweep again when the results show any of these:

- code outside the current scope calls the target code — from another domain, or an aggregate the request never named
- a guard clause, validation annotation, or enum transition the change must satisfy, whose reason is not visible inside the current scope
- a defect in an implementation this change references, where the sweep saw only part of that code because it sits on the scope boundary

Stop widening when a sweep shows none of these.

The categories:

| # | Category | Used in |
|---|----------|---------|
| 1 | Every entry point that starts [feature] — any code that receives an outside trigger: an HTTP request, a schedule, a message, or an event. E.g., controllers, batch jobs, message listeners. For each: the trigger (path, schedule, topic), the method signature, and the package path of the entry point and the classes it calls | Placement scan, `plan.md` 3 phase files |
| 2 | Services in the current scope — class names, public method signatures | Reuse scan |
| 3 | Domain models/entities — class names, fields the change touches, enum values | `plan.md` 1 |
| 4 | Classes that already wrap "find by id, throw if missing" (e.g., a `ReadService`) | Reuse scan, `plan.md` 3 snippets |
| 5 | Exception classes thrown in the current scope, and where they are thrown | `plan.md` 3 snippets |
| 6 | Validation annotations and guard clauses that reveal business constraints | `plan.md` 1 invariants |
| 7 | Existing tests that already verify behavior this requirement touches | `plan.md` 4 `[REGRESSION]` |
| 8 | **Defects in the existing implementation this requirement will reference** — e.g., paging/offset math, boundary values (date & time precision), joins that can't use an index, duplicated conditions, branches that silently drop a filter. For each: what the code does *and* why it's wrong. | Pitfall scan, `plan.md` 1 함정 |

Explorer prompt:

> "Requirement: [the requirement in one or two sentences]
>
> Scan [the current sweep scope] in this project and report the categories below — **file paths and signatures only, no full implementations**. The one exception is category 8: for each defect, give `path:line`, what the code does, and why it's wrong, in one or two sentences.
> Cap each category at the **8 entries most relevant to the requirement**. If there are more, list the top 8 and add a `+N more` count line rather than enumerating them.
> Category 7 means tests whose behavior overlaps the requirement — not an inventory of the domain's test suite.
> Use only Glob, Grep, Read tools. Do not use Bash.
>
> [the numbered categories above — the Category column only]"

After discovery, read directly every file from categories 3 and 6 that the change modifies or calls — usually 2–3 — to identify business invariants (guard clauses, state transitions, validation annotations). Read nothing outside that set; the Explore results already cover the rest.

**Reuse scan** — keep the new code from rebuilding what already exists.
- From Explore categories 2, 4, and 5, find classes that already do what the new code needs.
- Inject a category 4 class instead of wiring a repository directly.
- Show the reused classes in the phase file tables and code snippets of `plan.md` 3.

**Pitfall scan** — keep the new code from copying existing defects. An agent treats existing code as the right answer, so a defect left unwritten ships again.
- From category 8 and the files you read, keep only defects in code the new code will imitate or call.
- Each becomes a `plan.md` 1 기존 코드의 함정 entry with a `→ 신규는` decision. None → `해당 없음`.

**Placement scan** (when the plan adds a class) — put each new class where the project already puts that kind of class.
- Find where same-role classes of the same domain live, using category 1. That is the default.
- If the class should go elsewhere, or the domain is already split across locations, ask in Step 2.
- With no existing location, follow the project's documented layout rule, such as in CLAUDE.md. With no rule, ask.

**Target structure scan** (only when the task modifies existing code) — find the restructuring that makes this requirement easy to add. A smell the requirement doesn't touch is not a candidate. The candidates go to Step 2, and the one the user picks becomes the Tidy First phase of `plan.md` 3.

1. **Picture the target, then derive the restructuring.** In the target, the requirement goes in by adding a class, method, or field, without editing existing branches. Example shapes — use another if none fits:

   | The requirement adds | Target shape | What the requirement becomes |
   |---|---|---|
   | a case to an existing branch axis (type, channel, policy) | existing cases as implementations of one abstraction (Replace Conditional with Polymorphism, Strategy) | a new class |
   | a new rule about an existing concept | the rule's data and behavior in one domain object (Move Method, Extract Class) | a method or guard on that object |
   | a new step in a flow | the flow split into named steps (Compose Method) | one new method |
   | a new input value | scattered parameters gathered into one object (Introduce Parameter Object) | a field on that object |

2. **Stay inside the existing design** — same layers, packages, and patterns. A design change goes to `plan.md` 7. Backlog as separate work. Callers of the restructured code stay in this change's scope.
3. **Weigh ease against added complexity.** Add an abstraction only when this requirement adds a case to its axis — never an interface with one implementation.
4. **Build the candidates** — the current structure plus each restructuring that makes the requirement easier. Merge restructurings whose reach overlaps. For each: the restructuring and technique, its reach (callers, tests), and what the feature work adds. When existing tests don't cover the restructured code, say so in its reach, with the characterization tests it needs first. Let the user pick in Step 2.
5. **If the requirement already goes in by adding alone**, skip the Step 2 question and write `해당 없음` with one sentence on why.

### Step 2: Clarifying Questions

**Purpose**: keep guesses out of the plan. Ask before writing; never leave a decision or ambiguity in the document as a note like "별도 확인 필요".

Situations that require asking:
- **Domain context the code can't explain** — if neither the code nor the requirements document gives the business reason behind a concept (e.g., "왜 이 상태에서는 금액 변경이 불가능한가?"), ask.
- **Business invariants backed only by a guard clause** — the `[코드추론]` ones. Don't infer the rule's intent from the guard clause; ask for its violation consequence and where the constraint comes from.
- **Ambiguous domain terms** — one term used with several meanings, or one concept under several names.
- **The target structure from Step 1** — show the Step 1 candidates side by side, recommend one and say why, then let the user decide. When an abstraction is among them, ask whether its axis keeps growing — that answer weighs most. For example:

  > "[기능]을 넣는 방법이 두 가지입니다.
  > A. 지금 구조 — `calculateFee()`에 분기 추가. 채널 분기가 4개가 됩니다.
  > B. `FeePolicy` 구현체로 정비 후 추가. `SettlementService`와 호출부 2곳이 바뀝니다.
  > 채널이 계속 늘면 B를 추천합니다. 채널이 더 늘어날 예정인가요?"
- **Separation from an existing implementation** — Step 1 found one still in service doing the same job, and the new one uses its own tables. Ask whether the two must stay separate.
- **Placement the Step 1 placement scan sent here** — which package or existing class a new class joins. For example:

  > "새 API를 기존 `[Controller]`에 추가할까요, `[다른 위치]`로 분리할까요? [이유]로 분리를 추천합니다."

**How to ask** — get answers precise enough to write the plan without guessing.
- Ask in plain Korean messages, not `AskUserQuestion` — open questions need open answers. A plain A/B list is fine when the options are fixed.
- Ask in rounds of up to 4 and wait for the answers; they shape the next round.
- **Point and reason only.** Each question states what needs deciding and why the plan needs it, one sentence each. Each option gets one line. Leave out background the user already knows.
- Ask only what the plan needs and nothing yet answers — not the requirements document, Step 1, or earlier answers. Typical topics: goal, affected modules, endpoint shape, data source, success criteria.
- Stop when no such question is left. Ask again when an answer contradicts another or allows more than one plan.

**Reading answers** — catch answers that look like answers but can't go into the plan. Before deciding you have enough:
- **A one-word answer to a why/how question** — ask for the reason or detail.
- **"알아서 해주세요" / "네가 판단해줘"** — give your recommendation with its reason and ask whether to go with it.
- **An answer to a different question** — ask the original question again.

**Contradiction check (before writing)** — don't build the plan on two answers that can't both hold. Cross-read the answers and the requirements document. The table shows common conflicts, not a complete list:

| Conflict | Example |
|---|---|
| 범위 | "간단하게 가자" + 다중 테넌트·감사 로그 요구 |
| 리스크 | "보안은 신경 안 써도 돼" + 개인정보 저장 |
| 기술 | "기존 응답 형식 유지" + "응답 필드 이름 변경" |
| 일정 vs 범위 | 최소 일정 + 전체 기능 |

When you find one, quote both sides, say why they conflict, and ask which to follow. Don't pick one yourself or leave the conflict as a note in the document.

**Continuing vs. stopping** — the user decides when writing starts.
- When no question is left, confirm first:

  > "지금까지 답변해주신 내용으로 계획 문서를 작성해도 괜찮을까요? 더 확인하고 싶은 부분이 있으신가요?"

- If the user stops while questions are still unanswered, list them once and follow the user's decision. Record them in `plan.md` 7. Backlog.

### Step 3: Write the Task Folder

**Purpose**: turn Step 1 and Step 2 results into the task folder.

```
docs/spec/
└ {ticket}-{slug}/
  ├ plan.md        ← plan-write: what the work does and, for code work, how it is built
  └ decisions.md   ← decision-write: why it was done that way
```

- **Folder**: `docs/spec/{ticket}-{slug}/`, unless the user gives a path. With no ticket, the date the folder is created takes its place: `docs/spec/{YYYY-MM-DD}-{slug}/`. The slug is a short kebab-case feature summary (e.g., `RB-2396-refund-limit`, `2026-11-18-refund-limit`). Create the folder if it doesn't exist; reuse it if the Existing Task Folder step found one.
- Write `decisions.md` first, because `plan.md` points to its `Dec-N` numbers.

#### 1. decisions.md

Invoke `decision-write` with the Skill tool, passing the folder path and every decision this run made:

| Decision | 출처 |
|---|---|
| Chosen by the user from options you presented in Step 2 — target structure, placement, separation from an existing implementation | `ai-suggested` |
| A direction the user stated before you offered options | `user-suggested` |
| Settled by you without asking — a placement default from the placement scan, a reused class, a pitfall's `→ 신규는`, a choice that follows existing behavior | `ai-selected` |

Record every `ai-selected` decision. The user never saw them, so they are what the user reviews first. Give each decision its 영향도 (`foundation` / `significant` / `local`).

If `decision-write` is not in the skill list, say `not available`, then append the entries yourself in its format: `### Dec-N. [제목]`, then `영향도 · 출처`, 문제, 옵션, 선택, 근거, 연관 설계. Never edit an existing entry.

#### 2. plan.md

Invoke `plan-write` with the Skill tool in its write mode, passing the folder path and:

- 의도, 배경, and the external constraints from the request and the requirements document;
- the domain invariants with their 출처 tags — `[문서]`, `[사용자확인]` only for invariants the user actually answered about in Step 2, `[코드추론]` for the ones read off Step 1 code;
- the existing patterns from the reuse and placement scans;
- the pitfalls from the pitfall scan, each with its `→ 신규는` and the `Dec-N` that decided it — `해당 없음` when the scan kept none;
- In / Out scope — every Out item also becomes a Backlog entry;
- the phases: a Tidy First phase first when the user chose a target structure in Step 2 (with its `Dec-N`), otherwise `정비 해당 없음` with the reason; then the feature phases;
- for code work, each phase's detail: 구현 대상 파일 from the placement and reuse scans, API, 비즈니스 로직, and 코드 스니핏 that inject the reused classes and guard each invariant;
- the tests per phase — `[NEW]` or `[REGRESSION]` from Step 1 category 7, each described by a domain rule sentence, with boundary values for every rule that has a boundary;
- prerequisites, steps before deploy, and what a person checks by hand;
- the terms whose meaning Step 2 settled;
- the Backlog: Out items, design changes found by the target structure scan, and Step 2 questions left unanswered.

If `plan-write` is not in the skill list, say `not available`, then write `plan.md` yourself from its template structure: 1. Context (with 기존 코드의 함정), 2. Scope, 3. Plan (phase table, then one `### Phase N.` subsection per phase), 4. Verification, 5. Prerequisites, 6. Glossary, 7. Backlog.

**Non-code work** (e.g., a runbook, a document, an investigation) — `plan.md` keeps the phase table without phase detail, and 기존 코드의 함정 is left out. Self-Review checks tied to snippets and the Step 5 TDD handoff don't apply.

### Step 3.5: Self-Review

**Purpose**: catch gaps before the user reviews the folder.

After writing the documents, run these nine checks. Fix whatever needs no decision from the user; no need to re-check after fixing.

**1. Requirements coverage** (when a requirements document was provided):
- **Scope**: the requirements of the task chosen in the Requirements Document step — the whole document if it holds one task.
- **List**: if the document numbers them or uses a checklist, use that list. Otherwise, take each sentence that states what the system must do ("~해야 한다", "~하면 ~한다").
- **Match**: for each requirement, find a `plan.md` 4. Verification entry that tests it. If none exists, add one.
- **Unclear task**: if the document doesn't say which task a requirement belongs to, write it in `plan.md` 7. Backlog as a question.

**2. Placeholder scan**: outside `plan.md` 7. Backlog, find these patterns. Replace each with which class and method, under what condition, does what. If you don't know it, move it to the Backlog as a question.
- "TBD", "TODO", "추후 확인", "별도 확인 필요"
- "적절한 예외 처리 추가" / "유효성 검증 추가" with no class, condition, or action
- A `plan.md` 3 snippet whose method body is empty or a `// TODO`

**3. Test description check**: is every `plan.md` 4. Verification test description — the sentence shown in test results — a domain rule sentence?

**4. Consistency**: every class and method name appears, spelled the same, in:
- the phase file tables of `plan.md` 3
- the phase `코드 스니핏` of `plan.md` 3
- the `plan.md` 4. Verification entries
A name missing from one place means a missing file, signature, or test — add it there.

**5. Tidy First justification**: for every entry in the Tidy First phase of `plan.md` 3 —
- Does it point to a `Dec-N` whose 출처 is `ai-suggested` or `user-suggested` — a structure the user chose?
- Does its `본 작업에서 추가할 것` appear as a test in a feature phase of `plan.md` 4?
- Without it, would the requirement need edits to existing branches?
- Does its reach stay inside this change's scope?
Delete an entry the user didn't choose. When one the user chose fails another check, report it in Step 4. If every entry is deleted, write `해당 없음` with the reason.

**6. Invariant coverage**:
- Is every `plan.md` 1 domain invariant verified by at least one `plan.md` 4 test?
- Does every rule with a boundary — a threshold, a cap, a range — list both the boundary value and the value one unit before it, with expected results? Add the missing side.
- Does every test trace back to an invariant, the requirements document, or the user's request? For one that doesn't: if it checks an unwritten invariant, add the invariant; if it is scope creep, delete the test; if you can't tell, move it to the Backlog as a question.
- Does every `[사용자확인]` invariant have an answer the user actually gave in this conversation? If not, change it to `[코드추론]` when Step 1 code shows it; otherwise remove it and move its question to the Backlog.

**7. Sentence check**: search `plan.md` once with the Grep tool for `며 |지만 |그래서|고 |\(`, and keep the hits outside code blocks. Also take every table cell with more than two sentences. Decide every hit first:
- Two facts joined → split into two sentences.
- An aside in parentheses → its own sentence, or drop it. Code identifiers, literal values, and `N-x` references stay.
- A table cell longer than a decision plus one reason → keep those two; move a procedure to the phase's 비즈니스 로직 and point to it.
- None of these → leave it.
Then apply all changes in one edit per section. Confirm every path, constraint, and value is still there. Report how many sentences you changed.

**8. Decisions check**:
- Does every Step 2 decision and every `ai-selected` choice have a `Dec-N`?
- Is every existing entry still there, with its number and body unchanged?
- Does every superseded entry carry `[SUPERSEDED by Dec-M]`, and does Dec-M say `변경 히스토리 — ... 사용자 승인`?

**9. Scope check**: does every `plan.md` 2. Scope Out item have a 7. Backlog entry?

**Report the result in Step 4**, so the user sees what was checked:

```
자체 검증: 9개 항목 중 7개 통과
- 고침 2번 (플레이스홀더): plan.md Phase 2 비즈니스 로직의 "예외 처리 추가" → `RefundService.refund()`에서 환불액이 결제액보다 크면 `RefundAmountExceededException`
- 고침 7번 (문장): plan.md 1·3에서 문장 5개를 나눔
- 결정 필요 5번 (Tidy First 정당성): 고르신 `FeePolicy` 추출(Dec-2)이 `BatchSettler`까지 닿아 이번 변경 범위를 넘습니다
[코드추론] 불변성
- 계약 해지 요청은 원계약이 존재하는 상태에서만 가능하다
ai-selected 결정 (foundation·significant)
- Dec-4. 환불 한도 조회는 기존 `RefundPolicyReadService`를 재사용 — significant
```

An item that needs the user's decision blocks Step 5 until it is resolved. Questions moved to the Backlog don't block.

### Step 4: Request Feedback (Mandatory)

**Purpose**: get the user's approval of the plan before any code is written.

After Self-Review, send one normal message — no option tool, so the user can answer freely — in this order:
1. The task folder path and the documents in it
2. The Self-Review report from Step 3.5
3. The request:

> "계획 문서에 피드백을 주실 수 있을까요?
> 특히 [결정 필요 항목 / `[코드추론]` 불변성 / `ai-selected` 결정 / Tidy First 목표 구조 — 이 계획에 있는 것]에 대한 의견을 부탁드립니다."

Apply the feedback and ask again.

- Feedback that changes `plan.md` content → rewrite it with `plan-write`'s write mode.
- Feedback that reverses a recorded decision → the user's feedback is the approval. Invoke `decision-write` to append the new entry, with `변경 히스토리 — Dec-M 대체, 사용자 승인`, and to mark the old one superseded. Never edit the old entry's body. Then invoke `plan-write` in its update mode so the parts that followed the old decision — pitfalls, phase detail, snippets, tests — follow the new one.
- Feedback that adds a decision → invoke `decision-write` with 출처 `user-suggested`.

Do not proceed to Step 5 without explicit approval.

### Step 5: Hand Off to a TDD Skill (Terminal State)

**Purpose**: let the user choose how implementation starts. plan-creator ends here.

Once approved, ask with `AskUserQuestion`:
- `tdd-subagent` — 서브에이전트가 RED → GREEN → REFACTOR를 태스크마다 순차로 진행, 사이클마다 리뷰
- `tdd-agent-team` — RED·GREEN 팀원이 병렬로 진행하고 마지막에 리뷰어 3명이 교차 검토 (agent teams 기능 필요)
- 여기서 마치기

If the chosen skill is in the skill list, invoke it with the Skill tool and pass the task folder path as its argument. If it isn't in the list, or the user chose to stop, say so and give the task folder path.
