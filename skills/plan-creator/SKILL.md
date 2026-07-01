---
name: plan-creator
description: Writes a structured Markdown plan document for any task, feature, or project.
  Use when the user requests a "계획 문서", "구현 계획", "실행 계획", "계획 MD로 정리",
  "계획서 작성", or "plan document".
  Trigger on "계획을 작성해줘", "계획 작성해줘",
  "계획을 md 파일에 작성해줘", "계획을 md에 작성해줘",
  or any Korean sentence containing "계획" combined with a writing intent verb
  ("작성", "써줘", "정리", "만들어줘") — even if no specific file is mentioned.
---

# Plan Creator

## Process

### Step 1: Context Gathering

Delegate wide code discovery to an **Explore subagent** to protect the main context window from bulk search output.

**Spawn an Explore subagent with the following prompt** (fill in `[feature domain]` based on the user's request):

> "Scan the [feature domain] in this project and report the following — file paths and signatures only, no full implementations:
> 1. Controllers handling [feature] — file paths, endpoint annotations, method signatures
> 2. Services in the same domain — class names, public method signatures
> 3. Domain models/entities involved — class names, key fields, enum values
> 4. Any 'find-by-id + throw' patterns already encapsulated in ReadService classes
> 5. Related exception classes and where they're thrown
> 6. Validation annotations or guard clauses that hint at business constraints
> 7. Existing test classes in the same domain — class names and `@DisplayName` values or method names that already verify related behavior"

**After the Explore subagent returns**, directly Read only the 2–3 most relevant files to identify business invariants (guard clauses, state transitions, validation annotations).

**Reusable code scan**: From the Explore results, identify existing services, utilities, and exception classes that already handle overlapping concerns. In particular, if "find-by-id + throw" patterns are encapsulated in a ReadService, inject that service rather than wiring a repository directly — reflect this in the code snippets.

**New file vs. existing code modification**: After exploring, determine whether this task adds new files or modifies existing code.
- **If modifying existing code** — identify which classes/methods are the change targets and check whether the current structure makes adding the new requirement difficult (nested ifs, long methods, hardcoding, low cohesion, etc.). This judgment decides whether Section 0 is included.

### Step 2: Clarifying Questions

**Ask questions BEFORE writing the document.** If code analysis reveals any decision points or scope ambiguities, do NOT leave them as notes like "별도 확인 필요" inside the document. Instead, ask the user first, then write the document after receiving answers.

Situations that require asking:
- Scope decisions (e.g., "A has the same issue — fix it together or separately?")
- Multiple valid implementation approaches
- Ambiguous requirements or missing information
- **Domain context that isn't derivable from code alone** — code shows *what* happens, not *why*. If you cannot confidently explain the business reason behind a concept (e.g., "왜 이 상태에서는 금액 변경이 불가능한가?"), ask.
- **Business invariants whose motivation is unclear** — don't infer the rule's intent from the guard clause alone. If the violation consequence or the constraint's origin isn't obvious, ask.
- Domain-specific terminology or concepts that appear in the codebase but whose exact meaning is ambiguous

**Important**: If you are unsure about any domain context or invariant, ask in this step. Do **not** defer to Step 3 and fill in the blanks with guesses.

Ask through natural conversational text — do **not** use the `AskUserQuestion` tool for
this step. Its multiple-choice/lettered-option format is too constrained for open-ended
domain and invariant questions. (A lettered A/B/C list written as plain text is still fine
for narrow scope decisions, if it helps clarity.)

Ask in **rounds of up to 4 questions at a time**, in Korean. Wait for answers before
starting the next round. Cover: goal/problem, affected modules, API style, data source,
and success definition, along with any domain/invariant questions raised in Step 1.

**Continuing vs. stopping**: Once a round's answers resolve the open questions above,
proactively check in:

> "지금까지 답변해주신 내용으로 계획 문서를 작성해도 괜찮을까요? 더 확인하고 싶은 부분이 있으신가요?"

- Confirmed → proceed to Step 3.
- More to discuss → another round of up to 4 questions.
- User asks to stop mid-round while real ambiguity remains → mention it once, then
  respect the user's final decision. Do not ask twice.

Wait for answers before writing the plan.

### Step 3: Write the Plan Document

**File Naming**: Determine the filename as follows:
- If the user explicitly specified a filename (e.g., "ffs-contract-cancel.md에 작성해줘"), use that exact name.
- Otherwise, default to `task-{feature}.md` where `{feature}` is a short kebab-case summary of the feature (e.g., `task-consultant-change-cancel.md`, `task-payment-refund.md`).

**File Location**: Always save the plan document to the **project root** (the current working directory). Do NOT create subdirectories (e.g., `.omc/plans/`, `docs/`, etc.) unless the user explicitly specifies a different path.

Read and use the template from `assets/plan-template.md` — fill every section, omit only if truly not applicable.

#### Domain Context & Invariants (Section 2)

**Rule: never guess.** If you don't know the business reason behind a concept or invariant, it means you should have asked in Step 2. If something is still unclear when you reach this section, **stop and ask the user before continuing** — do not fill the section with inferred or assumed content.

Write **domain context** as prose sentences, not bullet points. A developer reading this for the first time should understand the domain's key concepts and assumptions from these sentences alone. Only write what you know from Step 1 code analysis or Step 2 answers.

Write **business invariants** as complete declarative sentences: "If X, then Y must always hold" / "Z is never permitted when W." Include what breaks if the invariant is violated — this is what makes the rule stick in the reader's mind. If you can't state the violation consequence with confidence, ask the user.

> Bad: `No amount change after approval`
> Good: `The amount of an approved contract can never be changed under any circumstances. Allowing this causes settlement discrepancies and audit failures.`

Also extract invariants from code discovered in Step 1 — enum state transitions, validation annotations, and guard clauses are all domain rules in disguise. But treat these as starting points for questions, not finished answers — code shows the constraint exists, not why it exists or what exactly it protects.

#### TDD Test DisplayNames (Section 7)

When listing test cases in the implementation order, name each test using a **domain rule sentence**, not a class or method name. The test list should read like a business specification.

> Bad: `OrderCancelServiceTest — testCancel_WhenStatusIsPaid_ThrowsException`
> Good: `OrderCancelServiceTest — "결제 완료된 주문은 취소할 수 없다"`

The invariants you defined in Section 2 are the natural source for DisplayNames — each invariant is a candidate test name.

**Existing test check**: Before proposing a new test for each invariant, check whether an existing test (from the Explore results in Step 1) already verifies that behavior. Tag each entry accordingly:
- `[NEW]` — no existing test covers this; write a new one
- `[REGRESSION]` — an existing test already covers this; run it as-is to confirm the behavior is preserved, do not add a duplicate test

Never add a new test when an existing one already verifies the same business rule.

The template is structured for Spring Boot API feature planning:
- **0. Tidy First (코드 구조 정비)**: **기존 코드 수정 시에만 포함**. 정비 대상·기법(Extract Method, Guard Clause, Normalize Symmetry, Rename, Cohesion Ordering, Parameterize 등)·커밋 순서(`refactor` → `feat`)를 간결한 표 하나로 정리. 신규 파일만 추가하는 작업은 생략.
- **1. Feature Overview**: Include a screen/function composition table — one row per UI section or feature unit
- **2. Domain Context & Invariants**: Prose sentences for domain background; declarative sentences for business rules that must never be violated
- **3. API Design**: One subsection per endpoint with Request/Response JSON examples; explicitly cover edge cases (null, empty, etc.)
- **4. Business Logic**: Numbered subsections for each logic area; use a mapping table when status values or enums need display labels
- **5. Implementation Files**: List target classes per module + a package directory tree. After the table and tree, add a **"코드 스니핏"** subsection with skeleton code for each new or modified class — class/record declaration, field stubs, and key method signatures with brief inline comments. Base the snippets on the actual code patterns you found during Step 1. Snippets are scaffolding, not complete implementations, but they should be concrete enough that a developer can start coding immediately without re-reading the requirements. **For `private final` dependency fields, prefer injecting existing services found in Step 1 over introducing new classes.**
- **6. Considerations & Questions**: Numbered list of items needing confirmation, each with an alternative option if applicable
- **7. Implementation Order (TDD)**: **When modifying existing code**, split into "Phase 1: Tidy First" and "Phase 2: Behavior Change". The tidy phase improves structure only with no behavior changes; commit separately before moving to the behavior phase. Each test uses domain-rule DisplayNames. Tag each entry with `[NEW]` or `[REGRESSION]` — `[REGRESSION]` means run the existing test as-is to confirm the behavior is preserved; never add a duplicate test.
- **8. Acceptance Criteria**: Final verification checklist

For non-API work (batch jobs, refactoring, etc.), omit sections that don't apply (e.g., API Design) and fill in the rest.

### Step 4: Request Feedback (Mandatory)

After writing the document, use the `AskUserQuestion` tool to ask:

> "계획 문서를 작성했습니다. 수정하거나 보완할 부분이 있으신가요?
> 특히 [단계 구성 / 누락된 항목 / 범위]에 대한 의견을 주시면 반영하겠습니다."

Do NOT proceed to implementation without explicit approval.

