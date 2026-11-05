---
name: plan-creator
description: Writes a structured Markdown plan document for any task, feature, or project.
  Use when the user requests a "계획 문서", "구현 계획", "실행 계획", "계획서 작성", or "plan document",
  or writes any Korean sentence combining "계획" with a writing intent verb
  ("작성", "써줘", "정리", "만들어줘") — even if no specific file is mentioned.
---

# Plan Creator

<!-- Chain: devlife-brainstorming → spec-creator → plan-creator → tdd-subagent -->

## Process

### Requirements Document (Optional)

A requirements document is any document that states what this task must do — a spec, a design document, or a ticket. If one is provided, read it before anything else.

- Take its domain context, invariants, and scope as given. Do not re-derive them in Step 1.
- Identify which part of the document this plan covers. If it covers several tasks and the request names none, ask before Step 1.
- Skip any Step 2 question the document already answers.
- If Step 1 finds code that contradicts the document, raise it in Step 2 instead of silently following either side.

### Step 1: Context Gathering

**Purpose**: ground the plan in the code before writing it. Step 1 finds the packages and classes the new code joins, the business invariants it must keep, the code to reuse, the defects not to copy, and — when modifying existing code — the restructuring that makes the change easy. What the code cannot settle, such as the business reason behind a rule or the choice of target structure, becomes a Step 2 question.

**Widen the scope as needed; never shrink the category list.**

- **Scope** — start at the narrowest scope that contains the target the request names: the target file and its direct callers, then its package, then its domain. Discovery output takes up more of this skill's context window than anything else, and an unscoped sweep of a domain with a lot of existing code returns far more than the plan can use. A scope that turns out too small costs only one more sweep, so widen it on the signals below.
- **Categories** — request every category on every sweep. The only exception is skipping category 6 when a requirements document already fixed the invariants: re-deriving them from guard clauses only restates what the document settled, as weaker `[코드추론]` evidence. A category never requested leaves no trace in the results, so you cannot tell later that it is missing.

1. Discover the available multi-agent tool with `tool_search`.
2. Spawn an explorer sub-agent with the prompt below.
3. If no Codex sub-agent tool is available, tell the user `not available`, then run the same sweep yourself — same scope, same categories — with `rg`, `rg --files`, and reads of the files the results point to.

Do not use Claude Code `Agent({ ... })` syntax.

Widen the scope one step — file, then package, then domain — and run the sweep again when the results show any of these:

- code outside the current scope calls the target code — from another domain, or an aggregate the request never named
- a guard clause, validation annotation, or enum transition the change must satisfy, whose reason is not visible inside the current scope
- a defect in an implementation this change references, where the sweep saw only part of that code because it sits on the scope boundary

Stop widening when a sweep shows none of these.

The categories:

| # | Category | Used in |
|---|----------|---------|
| 1 | Every entry point that starts [feature] — any code that receives an outside trigger: an HTTP request, a schedule, a message, or an event. E.g., controllers, batch jobs, message listeners. For each: the trigger (path, schedule, topic), the method signature, and the package path of the entry point and the classes it calls | Placement scan, Section 6 |
| 2 | Services in the current scope — class names, public method signatures | Reuse scan |
| 3 | Domain models/entities — class names, fields the change touches, enum values | Section 2 |
| 4 | Classes that already wrap "find by id, throw if missing" (e.g., a `ReadService`) | Reuse scan, Section 6 snippets |
| 5 | Exception classes thrown in the current scope, and where they are thrown | Section 6 snippets |
| 6 | Validation annotations and guard clauses that reveal business constraints | Section 2 invariants |
| 7 | Existing tests that already verify behavior this requirement touches | Section 8 `[REGRESSION]` |
| 8 | **Defects in the existing implementation this requirement will reference** — e.g., paging/offset math, boundary values (date & time precision), joins that can't use an index, duplicated conditions, branches that silently drop a filter. For each: what the code does *and* why it's wrong. | Pitfall scan, Section 3 |

Explorer prompt:

> "Requirement: [the requirement in one or two sentences]
>
> Scan [the current sweep scope] in this project and report the categories below — **file paths and signatures only, no full implementations**. The one exception is category 8: for each defect, give `path:line`, what the code does, and why it's wrong, in one or two sentences.
> Cap each category at the **8 entries most relevant to the requirement**. If there are more, list the top 8 and add a `+N more` count line rather than enumerating them.
> Category 7 means tests whose behavior overlaps the requirement — not an inventory of the domain's test suite.
>
> [the numbered categories above — the Category column only]"

After discovery, read directly every file from categories 3 and 6 that the change modifies or calls — usually 2–3 — to identify business invariants (guard clauses, state transitions, validation annotations). Read nothing outside that set; the Explore results already cover the rest.

**Reuse scan** — keep the new code from rebuilding what already exists.
- From Explore categories 2, 4, and 5, find classes that already do what the new code needs.
- Inject a category 4 class instead of wiring a repository directly.
- Show the reused classes in Section 6's file table and code snippets.

**Pitfall scan** — keep the new code from copying existing defects. An agent treats existing code as the right answer, so a defect left unwritten ships again.
- From category 8 and the files you read, keep only defects in code the new code will imitate or call.
- Each becomes a Section 3 entry with a `→ 신규는` decision. None → `해당 없음`.

**Placement scan** (when the plan adds a class) — put each new class where the project already puts that kind of class.
- Find where same-role classes of the same domain live, using category 1. That is the default.
- If the class should go elsewhere, or the domain is already split across locations, ask in Step 2.
- With no existing location, follow the project's documented layout rule, such as in CLAUDE.md. With no rule, ask.

**Target structure scan** (only when the task modifies existing code) — find the restructuring that makes this requirement easy to add. A smell the requirement doesn't touch is not a candidate. The candidates go to Step 2, and the one the user picks goes to Section 0.

1. **Picture the target, then derive the restructuring.** In the target, the requirement goes in by adding a class, method, or field, without editing existing branches. Example shapes — use another if none fits:

   | The requirement adds | Target shape | What the requirement becomes |
   |---|---|---|
   | a case to an existing branch axis (type, channel, policy) | existing cases as implementations of one abstraction (Replace Conditional with Polymorphism, Strategy) | a new class |
   | a new rule about an existing concept | the rule's data and behavior in one domain object (Move Method, Extract Class) | a method or guard on that object |
   | a new step in a flow | the flow split into named steps (Compose Method) | one new method |
   | a new input value | scattered parameters gathered into one object (Introduce Parameter Object) | a field on that object |

2. **Stay inside the existing design** — same layers, packages, and patterns. A design change goes to Section 7 as separate work. Callers of the restructured code stay in this change's scope.
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
- Ask in plain Korean messages, not a fixed-option input tool — open questions need open answers. A plain A/B list is fine when the options are fixed.
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

- If the user stops while questions are still unanswered, list them once and follow the user's decision. Record them in Section 7.

### Step 3: Write the Plan Document

**Purpose**: turn Step 1 and Step 2 results into the plan.

- **File**: `docs/plan/task-{feature}.md`, with a short kebab-case feature summary (e.g., `task-payment-refund.md`), unless the user gives a name or path.
- **Code work** — the template is for code work only. Read `assets/plan-template.md` and follow it.
  - Omit a section only when Step 1 and Step 2 produced nothing for it — e.g., Section 4 when the change has no endpoint, such as batch or refactoring work. A section left out because nobody looked is the blind spot this rule prevents.
  - Never omitted: Section 3, and Section 0 when modifying existing code. With nothing to write, they say `해당 없음`.
  - Section 7: the risks Step 1 or Step 2 found (failure modes, scale), and only the open questions whose answer would change Section 6 or 8. A choice that follows existing behavior is not a question — state it once under `기존 동작을 따름`.
- **Non-code work** (e.g., a runbook, a document, an investigation) — skip the template and use the structure that fits the task. Self-Review checks tied to template sections and the Step 5 TDD handoff don't apply.

#### Writing Style

**Purpose**: the plan is reread before every coding step, so each sentence should be read once and understood.

All plans:
- **One fact per sentence.** Split facts joined by `~지만`, `~며`, `~고`, `그래서`.
- **No parenthetical asides.** An aside that matters becomes its own sentence; otherwise drop it. Code identifiers, literal values, and `3-x` references in parentheses are fine.
- **No vague words.** Replace words that leave the reader guessing — `적절히`, `필요 시`, `등`, `관련`, `처리한다` — with the value, condition, or name they stand for. If you don't know it, ask the user.
- **No filler.** Drop words that add no fact — `기본적으로`, `참고로`, `~하는 것이 좋다`, `~할 수 있도록 한다`.

> Bad: `PartitionStrategy(999건) 단위로 나눠 조회해 조립 — MSSQL 파라미터 2,100개 제한 대비(목록 size 상한 없음). 빈 목록이면 쿼리 없이 빈 리스트`
> Good: `` `PartitionStrategy`의 999건 단위로 나눠 조회한다. 목록 `size`에 상한이 없어 MSSQL 파라미터 2,100개 제한에 걸릴 수 있다. 목록이 비면 쿼리 없이 빈 리스트를 반환한다. ``

Code-work template:
- **Table cells**: the decision in one sentence, plus at most one sentence of reason. A procedure goes in Section 5, and the cell points to it.
- **Section 2 invariants**: at most two rule sentences, plus the violation consequence in one sentence.
- **Section 3 items**: `왜 문제인가` and the `기존 코드` reason (fix or split) stay, each in one sentence.

#### Domain Context & Invariants (Section 2)

**Purpose**: give the reader the domain rules the change must keep, each with its source.

**Never guess.** Write only what the requirements document, the code, or the user's answers show. Ask the user about anything else before writing it.

**Domain context**: prose describing the concepts the change touches and the assumptions they rely on.

**Business invariants**: one declarative rule, then its violation consequence. If the requirements document, the code, and the answers don't show the consequence, ask the user.

> Bad: `승인 후 금액 변경 불가`
> Good: `승인된 계약의 금액은 변경할 수 없다. 변경하면 정산 금액이 승인 금액과 달라진다.`

Tag each invariant with a 출처 tag from the table below. Do not number invariants — tdd-subagent assigns its own IDs when it imports them.

Invariants extracted from Step 1 code — enum state transitions, validation annotations, guard clauses — are `[코드추론]`. Use `[사용자확인]` only when the user actually answered a Step 2 question about the invariant in this conversation. Without that answer, keep a code-derived invariant as `[코드추론]`; leave out any other, and list its question in Section 7.

| 출처 | Means | Review priority |
|------|-------|-----------------|
| `[문서]` | Stated in the requirements document as written | Lowest — already agreed |
| `[사용자확인]` | Answered by the user in Step 2 | Low |
| `[코드추론]` | Read off Step 1 code. The reason is not confirmed | **Highest — list these separately in the Step 4 report** |

**Isolation invariants.**
**Purpose**: catch new and existing code reading or writing each other's tables. Separate tables are not enough: one query that reads both, or one event that makes a save on one side change the other side's table, breaks the separation.

When Step 1 finds an existing implementation of the same feature still in service, and the new one uses its own tables, ask in Step 2 whether the two must stay separate — unless the requirements document already says. Only when the document or the user's answer requires separation, write it as two invariants:

> `신규 코드는 기존 테이블을 읽거나 쓰지 않는다.`
> `기존 코드는 신규 테이블을 읽거나 쓰지 않는다.`

#### 기존 코드의 함정 (Section 3)

**Purpose**: stop the new code from copying defects in the code it follows or calls.

- One subsection per defect from Step 1's pitfall scan, in the template's order: `현재 코드` → `왜 문제인가` → table → `→ 신규는` → `기존 코드`. No summary table above the subsections.
- **`현재 코드`**: one location per line.
- **Table**: only when the defect gives a wrong result for some input — condition / current / expected. The test takes this shape later. Otherwise omit it.
- **`→ 신규는`**: required in every entry — the concrete alternative. Without it, the agent may copy the defective code as is. Number multiple instructions.
- **`기존 코드`**: fix the existing defect in this ticket or split it out, and why, in one sentence. Left empty, the agent fixes legacy code outside this change.
- No referenced implementation, or no defects found → `해당 없음`. Don't pad the section.

### Step 3.5: Self-Review

**Purpose**: catch gaps before the user reviews the plan.

After writing the document, run these seven checks. Fix whatever needs no decision from the user; no need to re-check after fixing.

**1. Requirements coverage** (when a requirements document was provided):
- **Scope**: the requirements of the task chosen in the Requirements Document step — the whole document if it holds one task.
- **List**: if the document numbers them or uses a checklist, use that list. Otherwise, take each sentence that states what the system must do ("~해야 한다", "~하면 ~한다").
- **Match**: for each requirement, find a Section 8 entry that implements or tests it. If none exists, add one.
- **Unclear task**: if the document doesn't say which task a requirement belongs to, write it in Section 7 as a question.

**2. Placeholder scan**: outside Section 7, find these patterns. Replace each with which class and method, under what condition, does what. If you don't know it, move it to Section 7 as a question.
- "TBD", "TODO", "추후 확인", "별도 확인 필요"
- "적절한 예외 처리 추가" / "유효성 검증 추가" with no class, condition, or action
- A Section 8 entry that only says "구현한다" without naming the class and method
- A Section 6 snippet whose method body is empty or a `// TODO`

**3. Test description check**: is every Section 8 test description — the sentence shown in test results — a domain rule sentence?

**4. Consistency**: every class and method name appears, spelled the same, in all three places:
- the Section 6 file table
- the Section 6 `코드 스니핏`
- the Section 8 implementation entries
A name missing from one place means a missing file, signature, or step — add it there.

**5. Section 0 justification**: for every Section 0 entry —
- Does its `본 작업에서 추가할 것` appear as a Section 8 behavior-change entry?
- Without it, would the requirement need edits to existing branches?
- Does its reach stay inside this change's scope?
- Did the user choose it in Step 2?
Delete an entry the user didn't choose. When one the user chose fails another check, report it in Step 4. If every entry is deleted, write `해당 없음` with the reason.

**6. Invariant coverage**:
- Is every Section 2 invariant verified by at least one Section 8 test?
- Does every Section 8 test trace back to an invariant, the requirements document, or the user's request? For one that doesn't: if it checks an unwritten invariant, add the invariant to Section 2; if it is scope creep, delete the test; if you can't tell, move it to Section 7 as a question.
- Does every `[사용자확인]` invariant have an answer the user actually gave in this conversation? If not, change it to `[코드추론]` when Step 1 code shows it; otherwise remove it and move its question to Section 7.

**7. Sentence check**: search the plan file once with `rg -n` for `며 |지만 |그래서|고 |\(`, and keep the hits outside code blocks. Also take every table cell with more than two sentences. Decide every hit first:
- Two facts joined → split into two sentences.
- An aside in parentheses → its own sentence, or drop it. Code identifiers, literal values, and `3-x` references stay.
- A table cell longer than a decision plus one reason → keep those two; move a procedure to Section 5 and point to it.
- None of these → leave it.
Then apply all changes in one edit per section. Confirm every path, constraint, and value is still in the plan. Report how many sentences you changed.

**Report the result in Step 4**, so the user sees what was checked:

```
자체 검증: 7개 항목 중 5개 통과
- 고침 2번 (플레이스홀더): 섹션 5-2의 "예외 처리 추가" → `RefundService.refund()`에서 환불액이 결제액보다 크면 `RefundAmountExceededException`
- 고침 7번 (문장): 섹션 2·3에서 문장 5개를 나눔
- 결정 필요 5번 (섹션 0 정당성): 고르신 `FeePolicy` 추출이 `BatchSettler`까지 닿아 이번 변경 범위를 넘습니다
[코드추론] 불변성
- 계약 해지 요청은 원계약이 존재하는 상태에서만 가능하다
```

An item that needs the user's decision blocks Step 5 until it is resolved. Questions moved to Section 7 don't block.

### Step 4: Request Feedback (Mandatory)

**Purpose**: get the user's approval of the plan before any code is written.

After Self-Review, send one normal message — no option tool, so the user can answer freely — in this order:
1. The plan document path
2. The Self-Review report from Step 3.5
3. The request:

> "계획 문서에 피드백을 주실 수 있을까요?
> 특히 [결정 필요 항목 / `[코드추론]` 불변성 / 섹션 0 목표 구조 — 이 계획에 있는 것]에 대한 의견을 부탁드립니다."

Apply the feedback and ask again. Do not proceed to Step 5 without explicit approval.

### Step 5: Hand Off to a TDD Skill (Terminal State)

**Purpose**: let the user choose how implementation starts. plan-creator ends here.

Once approved, ask:

> "계획 문서가 완성되었습니다. tdd-subagent로 이어서 구현을 시작할까요, 아니면 여기서 마칠까요?"

If they continue and `tdd-subagent` is in the skill list, read its `SKILL.md` and pass the plan document path as input. If it isn't in the list, or they choose to stop, say so and give the plan document path.
