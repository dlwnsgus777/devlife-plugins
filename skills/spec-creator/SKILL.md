---
name: spec-creator
description: Writes a Spec (기술 명세 / 요구사항 문서) for large-scale features or initiatives,
  breaking them down into sub-tasks that can each be planned with plan-creator.
  Use when the user needs to plan a large feature with multiple sub-tasks, wants to define
  the overall scope and direction before diving into individual task plans, or wants a
  structured breakdown of work that spans multiple development sessions.
  Trigger on "spec 작성해줘", "스펙 작성해줘", "전체 계획 세워줘", "기능 전체 계획", "에픽 계획",
  "큰 기능 계획", "spec 만들어줘", "작업 목록 정리해줘", "PRD 작성해줘" (legacy phrasing),
  or any Korean sentence combining a large feature description with planning intent
  ("전체", "에픽", "큰 작업", "여러 단계") and a writing verb
  ("작성", "정리", "만들어", "세워줘").
---

# Spec Creator

## Purpose

Write a Spec for a large-scale feature or initiative.
The Spec sits above `plan-creator` in the hierarchy: it defines the overall background, goals, and scope,
and enumerates each sub-task.

<!-- Chain: devlife-brainstorming → spec-creator → plan-creator → tdd-team -->

## Process

### Document Input (Optional)

If a brainstorming document path is provided (from devlife-brainstorming or otherwise):

1. Read the document before doing anything else
2. Extract what is already defined: core problem, target users, scope, key design decisions, constraints
3. In Step 2, skip questions whose answers are already clear from the document — do not ask about topics already covered
4. Use the document's content as the foundation for the spec; only ask about gaps

If no document is provided, proceed to Step 1 as normal.

### Step 1: Explore the Codebase

Scan relevant modules before asking any questions.
- Identify affected domains, services, and controllers
- Understand existing patterns and architectural style
- Find the gap between current state and the target state

This makes your questions concrete and meaningful.

### Step 2: Gather Information

**Complete codebase exploration first.**

Ask questions through natural conversational text in normal assistant messages.
Multiple-choice formats are too constrained for domain context and business invariant
questions, which often need long-form, nuanced answers.

Ask in **rounds of up to 4 questions at a time**, written in Korean. Wait for the user's
answers before starting the next round.

Required topics (track these as a coverage checklist across rounds — order is flexible,
but note what's still uncovered):
- **Background & Goals**: Why is this work needed? What problem does it solve?
- **Domain Context**: What are the core concepts, assumptions, and constraints of the domain? (e.g., state machine structure, multi-tenancy requirements, external system dependencies). If code exploration left any concepts whose *business meaning* is unclear, ask here — code shows *what* happens, not *why*.
- **Business Invariants**: Are there rules that must never be broken throughout implementation? (e.g., "amount cannot change after payment is complete", "one active subscription per user"). If you found guard clauses or validation logic in the codebase but don't know the business motivation behind them, ask — don't infer intent from code structure alone.
- **Scope**: What is in scope and what is explicitly out of scope?
- **Sub-task Breakdown**: How can it be split? What are the dependencies?
- **Technical Direction**: Are there specific approaches or constraints?
- **Priority**: Which task should start first?
- **Success Criteria**: What does "done" look like for the entire initiative?

**Important**: If you are unsure about domain context or any invariant, ask in this step. Do **not** defer to Step 3 and fill in the blanks with guesses.

**Continuing vs. stopping**: Do not passively wait for the user to say "이제 됐어."
Once a round's answers bring the checklist close to complete, proactively check in:

> "지금까지 답변해주신 내용으로 Spec 문서를 작성해도 괜찮을까요? 더 다루고 싶은 내용이 있으신가요?"

- User confirms → proceed to Step 3.
- User wants to add more → start another round of up to 4 questions.
- User asks to stop at any point (e.g., "그만 물어봐", "이 정도면 됐어"):
  - No required topic left uncovered → stop immediately, proceed to Step 3.
  - Some topic still uncovered → mention it once ("OO 부분은 아직 확인 못했는데
    이대로 진행해도 될까요?") and follow the user's final call. Do not ask twice.

Do not write the document until you have received answers.

### Step 3: Write the Spec Document

**Naming convention**:
- If the user specifies a filename: use it
- Otherwise: `spec-{feature}.md` (e.g., `spec-payment-refund.md`, `spec-user-auth.md`)

**File location**: Project root (current working directory).
Do not create subdirectories unless a path is explicitly specified.

Read `assets/spec-template.md` and fill in all sections.

#### Domain Context & Invariants

**Rule: never guess.** If you don't know the business reason behind a concept or invariant, it means you should have asked in Step 2. If something is still unclear when you reach this section, **stop and ask the user before continuing** — do not fill the section with inferred or assumed content.

**Domain context** must be written as **prose sentences**, not bullet points.
A reader new to this domain should be able to understand the feature's background from these sentences alone. Only write what you know from Step 1 code analysis or Step 2 answers.

**Business invariants** must be written as **complete declarative sentences**:
"If X, then Y must always hold" / "Z is never permitted when W".
Where possible, hint at what goes wrong if the invariant is violated. If you can't state the violation consequence with confidence, ask the user.

> Bad: `No amount change after payment`
> Good: `The amount of an order that has transitioned to payment-complete status can never be changed under any circumstances. Allowing this leads to settlement discrepancies and accounting audit failures.`

Also capture domain rules you discovered during codebase exploration (enum values, validation logic, comments) as invariants — but treat these as starting points for questions, not finished answers. Code shows the constraint exists, not why it exists or what it protects.

#### Sub-task Decomposition

Each sub-task must satisfy:
- **Independence**: implementable without blocking other tasks where possible
- **Clarity**: specific enough for `plan-creator` to write a detailed plan immediately
- **Right-sized**: completable in one development session (half to full day)
- **Verifiable**: clear completion criteria

#### Complexity Guide

| Size | Criteria |
|------|----------|
| S (Small) | Single file change, under 3 hours |
| M (Medium) | 2-5 files, half to full day |
| L (Large) | Multiple modules, more than one day |

Break down any L-sized task into smaller units.

### Step 3.5: Spec Review (Automated)

After writing the document, review it before asking the user.

Use a sub-agent for the independent review:
1. Spawn a sub-agent via `Agent({ subagent_type: "general-purpose", ... })` with the reviewer instructions below.
2. Pass only the spec path and the reviewer instructions. Do not pass your expected verdict.
3. If the Agent tool is unavailable, say `not available`, then perform the same review locally.

Reviewer prompt:

```
Read {SKILL_DIR}/references/spec-reviewer.md.
Follow it exactly.

Spec to review: {spec_file_path}
```

- **Approved** → proceed to Step 4
- **Issues Found** → fix inline, then re-run the reviewer once. If it passes, proceed to Step 4.

### Step 4: Request Feedback (Required)

After writing and reviewing the document, ask the user in a normal assistant message:

> "Spec 문서를 작성했습니다. 수정하거나 보완할 부분이 있으신가요?
> 특히 [하위 작업 분해 방식 / 범위 정의 / 우선순위]에 대한 의견을 주시면 반영하겠습니다."

Do not proceed to implementation without explicit approval.

### Step 5: Hand Off to plan-creator (Terminal State)

Once feedback is incorporated and approved:

> "Spec이 완성되었습니다. 이제 plan-creator를 사용해 첫 번째 task의 구현 계획을 작성하겠습니다."

**REQUIRED**: If `plan-creator` is available, read its `SKILL.md` and continue with the spec document path as input. If it is not available, say `not available` and share the spec path plus the recommended starting task.

---

**Standalone use**: If the user does not want to continue to plan-creator, ask:

> "plan-creator로 이어서 구현 계획을 작성할까요, 아니면 여기서 마칠까요?"

If they choose to stop, share the spec document path and the recommended starting task, then exit.
