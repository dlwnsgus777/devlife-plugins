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

Scan the relevant module's existing code first — controllers, services, domain models, and similar features. This makes your questions targeted rather than generic.

**신규 vs 기존 코드 수정 판별**: 코드 탐색 후, 이 작업이 "신규 파일 추가"인지 "기존 코드 수정"인지 판단한다.
- **기존 코드 수정**이라면 — 어떤 클래스/메서드가 변경 대상인지 파악하고, 해당 코드에 새 요구사항을 추가하기 어렵게 만드는 구조적 문제(중첩 if, 긴 메서드, 하드코딩, 낮은 응집도 등)가 있는지 확인한다. 이 판단이 Section 0 작성 여부를 결정한다.

### Step 2: Clarifying Questions

**Ask questions BEFORE writing the document.** If code analysis reveals any decision points or scope ambiguities, do NOT leave them as notes like "별도 확인 필요" inside the document. Instead, ask the user via `AskUserQuestion` first, then write the document after receiving answers.

Situations that require asking:
- Scope decisions (e.g., "A has the same issue — fix it together or separately?")
- Multiple valid implementation approaches
- Ambiguous requirements or missing information
- **Domain context that isn't derivable from code alone** — code shows *what* happens, not *why*. If you cannot confidently explain the business reason behind a concept (e.g., "왜 이 상태에서는 금액 변경이 불가능한가?"), ask.
- **Business invariants whose motivation is unclear** — don't infer the rule's intent from the guard clause alone. If the violation consequence or the constraint's origin isn't obvious, ask.
- Domain-specific terminology or concepts that appear in the codebase but whose exact meaning is ambiguous

**Important**: If you are unsure about any domain context or invariant, ask in this step. Do **not** defer to Step 3 and fill in the blanks with guesses.

Use `AskUserQuestion` to ask 3–5 questions **in a single call** with **lettered options (A / B / C / D)**. All questions must be written in Korean. Cover: goal/problem, affected modules, API style, data source, and success definition.

Format:
```
Q1. 구현 방식을 선택해 주세요:
A) 신규 REST API 엔드포인트 추가
B) 기존 API 응답 필드 확장
C) 배치 작업 추가
D) 내부 서비스 로직 변경만
```

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

The template is structured for Spring Boot API feature planning:
- **0. Tidy First (코드 구조 정비)**: **기존 코드 수정 시에만 포함**. 정비 대상·기법(Extract Method, Guard Clause, Normalize Symmetry, Rename, Cohesion Ordering, Parameterize 등)·커밋 순서(`refactor` → `feat`)를 간결한 표 하나로 정리. 신규 파일만 추가하는 작업은 생략.
- **1. Feature Overview**: Include a screen/function composition table — one row per UI section or feature unit
- **2. Domain Context & Invariants**: Prose sentences for domain background; declarative sentences for business rules that must never be violated
- **3. API Design**: One subsection per endpoint with Request/Response JSON examples; explicitly cover edge cases (null, empty, etc.)
- **4. Business Logic**: Numbered subsections for each logic area; use a mapping table when status values or enums need display labels
- **5. Implementation Files**: List target classes per module + a package directory tree. After the table and tree, add a **"코드 스니핏"** subsection with skeleton code for each new or modified class — class/record declaration, field stubs, and key method signatures with brief inline comments. Base the snippets on the actual code patterns you found during Step 1. Snippets are scaffolding, not complete implementations, but they should be concrete enough that a developer can start coding immediately without re-reading the requirements.
- **6. Considerations & Questions**: Numbered list of items needing confirmation, each with an alternative option if applicable
- **7. Implementation Order (TDD)**: **기존 코드 수정 시** "1단계: 코드 정비 (Tidy First)"와 "2단계: 기능 구현 (Behavior Change)"로 구분. 정비 단계는 동작 변경 없이 구조만 개선하며, 별도 커밋 후 기능 단계로 진행. 각 테스트는 domain-rule DisplayNames 사용.
- **8. Acceptance Criteria**: Final verification checklist

For non-API work (batch jobs, refactoring, etc.), omit sections that don't apply (e.g., API Design) and fill in the rest.

### Step 4: Request Feedback (Mandatory)

After writing the document, use the `AskUserQuestion` tool to ask:

> "계획 문서를 작성했습니다. 수정하거나 보완할 부분이 있으신가요?
> 특히 [단계 구성 / 누락된 항목 / 범위]에 대한 의견을 주시면 반영하겠습니다."

Do NOT proceed to implementation without explicit approval.

