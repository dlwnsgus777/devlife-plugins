---
name: devlife-brainstorming
description: Explore ideas conversationally to define what/why/design decisions, then produce an approved design spec document.
  First step in the devlife workflow chain — hands off to plan-creator.
  Trigger on "브레인스토밍", "아이디어 정리", "기능 구상", "devlife-brainstorming",
  "뭘 만들지 정리", "아이디어 탐색", "기획 정리".
---

# Devlife Brainstorming

## Purpose

Turn a vague idea into an approved design spec. This skill covers **what** to build, **why**, and **how it's designed** (architecture, components, data flow, error handling, testing) — through a DDD lens: existing bounded contexts, aggregates, entities/value objects, and ubiquitous language are identified and respected before any new domain logic is proposed.
Implementation breakdown (which files, step-by-step tasks, commit units) is handled by plan-creator.

<HARD-GATE>
Do not write implementation code, scaffold files, or start implementation planning until the
brainstorming document has been written and the user has explicitly approved it.
</HARD-GATE>

**Position in the workflow chain:**
```
devlife-brainstorming  (what/why + design spec)
        ↓
   plan-creator        (구현 계획 — 파일/step/테스트/커밋 단위)
        ↓
     tdd-team          (TDD execution)
```

---

## Process

### Step 1: Scan Project Context

Before asking questions, briefly scan the current project state:
- Recent commits (`git log --oneline -5`)
- Key files in project root
- Titles of any existing spec/plan docs
- Domain-layer code relevant to this feature area — read the actual code, not just filenames, and identify:
  - which **bounded context** this feature falls into (or whether it needs a new one)
  - existing **aggregates/entities** and **value objects** nearby, and which aggregate would own new behavior
  - **invariants** already enforced in the domain layer for this area
  - **domain events** already published/consumed nearby
  - **ubiquitous language** terms already used in code/tickets for this area (so new naming reuses them instead of inventing synonyms)

This makes questions concrete and contextual, and grounds the domain question in Step 2. Do NOT report findings to the user — proceed directly to Step 1.5.

### Step 1.5: Scope Size Check

Before asking the first question, assess whether the idea contains multiple independent subsystems.

- **Single system or feature** → proceed to Step 2
- **Multiple independent subsystems** (e.g., "platform with chat, billing, file storage, analytics" — usually a sign of multiple bounded contexts)
  → flag immediately:
    > "Your idea contains several independent pieces. It's better to tackle them one at a time.
    >  Which would you like to start with — [A], [B], or [C]?"
  → brainstorm only the first sub-project; each gets its own design spec and plan-creator cycle

### Step 2: Explore the Idea (Batched Questions)

**Rules:**
- Ask **all checklist topics together in a single message**, laid out as a numbered/bulleted list the user can answer item by item in one reply
- Prefer open-ended questions; offer A/B/C choices only when options are clear
- Ask in Korean

**Topics to cover (present all at once):**
- [ ] **Core problem**: What problem does this solve?
- [ ] **Target users**: Who uses it? In what situation?
- [ ] **Success criteria**: How will you know it's done well?
- [ ] **Scope**: What must be in, and what is explicitly out?
- [ ] **Key design decisions**: Any trade-offs that determine the direction?
- [ ] **Constraints**: Technical, timeline, or business constraints?
- [ ] **Existing domain**: Present the Step 1 domain scan findings inline and ask for confirmation, e.g. "제가 파악한 기존 도메인은 {스캔 결과 요약}입니다 — 맞나요? 충돌하는 지점이나 예상되는 사이드이펙트가 있다면 알려주세요." If no relevant existing domain was found, state "기존 도메인 없음" and skip confirmation.

**Follow-up:**

After the batched reply, only ask **targeted follow-up questions** for items that are missing, ambiguous, or contradictory — do not re-ask the full list. Follow-ups can go one at a time since only a few items typically need clarification.

**When to stop asking:**

Once the checklist is mostly covered (batched answers + follow-ups), proactively check in:

> "I think I have enough to write the brainstorming document. Is there anything else you'd like to cover first?"

- Confirmed → proceed to Step 3
- More to discuss → continue questions
- User says "stop asking" / "that's enough" → mention any uncovered item once, then follow the user's call

### Step 3: Present Direction Options

Before presenting the design, propose 2-3 possible product/design directions with trade-offs.
Lead with the recommended direction and explain why it best fits the user's answers.

Ask:

> "이 방향이 맞나요? 이걸 바탕으로 설계를 발표하겠습니다."

- Approved → proceed to Step 4
- Changes requested → revise the direction options or ask one more clarifying question

### Step 4: Present Design Sections

Once the direction is approved, present the design **section by section** and get confirmation after each.

**Sections to cover (in order):**
1. **Architecture** — overall structure, layers, main modules
2. **Domain Model** (skip if the feature has no domain/business logic) — building on the Step 1 findings, decide aggregate ownership (existing vs. new), invariant placement (domain layer only), and whether new value objects/domain events are needed
3. **Components** — key classes/modules, responsibilities, interfaces
4. **Data Flow** — how data moves through the system, key transformations
5. **Error Handling** — failure modes, error boundaries, recovery strategies
6. **Testing** — test strategy, key scenarios, test boundaries

**Scale each section to its complexity:**
- Simple feature: a few sentences
- Complex system: up to 200-300 words

After each section, ask:

> "이 [섹션명] 방향이 맞나요?"

- Confirmed → proceed to the next section
- Changes requested → revise and re-present that section before continuing

Once all sections are confirmed → proceed to Step 5.

### Step 5: Write the Design Spec Document

**Filename**: `YYYY-MM-DD-{topic}.md` (e.g. `2026-07-02-payment-refund.md`)
**Location**: `docs/brainstorming/` (create the directory if it does not exist)

Organize the document to reflect how the conversation actually unfolded — let the structure follow the feature's own shape, not a fixed list. A one-screen config change might read as three short paragraphs; a multi-component feature might need a dozen named sections. Don't reach for the same section names every time — naming and grouping should come from what was actually discussed, not a checklist.

<!-- merged: check this section -->
The following must all be covered somewhere in the document (merge, split, or reorder as makes sense — this is a coverage requirement, not a section template):

- **Core Problem** — what this solves and why it needs to exist
- **Target Users / Context** — who uses it, when, in what situation
- **Success Criteria** — how to judge whether this was built well
- **Scope** — what's in, what's explicitly out
- **Key Design Decisions** — trade-offs and the chosen direction
- **Existing Domain** — what existing domain concepts this touches (bounded context, aggregates, invariants, domain events, ubiquitous language from Step 1), any conflicts and how they're resolved, and expected side effects on existing domain logic or other features (if genuinely none, state that explicitly with the reasoning)
- **Architecture** — overall structure, layers, main modules
- **Domain Model** — aggregate ownership, invariant placement, new value objects/domain events (skip if the feature has no domain/business logic)
- **Components** — key classes/modules, responsibilities, interfaces
- **Data Flow** — how data moves through the system, key transformations
- **Error Handling** — failure modes, error boundaries, recovery strategies
- **Testing Strategy** — test strategy, key scenarios, test boundaries
- **Constraints** — technical, timeline, or business constraints (only if applicable)

### Step 6: Self-Review

Before showing the file to the user, review it yourself and fix issues inline:
- Placeholder scan: no `TBD`, `TODO`, or empty sections
- Consistency: scope, success criteria, and design sections do not contradict each other
- Ambiguity: any decision with multiple interpretations is made explicit
- YAGNI: no feature is added unless it came from the conversation
- Domain coverage: the document states whether this conflicts with existing domain logic and what side effects to expect, grounded in the Step 1 scan and Step 2 confirmation — not speculation
- DDD consistency & coverage: without re-listing terms or forcing new headings, verify the Step 1 domain vocabulary is used consistently, aggregate/invariant boundaries aren't violated, behavior isn't scattered into services when it belongs on the owning entity (anemic domain model), and every topic raised in Step 2 and Step 4 actually appears somewhere in the doc. Add whatever's missing into whichever section fits.

### Step 7: User Review → Hand Off to plan-creator (Terminal State)

After writing the document, present the path and ask the user to review it. Resolve review and hand-off in a single round-trip — do not ask a separate "진행할까요?" question afterward:

> "설계 spec 문서를 `{file path}`에 작성했습니다.
>  확인해주시고, 수정할 부분이 있으면 알려주세요.
>  별다른 요청이 없으면 이어서 plan-creator로 구현 계획을 작성하겠습니다."

- **change request** → apply the changes, then re-present the updated document with the same message (repeat this step)
- **any other reply with no change requested** (confirmation, "다음", "계속" 등) → immediately invoke plan-creator with the design spec document path as input
- **explicit stop request** ("여기서 멈춰줘", "plan-creator는 나중에 할게" 등) → share the document path and exit without invoking plan-creator

**If plan-creator is not available:**
> "plan-creator를 찾을 수 없습니다. 문서 경로: `{file path}`"

---

## Principles

- **what/why + design, not how** — implementation breakdown belongs to plan-creator
- **Scale to complexity** — sections can be a few sentences or several hundred words
- **Batch, then narrow** — ask everything at once in Step 2; follow up only on gaps
- **Confirm domain understanding, don't assume it** — verified in Step 2, not guessed
- **Spec structure is free-form** — organized by how the conversation unfolded, not a fixed template; the required topics listed in Step 5 must still appear somewhere in the document, and their coverage is double-checked in Step 6
- **Never guess; YAGNI** — ask when unclear, don't add scope the user didn't mention
- **Domain-driven, when applicable** — respect existing bounded contexts, aggregates, and ubiquitous language (Step 1); skip entirely for features with no domain logic
