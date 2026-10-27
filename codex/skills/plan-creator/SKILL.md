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

### Document Input (Optional)

If a spec document path is provided (from devlife-brainstorming or otherwise), read it before anything else. Take its domain context, invariants, and scope as given — do not re-derive them — identify which subtask this plan covers, and skip any Step 2 question it already answers.

### Step 1: Context Gathering

**Start at the narrowest scope that contains the target the request names, and widen when the results hit an edge.** Discovery output is the largest single thing entering this skill's context, and an unscoped sweep of a mature domain returns far more than the plan can use. But a scope guessed too small costs one more sweep, while a category never requested is a blind spot you cannot discover later — so the **scope is provisional and the category list is not**.

Widen and re-run when the sweep comes back with:

- callers reaching outside the scope you assumed — another domain, an aggregate the request never named
- a guard clause, validation annotation or enum transition the change has to satisfy, whose motivation the current scope does not explain
- a defect in the implementation this change references, in code the sweep only touched at its edge

Say it in one line and keep going:

> "탐색에서 [발견]이 나와 [도메인]까지 넓혀 다시 훑습니다."

1. Discover the available multi-agent tool with `tool_search`.
2. Spawn an explorer sub-agent with the prompt below.
3. If no Codex sub-agent tool is available, say `not available`, then perform the same scoped discovery locally with `rg`, `rg --files`, and focused file reads.

Do not use Claude Code `Agent({ ... })` syntax.

Request every category below on every sweep, whatever the scope:

| # | Category |
|---|----------|
| 1 | Controllers handling [feature] — paths, endpoint annotations, method signatures, and the package path of each controller and the classes it calls |
| 2 | Services in the same domain — class names, public method signatures |
| 3 | Domain models/entities — class names, key fields, enum values |
| 4 | `find-by-id + throw` patterns already encapsulated in ReadService classes |
| 5 | Related exception classes and where they're thrown |
| 6 | Validation annotations / guard clauses hinting at business constraints |
| 7 | Existing tests that already verify behavior this requirement touches |
| 8 | **Known defects in the existing implementation this requirement will reference** — paging/offset math, boundary values (date & time precision), joins that can't use an index, duplicated conditions, branches that silently drop a filter. For each: what the code does *and* why it's wrong. |

One cut, and it is evidence-based: skip **6** when a spec document already fixed the invariants (see Document Input). Re-deriving them from guard clauses redoes work the spec settled, and lands them as weaker `[코드추론]` evidence besides.

Name the current scope in the prompt — for a single-file fix that is the target file and its direct callers, not the domain.

Explorer prompt:

> "Scan [the current sweep scope] in this project and report the categories below — **file paths and signatures only, no full implementations**.
> Cap each category at the **8 most relevant** entries. If there are more, list the top 8 and add a `+N more` count line rather than enumerating them.
> Category 7 means tests whose behavior overlaps [requirement] — not an inventory of the domain's test suite.
>
> [the numbered categories above]"

After discovery, directly read only the 2–3 most relevant files to identify business invariants (guard clauses, state transitions, validation annotations).

**Reusable code scan**: From the Explore results, identify existing services, utilities, and exception classes that already handle overlapping concerns. In particular, if "find-by-id + throw" patterns are encapsulated in a ReadService, inject that service rather than wiring a repository directly — reflect this in the code snippets.

**Pitfall scan — the inverse of the reuse scan.** The reuse scan asks what to lean on; this one asks what **not to copy**. An agent reads existing code as this project's answer and reproduces its defects verbatim, so a defect you noticed but didn't write down will ship again. From the Explore category 8 results plus the 2–3 files you read, keep only defects the new code would actually inherit by imitation — a flaw in an unrelated corner of the codebase is not this plan's business. Each one needs a `→ 신규는` decision, not just a diagnosis. Nothing qualifies → `해당 없음`.

**Placement scan** (whenever the plan adds a new class): for each new file, find where the same feature's existing classes of the same role already live — read the package layout off Explore category 1 instead of assuming one. That location is the default. Placing a new file elsewhere, or finding the feature already spread across more than one location, is a structural decision the code cannot settle: take it to Step 2 instead of fixing it in Section 6. A feature with no existing location follows the project's documented layout rule; with no rule, ask.

**Target structure scan** (only when the task modifies existing code). Work backwards from the requirement: first picture the structure the requirement would go into without strain, then derive the restructuring that moves the existing code there. That restructuring is Tidy First; adding the requirement on top of it is the feature work.

1. **Picture the target structure.** Ask: *how should the existing code be refactored so this requirement is easy to put in?* Look at where the requirement lands and what shape would take it naturally. These shapes are heuristics, not a checklist:

   | The requirement adds | A shape that takes it naturally |
   |---|---|
   | a case to an existing branch axis (type, channel, policy) | the existing cases as implementations of one abstraction (Replace Conditional with Polymorphism, Strategy) — the new case becomes a new class |
   | a new rule about an existing concept | the rule's data and behavior in one domain object (Move Method, Extract Class) — the rule becomes a method or guard on it |
   | a new step in a flow | the flow split into named steps (Compose Method) — the new step becomes one method |
   | a new input value | the scattered parameters gathered into one object (Introduce Parameter Object) |

2. **Keep the existing design.** The target stays inside the layers, packages, and patterns the code already uses. Tearing up the existing framework or design makes side effects unpredictable — that is separate work for Section 7, not a tidy item. The restructuring also stays within the requirement's reach: its callers sit inside this change's scope, and existing tests can show the behavior is unchanged.
3. **Don't lean only toward ease.** A target that makes the addition trivial but adds an abstraction, a layer, or a wide blast radius is not automatically better. Weigh how much easier the requirement becomes against the complexity and risk the restructuring adds. An abstraction needs this requirement to add a case to its axis and 2+ concrete cases counting that one — an interface with one implementation is an anti-pattern.
4. **Build 2–3 candidates**, normally including the current structure as is. For each, note the restructuring and its technique, its reach (callers and safety-net tests), and what the feature work then adds. They go to Step 2 — you do not pick one alone.
5. **Nothing to restructure is a result too.** When the requirement already fits the current structure without strain — say, one class added beside the existing implementations — skip the Step 2 question and write `해당 없음` with one sentence on how the current structure takes it. Inventing an item to fill the section is worse than none.

A smell the requirement never touches is not a candidate: Section 0 exists to make this change easy, not to clean the code.

### Step 2: Clarifying Questions

**Ask questions BEFORE writing the document.** If code analysis reveals any decision points or scope ambiguities, do NOT leave them as notes like "별도 확인 필요" inside the document. Instead, ask the user first, then write the document after receiving answers.

Situations that require asking:
- **Domain context that isn't derivable from code alone** — code shows *what* happens, not *why*. If you cannot confidently explain the business reason behind a concept (e.g., "왜 이 상태에서는 금액 변경이 불가능한가?"), ask.
- **Business invariants whose motivation is unclear** — don't infer the rule's intent from the guard clause alone. If the violation consequence or the constraint's origin isn't obvious, ask.
- Domain-specific terminology or concepts that appear in the codebase but whose exact meaning is ambiguous
- **The target structure from Step 1** — present the candidates side by side: what each restructures, its reach, what the feature work then adds, and the trade-off between ease and the complexity and risk it adds. Recommend one and say why, then let the user decide. When an abstraction is among them, ask whether its axis keeps growing — that answer weighs most in the trade-off. For example:

  > "[기능]을 넣는 방법으로 두 가지를 봤습니다.
  > A. 지금 구조 그대로 — `SettlementService.calculateFee()`에 분기를 하나 추가합니다. 변경은 작지만 채널 분기가 4개가 됩니다.
  > B. 기존 3개 채널을 `FeePolicy` 구현체로 정비한 뒤 신규 채널 구현체를 추가합니다. 정비는 `SettlementService`와 호출부 2곳에 닿고, `SettlementServiceTest`로 확인합니다.
  > 채널이 앞으로도 늘어난다면 B를 추천합니다. 채널이 더 늘어날 예정인가요, 어느 쪽으로 갈까요?"
- **Placement the code and project rules don't settle** — which package or existing class a new file joins, when the placement scan found no single home or the plan departs from it (e.g., "[기능]의 기존 엔드포인트는 `[패키지]`의 `[Controller]`에 있는데, 이번 API는 `[다른 위치]`에 둘 이유가 있어 보입니다. 기존 위치에 추가할까요, 분리할까요?").

Ask through natural conversational text in normal assistant messages.
Multiple-choice/lettered-option formats are too constrained for open-ended domain and
invariant questions. (A lettered A/B/C list written as plain text is still fine for narrow
scope decisions, if it helps clarity.)

Ask in **rounds of up to 4 questions at a time**, in Korean, and let the count follow what Step 1
left open rather than a number fixed in advance. Wait for answers before starting the next round. Cover: goal/problem, affected modules, API style, data
source, and success definition, along with any domain/invariant questions raised in Step 1.

**Stop when the open questions are closed, not at a count.** Go further when an answer is
contradictory or dangerously vague; stop early when the spec document or the code already
answers the rest. Padding to look thorough is worse than asking three good questions.

**Reading answers you got.** Before deciding you have enough, check for these — each one is a
follow-up, not an answer:
- Single-word replies to open-ended questions
- "알아서 해주세요" / "네가 판단해줘" — reframe rather than accept: *"설계가 어느 쪽으로 기울어야 하는지는 정하고 싶습니다. [구체적 항목]만 알려주시겠어요?"*
- Answers that change the subject instead of addressing the question

**Contradiction check (before writing).** Cross-read the full answer set for four conflicts:

| Conflict | Looks like |
|---|---|
| 범위 | "간단하게 가자" + 엔터프라이즈급 요구 |
| 리스크 | "보안은 신경 안 써도 돼" + 민감 정보 취급 |
| 기술 | 상호 배타적인 두 제약을 동시에 요구 |
| 일정 vs 범위 | 최소 일정 + 전체 기능 |

If one appears, quote **both** answers side by side, say why they conflict, and resolve it
before writing. Do not pick an interpretation yourself and do not write the conflict into the
document as a note.

**Continuing vs. stopping**: Once a round's answers resolve the open questions above,
proactively check in:

> "지금까지 답변해주신 내용으로 계획 문서를 작성해도 괜찮을까요? 더 확인하고 싶은 부분이 있으신가요?"

If the user asks to stop mid-round while real ambiguity remains, mention it once, then
respect their final decision — do not ask twice.

### Step 3: Write the Plan Document

**File Naming**: `task-{feature}.md` with a short kebab-case feature summary (e.g., `task-payment-refund.md`), unless the user named the file.

**File Location**: `docs/plan/`, unless the user specifies another path.

Read and use the template from `assets/plan-template.md`. **Omit a section only when Step 1 and Step 2 produced nothing for it** — no endpoint in the change means no Section 4, no defect in the referenced implementation means Section 3 is `해당 없음`, and API Design does not apply to batch or refactoring work. A section dropped because it was never investigated is the blind spot this rule exists to prevent. Section 7 carries risk notes — failure modes and scale — whenever Step 1 or Step 2 surfaced any.

#### Writing Style (all sections)

The plan is reread before every coding step, so a sentence that packs three facts costs the reader three times. Verbosity in these plans comes from sentence shape, not from the number of sections.

- **One fact per sentence.** Split facts chained with `~지만`, `~며`, `~고`, `그래서` into separate sentences.
- **No parenthetical asides.** An aside that matters becomes its own sentence; one that doesn't is dropped. Code identifiers, literal values, and `3-x` references in parentheses are fine.
- **Table cells: the decision in one sentence, plus at most one sentence of reason.** A procedure belongs in Section 5, and the cell points to it.
- **Invariants: at most two rule sentences**, plus the violation consequence in one sentence.
- **Keep the reasons, shorten them.** The violation consequence (Section 2), `왜 문제인가`, and the fix-or-split reason (Section 3) stay — each as one sentence.
- **State a fact once.** When another section already says it, reference the section instead of restating it.
- **Never shorten by dropping a fact.** Remove only what another section already states. A shorter plan that lost a path, a constraint, or a value is worse than a long one.

> Bad: `PartitionStrategy(999건) 단위로 나눠 조회해 조립 — MSSQL 파라미터 2,100개 제한 대비(목록 size 상한 없음). 빈 목록이면 쿼리 없이 빈 리스트`
> Good: `` `PartitionStrategy`의 999건 단위로 나눠 조회한다. 목록 `size`에 상한이 없어 MSSQL 파라미터 2,100개 제한에 걸릴 수 있다. `` — the empty-list case moves to the file table, which already covers it.

#### Domain Context & Invariants (Section 2)

**Rule: never guess.** If you don't know the business reason behind a concept or invariant, it means you should have asked in Step 2. If something is still unclear when you reach this section, **stop and ask the user before continuing** — do not fill the section with inferred or assumed content.

Write **domain context** as prose sentences, not bullet points. A developer reading this for the first time should understand the domain's key concepts and assumptions from these sentences alone. Only write what you know from Step 1 code analysis or Step 2 answers.

Write **business invariants** as complete declarative sentences: "If X, then Y must always hold" / "Z is never permitted when W." Include what breaks if the invariant is violated — this is what makes the rule stick in the reader's mind. If you can't state the violation consequence with confidence, ask the user.

> Bad: `No amount change after approval`
> Good: `The amount of an approved contract can never be changed under any circumstances. Allowing this causes settlement discrepancies and audit failures.`

Tag each invariant with a **출처**. Do not number invariants — nobody reads the plan by ID, and tdd-subagent assigns its own IDs when it imports them.

| 출처 | Means | Review weight |
|------|-------|---------------|
| `[문서]` | Stated in the spec/ticket as written | Lowest — already agreed |
| `[사용자확인]` | Answered by the user in Step 2 | Low |
| `[코드추론]` | Read off a guard clause or enum, motivation not confirmed | **Highest — flag these for the user explicitly** |

**Isolation invariants.** When the feature runs alongside an existing parallel implementation — its own tables, its own flow, the legacy one still live — write the separation as invariants in both directions: the new path must not touch the old store, *and* the old path must not pull in the new one. Structural separation (different tables) is an argument for why it holds, not evidence that it does; a shared query or a chained side effect breaks it just the same. These land as invariants rather than prose because tdd-subagent imports each invariant and tests it on both sides, so writing them here is what makes them verified rather than asserted.

Also extract invariants from code discovered in Step 1 — enum state transitions, validation annotations, and guard clauses are all domain rules in disguise. But they land as `[코드추론]`: code shows the constraint exists, not why it exists or what it protects. Never promote one to `[사용자확인]` without an actual answer.

#### 기존 코드의 함정 (Section 3)

Write one subsection per defect from Step 1's pitfall scan, in the template's order: `현재 코드` → `왜 문제인가` → table → `→ 신규는` → `기존 코드`. No summary table above the subsections — it repeats each entry and pushes the evidence away from the decision.

List each location under `현재 코드` on its own line. Several locations packed into one sentence is the hardest line in the plan to read.

A diagnosis alone is worse than nothing — it tells the agent something is wrong and leaves it to invent a replacement, which is how you get a third variant of the same bug. Every entry carries **`→ 신규는`** naming the concrete alternative. When it holds more than one instruction, number them.

Show the failure as data where you can: a small condition/current/expected table beats a paragraph, because it is the shape the test will take later.

Close each entry with **`기존 코드`**: whether the existing defect is fixed in this ticket or split out, and why in one sentence. Silence here reads as "fix it", and an agent widening scope into legacy code is exactly what Section 0's commit separation exists to prevent.

No referenced implementation, or no defects found → `해당 없음`. A padded pitfall section trains the reader to skim the real ones.

#### TDD Test DisplayNames (Section 8)

When listing test cases in the implementation order, name each test using a **domain rule sentence**, not a class or method name.

**Existing test check**: Before proposing a new test for each invariant, check whether an existing test (from the Explore results in Step 1) already verifies that behavior. Tag each entry accordingly:
- `[NEW]` — no existing test covers this; write a new one
- `[REGRESSION]` — an existing test already covers this; run it as-is to confirm the behavior is preserved, never add a duplicate

The template is structured for Spring Boot API feature planning. Non-obvious section requirements:
- **0. 코드 구조 정비**: Only when modifying existing code — and then always present, as `해당 없음` with its reason when nothing is restructured, so a reader can tell it was considered. One table from the target structure the user chose in Step 2: the target, the restructuring and its technique, its reach, and what the feature work adds. One line of 결정 근거 records why the user chose it. Commit order: `refactor` → `feat`.
- **6. Implementation Files**: File table, then fill in the template's **`코드 스니핏` subsection** — class declaration, `private final` fields, and **method bodies**. The body is the point: call order, the guard clause enforcing each invariant, exceptions, and the return shape. Skeleton, not finished code — skip logging, transaction config, and defensive null checks, but make it concrete enough to start coding without re-reading the requirements. For dependencies, prefer injecting existing services found in Step 1 over wiring a repository directly.
- **8. Implementation Order**: When modifying existing code, split into Tidy First → Behavior Change phases with separate commits, and tag every entry `[NEW]` or `[REGRESSION]`. An abstraction in Section 0 is extracted in the Tidy First phase from the cases that already exist (`refactor`), and the new case follows in the behavior-change phase.

### Step 3.5: Self-Review

After writing the document, run these seven checks and fix what you can inline — no need to re-review after fixing.

**1. Spec coverage** (when a spec document was provided): does every requirement and invariant have a matching implementation entry in Section 8? Add whatever is missing.

**2. Placeholder scan**: fix these patterns immediately.
- "TBD", "TODO", "추후 확인", "별도 확인 필요"
- "적절한 예외 처리 추가" / "유효성 검증 추가" with no concrete content
- A Section 8 entry that only says "구현한다" without naming the class and method it implements
- A Section 6 snippet whose method body is empty or a `// TODO` — a body with no logic is a placeholder

**3. DisplayName check**: are the test names in Section 8 domain rule sentences rather than method names?
- Bad: `testCancelWhenPaid`
- Good: `결제 완료된 주문은 취소할 수 없다`

**4. Consistency**: are the class and method names identical across all three places they appear — the Section 6 file table, the Section 6 `코드 스니핏`, and the Section 8 implementation entries? A name that exists in only one of them means a file, a signature, or a step is missing.

**5. Section 0 justification**: for every Section 0 entry — does its `본 작업에서 추가할 것` appear as a Section 8 behavior-change entry; would the requirement really be harder to put in without it; does its reach stay inside this change's scope; and did the user choose it in Step 2? Delete the ones that fail — `해당 없음` with its reason beats a padded table.

**6. Invariant coverage**: is every Section 2 invariant verified by at least one Section 8 test, and does every Section 8 test trace back to an invariant or an explicit requirement? A test with no upstream is either an unwritten invariant or scope creep — resolve which.

**7. Sentence check**: scan for sentences that chain facts, parenthetical asides, and table cells longer than a decision plus one reason, and fix them per Writing Style. Then confirm the fix dropped nothing — every path, constraint, and value is still stated somewhere.

**Report the result, don't just fix silently.** Show the outcome as part of Step 4 so the user sees what was checked:

```
자체 검증: 7개 항목 중 6개 통과
- FAIL 2번 (플레이스홀더): 섹션 5-2의 "예외 처리 추가" → 구체 문구로 교체함
- FAIL 6번 (불변성 커버리지): "정산 완료된 계약은 해지할 수 없다"를 검증하는 테스트가 섹션 8에 없음 — 확인 필요
```

A check you fixed is reported as fixed. **A check you could not fix without a decision blocks the handoff**: do not proceed to Step 5 until it is resolved, and say so in Step 4 rather than passing an incomplete plan to tdd-subagent.

### Step 4: Request Feedback (Mandatory)

After writing the document, ask the user in a normal assistant message:

> "계획 문서를 작성했습니다. 수정하거나 보완할 부분이 있으신가요?
> 특히 [단계 구성 / 누락된 항목 / 범위]에 대한 의견을 주시면 반영하겠습니다."

Do NOT proceed to implementation without explicit approval.

### Step 5: Hand Off to a TDD Skill (Terminal State)

Once approved, ask:

> "계획 문서가 완성되었습니다. tdd-subagent로 이어서 구현을 시작할까요, 아니면 여기서 마칠까요?"

If they continue and `tdd-subagent` is available, read its `SKILL.md` and pass the plan document path as input. If it is unavailable, or they choose to stop, say so and share the plan path.
