---
name: devlife-brainstorming
description: Explore ideas conversationally to define what/why/design decisions, then produce an approved design spec document.
  First step in the devlife workflow chain — hands off to plan-creator.
  Trigger on "브레인스토밍", "아이디어 정리", "기능 구상", "devlife-brainstorming",
  "뭘 만들지 정리", "아이디어 탐색", "기획 정리".
---

# Devlife Brainstorming

## Purpose

Turn a vague idea into an approved design spec — **what** to build, **why**, and **how it's designed** (architecture, components, data flow, error handling, testing), through a DDD lens that respects existing bounded contexts, aggregates, and ubiquitous language. Implementation breakdown (files, steps, commit units) is plan-creator's job.

<HARD-GATE>
Two things require an **explicit instruction** from the user — never do them on your own:
1. **Writing the design spec document.** A confirmation ("좋아", "맞아", "다음", "계속") means the user agrees with the current step. It is NOT permission to write the file. Wait until the user tells you to write it.
2. **Handing off to plan-creator.** Do not invoke plan-creator until the user explicitly tells you to proceed.

Never write implementation code or scaffold files at any point.
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
  - **ubiquitous language** terms already used in code/tickets (so new naming reuses them instead of inventing synonyms)

This grounds the questions and the domain confirmation in Step 2. Do NOT report findings to the user — proceed directly to Step 1.5.

### Step 1.5: Scope Size Check

Assess whether the idea contains multiple independent subsystems.

- **Single system or feature** → proceed to Step 2
- **Multiple independent subsystems** (e.g., "platform with chat, billing, file storage, analytics" — usually multiple bounded contexts) → flag immediately:
    > "아이디어에 독립적인 조각이 여러 개 있습니다. 하나씩 다루는 게 좋습니다. 어느 것부터 시작할까요 — [A], [B], [C]?"
  → brainstorm only the first sub-project; each gets its own spec and plan-creator cycle

### Step 2: Explore the Idea (Batched Questions)

**Rules:**
- Ask **all checklist topics together in a single message**, as a numbered/bulleted list the user can answer item by item
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

**Follow-up:** After the batched reply, ask **targeted follow-ups** only for items that are missing, ambiguous, or contradictory — do not re-ask the full list.

**Surface concerns, then summarize and confirm:** Throughout, keep raising anything that worries you — ambiguity, risk, contradiction, a hidden side effect — and ask about it before moving on. When you have **no remaining concerns**, summarize what you've gathered and confirm:

> "지금까지 정리한 내용은 {요약}입니다. 이대로 진행해도 괜찮을까요? 더 다룰 부분이 있으면 알려주세요."

- Confirmed → proceed to Step 3
- More to discuss → keep asking

### Step 3: Present Direction Options

Propose 2-3 possible product/design directions with trade-offs. Lead with the recommended direction and explain why it best fits the user's answers.

Ask:
> "이 방향이 맞나요? 이걸 바탕으로 설계를 발표하겠습니다."

- Approved → proceed to Step 4
- Changes requested → revise the options or ask one more clarifying question

### Step 4: Present Design Sections

Present the design **section by section**, getting confirmation after each. Scale each section to its complexity — a few sentences for a simple feature, up to 200-300 words for a complex system.

**Sections (in order):**
1. **Architecture** — overall structure, layers, main modules
2. **Domain Model** (skip if no domain/business logic) — aggregate ownership (existing vs. new), invariant placement (domain layer only), new value objects/domain events
3. **Components** — key classes/modules, responsibilities, interfaces
4. **Data Flow** — how data moves through the system, key transformations
5. **Error Handling** — failure modes, error boundaries, recovery strategies
6. **Testing** — test strategy, key scenarios, test boundaries

After each section, ask:
> "이 [섹션명] 방향이 맞나요?"

- Confirmed → next section
- Changes requested → revise and re-present that section first

Once all sections are confirmed, summarize the full design and **ask for an explicit instruction to write the document** — do not write it yet:

> "설계가 모두 정리됐습니다. {요약}. 이대로 spec 문서를 작성할까요?"

### Step 5: Write the Design Spec Document (only when explicitly instructed)

Only after the user explicitly tells you to write it, create the file.

**Filename**: `YYYY-MM-DD-{topic}.md` (e.g. `2026-07-02-payment-refund.md`)
**Location**: `docs/brainstorming/` (create the directory if it does not exist)

Organize the document to reflect how the conversation actually unfolded — structure follows the feature's shape, not a fixed list. Don't reach for the same section names every time.

The following must all be covered somewhere in the document (merge, split, or reorder as makes sense — this is a coverage requirement, not a section template):

- **Core Problem** — what this solves and why it needs to exist
- **Target Users / Context** — who uses it, when, in what situation
- **Success Criteria** — how to judge whether this was built well
- **Scope** — what's in, what's explicitly out
- **Key Design Decisions** — trade-offs and the chosen direction
- **Existing Domain** — existing domain concepts this touches (bounded context, aggregates, invariants, domain events, ubiquitous language from Step 1), conflicts and how they're resolved, and expected side effects on existing domain logic or other features (if genuinely none, state that explicitly with reasoning)
- **Architecture** — overall structure, layers, main modules
- **Domain Model** — aggregate ownership, invariant placement, new value objects/domain events (skip if no domain/business logic)
- **Components** — key classes/modules, responsibilities, interfaces
- **Data Flow** — how data moves through the system, key transformations
- **Error Handling** — failure modes, error boundaries, recovery strategies
- **Testing Strategy** — test strategy, key scenarios, test boundaries
- **Constraints** — technical, timeline, or business constraints (only if applicable)

### Step 6: Self-Review

Before showing the file, review it yourself and fix issues inline:
- **Placeholders**: no `TBD`, `TODO`, or empty sections
- **Consistency**: scope, success criteria, and design sections don't contradict each other
- **Ambiguity**: any decision with multiple interpretations is made explicit
- **YAGNI**: no feature added unless it came from the conversation
- **Domain coverage & DDD consistency**: conflicts and side effects are grounded in the Step 1 scan and Step 2 confirmation (not speculation); domain vocabulary is used consistently; aggregate/invariant boundaries aren't violated; behavior isn't scattered into services when it belongs on the owning entity (anemic domain model); every topic from Step 2 and Step 4 appears somewhere in the doc. Add whatever's missing into whichever section fits.

### Step 7: User Review → Hand Off (only when explicitly instructed)

After writing, present the path and ask for review:

> "설계 spec 문서를 `{file path}`에 작성했습니다. 확인해주시고, 수정할 부분이 있으면 알려주세요."

- **change request** → apply the changes, then re-present the updated document
- **Do NOT invoke plan-creator automatically.** Only when the user explicitly instructs you to proceed ("plan-creator로 넘어가줘", "구현 계획 작성해줘" 등) → invoke plan-creator with the spec document path as input

**If plan-creator is not available:**
> "plan-creator를 찾을 수 없습니다. 문서 경로: `{file path}`"

---

## Principles

- **Never write or hand off without an explicit instruction** — confirming a step ≠ telling you to write the file or run plan-creator (see HARD-GATE)
- **Surface concerns continuously; summarize and confirm when none remain** — don't move on with an open worry unspoken
- **what/why + design, not how** — implementation breakdown belongs to plan-creator
- **Scale to complexity** — sections can be a few sentences or several hundred words
- **Batch, then narrow** — ask everything at once in Step 2; follow up only on gaps
- **Confirm domain understanding, don't assume it** — verified in Step 2, not guessed
- **Never guess; YAGNI** — ask when unclear, don't add scope the user didn't mention
- **Domain-driven, when applicable** — respect existing bounded contexts, aggregates, and ubiquitous language (Step 1); skip entirely for features with no domain logic
