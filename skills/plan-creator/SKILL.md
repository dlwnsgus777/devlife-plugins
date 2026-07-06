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

<!-- Chain: devlife-brainstorming → plan-creator → tdd-team -->

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
2. Ask for file paths and signatures only, no full implementations.
3. If the Explore agent is unavailable, say `not available`, then perform targeted local discovery with `rg`, `rg --files`, and focused file reads.

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

When listing test cases in the implementation order, name each test using a **domain rule sentence**, not a class or method name. Invariants from Section 2 are natural candidates for DisplayNames.

**Existing test check**: Before proposing a new test for each invariant, check whether an existing test (from the Explore results in Step 1) already verifies that behavior. Tag each entry accordingly:
- `[NEW]` — no existing test covers this; write a new one
- `[REGRESSION]` — an existing test already covers this; run it as-is to confirm the behavior is preserved, do not add a duplicate test

Never add a new test when an existing one already verifies the same business rule.

The template is structured for Spring Boot API feature planning. Non-obvious section requirements:
- **0. Tidy First**: Only when modifying existing code. One table: target, technique (Extract Method, Guard Clause, etc.), commit order (`refactor` → `feat`).
- **5. Implementation Files**: File table + package tree, then add a **"코드 스니핏" subsection** — class declaration, field stubs, key method signatures. For `private final` dependencies, prefer injecting existing services found in Step 1.
- **7. Implementation Order**: When modifying existing code, split into Tidy First → Behavior Change phases with separate commits. Tag every entry `[NEW]` or `[REGRESSION]` — `[REGRESSION]` means run the existing test as-is; never add a duplicate.

For non-API work (batch jobs, refactoring, etc.), omit sections that don't apply (e.g., API Design) and fill in the rest.

### Step 3.5: Self-Review

After writing the document, review it yourself before showing it to the user. Fix issues inline — no need to re-review after fixing.

**1. Spec coverage** (spec 문서가 제공된 경우): 각 요구사항/불변성에 대응하는 구현 항목이 섹션 7에 있는가? 누락된 항목은 추가한다.

**2. Placeholder scan**: 다음 패턴이 있으면 즉시 수정한다.
- "TBD", "TODO", "추후 확인", "별도 확인 필요"
- "적절한 예외 처리 추가" / "유효성 검증 추가" (구체적 내용 없이)
- 코드 스니핏 없이 "구현한다"만 적힌 단계

**3. DisplayName check**: 섹션 7의 테스트 이름이 메서드명이 아닌 도메인 규칙 문장인가?
- Bad: `testCancelWhenPaid`
- Good: `결제 완료된 주문은 취소할 수 없다`

**4. Consistency**: 섹션 5의 클래스명/메서드명이 섹션 7의 코드 스니핏과 일치하는가?

### Step 4: Request Feedback (Mandatory)

After writing the document, ask the user in a normal assistant message:

> "계획 문서를 작성했습니다. 수정하거나 보완할 부분이 있으신가요?
> 특히 [단계 구성 / 누락된 항목 / 범위]에 대한 의견을 주시면 반영하겠습니다."

Do NOT proceed to implementation without explicit approval.

### Step 5: Hand Off to tdd-team (Terminal State)

Once feedback is incorporated and approved:

> "계획 문서가 완성되었습니다. 이제 tdd-team을 사용해 구현을 시작하겠습니다."

**REQUIRED**: If `tdd-team` is available, read its `SKILL.md` and continue with the plan document path as input. If it is not available, say `not available` and share the plan path.

---

**Standalone use**: If the user does not want to continue to tdd-team, ask:

> "tdd-team으로 이어서 구현을 시작할까요, 아니면 여기서 마칠까요?"

If they choose to stop, share the plan document path and exit.
