---
name: plan-creator
description: Writes a structured Markdown plan document for any task, feature, or project.
  Use when the user requests a "계획 문서", "구현 계획", "실행 계획", "계획서 작성", or "plan document",
  or writes any Korean sentence combining "계획" with a writing intent verb
  ("작성", "써줘", "정리", "만들어줘") — even if no specific file is mentioned.
---

# Plan Creator

<!-- Chain: devlife-brainstorming → spec-creator → plan-creator → tdd-team -->

## Process

### Document Input (Optional)

If a spec document path is provided (from devlife-brainstorming or otherwise):

1. Read the document before doing anything else
2. Extract what is already defined: domain context, business invariants, subtask breakdown, scope
3. In Step 2, skip questions whose answers are already clear from the document
4. Use Section 2 (Domain Context & Invariants) of the spec as the foundation — do not re-derive invariants already stated there
5. Identify which subtask this plan covers from the spec's task list

If no document is provided, proceed to Step 1 as normal.

### Step 1: Context Gathering

Use the Explore sub-agent for wide code discovery:
1. Spawn a sub-agent via `Agent({ subagent_type: "Explore", ... })` with the prompt below.
2. If the Explore agent is unavailable, say `not available`, then perform targeted local discovery with `rg`, `rg --files`, and focused file reads.

Explorer prompt (fill in `[feature domain]` based on the user's request):

> "Scan the [feature domain] in this project and report the following — file paths and signatures only, no full implementations:
> 1. Controllers handling [feature] — file paths, endpoint annotations, method signatures
> 2. Services in the same domain — class names, public method signatures
> 3. Domain models/entities involved — class names, key fields, enum values
> 4. Any 'find-by-id + throw' patterns already encapsulated in ReadService classes
> 5. Related exception classes and where they're thrown
> 6. Validation annotations or guard clauses that hint at business constraints
> 7. Existing test classes in the same domain — class names and `@DisplayName` values or method names that already verify related behavior"

After discovery, directly read only the 2–3 most relevant files to identify business invariants (guard clauses, state transitions, validation annotations).

**Reusable code scan**: From the Explore results, identify existing services, utilities, and exception classes that already handle overlapping concerns. In particular, if "find-by-id + throw" patterns are encapsulated in a ReadService, inject that service rather than wiring a repository directly — reflect this in the code snippets.

**Existing code modification**: If this task modifies existing code rather than only adding files, identify the change targets and judge whether their current structure makes the new requirement hard to add — that judgment decides whether Section 0 is included.

**Variation point scan**: Find the axis this domain keeps changing along — branching on an enum/type/channel, policy values hardcoded in a service, near-duplicate methods differing in one step. That axis is where the next requirement lands, so it is the abstraction candidate for `0-2`.

**Two-case rule — never force it.** Propose an abstraction only when the axis has 2+ concrete cases (already, or counting the one this requirement adds) **and** the domain says it keeps growing (Section 2 context or a Step 2 answer). A single case, or a structural smell with no domain reason, means no proposal — an interface with one implementation is an anti-pattern. Nothing qualifies → `해당 없음`, never an invented axis.

### Step 2: Clarifying Questions

**Ask questions BEFORE writing the document.** If code analysis reveals any decision points or scope ambiguities, do NOT leave them as notes like "별도 확인 필요" inside the document. Instead, ask the user first, then write the document after receiving answers.

Situations that require asking:
- **Domain context that isn't derivable from code alone** — code shows *what* happens, not *why*. If you cannot confidently explain the business reason behind a concept (e.g., "왜 이 상태에서는 금액 변경이 불가능한가?"), ask.
- **Business invariants whose motivation is unclear** — don't infer the rule's intent from the guard clause alone. If the violation consequence or the constraint's origin isn't obvious, ask.
- Domain-specific terminology or concepts that appear in the codebase but whose exact meaning is ambiguous
- **Whether a variation axis from Step 1 is real** — code shows today's branches, not whether more are coming (e.g., "정산 정책이 앞으로 채널별로 더 늘어날 예정인가요?"). A "no" drops the proposal.

Ask through natural conversational text in normal assistant messages.
Multiple-choice/lettered-option formats are too constrained for open-ended domain and
invariant questions. (A lettered A/B/C list written as plain text is still fine for narrow
scope decisions, if it helps clarity.)

Ask in **rounds of up to 4 questions at a time**, in Korean. Wait for answers before
starting the next round. Cover: goal/problem, affected modules, API style, data source,
and success definition, along with any domain/invariant questions raised in Step 1.

**Continuing vs. stopping**: Once a round's answers resolve the open questions above,
proactively check in:

> "지금까지 답변해주신 내용으로 계획 문서를 작성해도 괜찮을까요? 더 확인하고 싶은 부분이 있으신가요?"

If the user asks to stop mid-round while real ambiguity remains, mention it once, then
respect their final decision — do not ask twice.

### Step 3: Write the Plan Document

**File Naming**: `task-{feature}.md` with a short kebab-case feature summary (e.g., `task-payment-refund.md`), unless the user named the file.

**File Location**: `docs/plan/`, unless the user specifies another path.

Read and use the template from `assets/plan-template.md` — fill every section, omitting only those that truly don't apply (e.g., API Design for batch or refactoring work).

#### Domain Context & Invariants (Section 2)

**Rule: never guess.** If you don't know the business reason behind a concept or invariant, it means you should have asked in Step 2. If something is still unclear when you reach this section, **stop and ask the user before continuing** — do not fill the section with inferred or assumed content.

Write **domain context** as prose sentences, not bullet points. A developer reading this for the first time should understand the domain's key concepts and assumptions from these sentences alone. Only write what you know from Step 1 code analysis or Step 2 answers.

Write **business invariants** as complete declarative sentences: "If X, then Y must always hold" / "Z is never permitted when W." Include what breaks if the invariant is violated — this is what makes the rule stick in the reader's mind. If you can't state the violation consequence with confidence, ask the user.

> Bad: `No amount change after approval`
> Good: `The amount of an approved contract can never be changed under any circumstances. Allowing this causes settlement discrepancies and audit failures.`

Also extract invariants from code discovered in Step 1 — enum state transitions, validation annotations, and guard clauses are all domain rules in disguise. But treat these as starting points for questions, not finished answers — code shows the constraint exists, not why it exists or what exactly it protects.

#### TDD Test DisplayNames (Section 7)

When listing test cases in the implementation order, name each test using a **domain rule sentence**, not a class or method name.

**Existing test check**: Before proposing a new test for each invariant, check whether an existing test (from the Explore results in Step 1) already verifies that behavior. Tag each entry accordingly:
- `[NEW]` — no existing test covers this; write a new one
- `[REGRESSION]` — an existing test already covers this; run it as-is to confirm the behavior is preserved, never add a duplicate

The template is structured for Spring Boot API feature planning. Non-obvious section requirements:
- **0. 코드 구조 정비**: Only when modifying existing code. `0-1. Tidy First` — behavior-preserving cleanup (Extract Method, Guard Clause, …). `0-2. 추상화 제안` — entries passing the two-case rule; it is a design decision, so leave 적용 여부 as pending until Step 4 approves it. Commit order: `refactor` → `feat`.
- **5. Implementation Files**: File table, then add a **"코드 스니핏" subsection** — class declaration, field stubs, key method signatures. For `private final` dependencies, prefer injecting existing services found in Step 1.
- **7. Implementation Order**: When modifying existing code, split into Tidy First → Behavior Change phases with separate commits, and tag every entry `[NEW]` or `[REGRESSION]`. An approved `0-2` abstraction is extracted in the Tidy First phase from the cases that already exist (`refactor`), and the new case follows in the behavior-change phase.

### Step 3.5: Self-Review

After writing the document, review it yourself before showing it to the user. Fix issues inline — no need to re-review after fixing.

**1. Spec coverage** (when a spec document was provided): does every requirement and invariant have a matching implementation entry in Section 7? Add whatever is missing.

**2. Placeholder scan**: fix these patterns immediately.
- "TBD", "TODO", "추후 확인", "별도 확인 필요"
- "적절한 예외 처리 추가" / "유효성 검증 추가" with no concrete content
- A step that only says "구현한다" with no code snippet

**3. DisplayName check**: are the test names in Section 7 domain rule sentences rather than method names?
- Bad: `testCancelWhenPaid`
- Good: `결제 완료된 주문은 취소할 수 없다`

**4. Consistency**: do the class and method names in Section 5 match the code snippets in Section 7?

**5. Abstraction justification**: does every `0-2` entry have 2+ cases and a domain reason? Delete the ones that don't — `해당 없음` beats a padded table.

### Step 4: Request Feedback (Mandatory)

After writing the document, ask the user in a normal assistant message:

> "계획 문서를 작성했습니다. 수정하거나 보완할 부분이 있으신가요?
> 특히 [단계 구성 / 누락된 항목 / 범위]에 대한 의견을 주시면 반영하겠습니다."

If `0-2` has an entry, ask about it in the same message and delete it from the document if rejected — never leave it as "추후 검토":

> "섹션 0-2에 [변화 지점] 추상화([제안])를 제안했습니다. 지금 도입할지, 케이스가 더 쌓일 때까지 미룰지 판단해주세요."

Do NOT proceed to implementation without explicit approval.

### Step 5: Hand Off to tdd-team (Terminal State)

Once approved:

> "계획 문서가 완성되었습니다. 이제 tdd-team을 사용해 구현을 시작하겠습니다."

**REQUIRED**: If `tdd-team` is available, read its `SKILL.md` and continue with the plan document path as input. If it is not available, say `not available` and share the plan path.

---

**Standalone use**: If the user does not want to continue to tdd-team, ask:

> "tdd-team으로 이어서 구현을 시작할까요, 아니면 여기서 마칠까요?"

If they choose to stop, share the plan document path and exit.
