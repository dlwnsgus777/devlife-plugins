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

If a spec document path is provided (from devlife-brainstorming or otherwise), read it before anything else. Take its domain context, invariants, and scope as given — do not re-derive them — identify which subtask this plan covers, and skip any Step 2 question it already answers.

### Step 0: Classify Scope and Depth

Do this before any code discovery — it decides how much of the rest of this skill runs.

**Workspace**: does this task add new files only (greenfield for this feature), or modify existing code (brownfield)? Brownfield is what makes Section 0 apply; greenfield skips it entirely.

**Depth**: pick one.

| Depth | Fits | Step 1 discovery | Step 2 | Template sections |
|-------|------|------------------|--------|-------------------|
| **Minimal** | Bug fix, behavior-preserving refactor, single-file change | Target file + direct callers; no variation-point scan | 2–4 questions, one round | Skip 3 (API), 4 (business logic), 6 (considerations) |
| **Standard** | New feature, extending an existing one | Feature domain | 5–8 questions | All, minus what truly doesn't apply |
| **Comprehensive** | New module, new bounded context, cross-cutting change | Feature domain + read every touched aggregate | 8–12 questions, probe failure modes and scale | All, plus risk notes in Section 6 |

Step 1's category table says which discovery categories each depth requests.

**Never infer depth silently.** Confirm it in one line with the concrete consequence, so the user knows what they are agreeing to:

> "버그 수정으로 보여서 Minimal로 진행하려 합니다 — 코드 탐색은 대상 파일 주변만, 질문 2~4개, API·비즈니스 로직 섹션 생략. 이대로 갈까요, 아니면 범위를 넓힐까요?"

A request that reads like a keyword match ("리팩터링해줘") but comes with a long description is probably not that keyword — the description outranks the keyword. Ask instead of routing on it.

### Step 1: Context Gathering

**Scope the sweep to Step 0's depth before dispatching.** Discovery output is the largest single thing entering this skill's context, and an unscoped sweep of a mature domain returns far more than the plan can use.

1. Spawn a sub-agent via `Agent({ subagent_type: "Explore", ... })` with the prompt below.
2. If the Explore agent is unavailable, say `not available`, then perform the same scoped discovery locally with `rg`, `rg --files`, and focused file reads.

Request only the categories the depth calls for:

| # | Category | Minimal | Standard | Comprehensive |
|---|----------|:-------:|:--------:|:-------------:|
| 1 | Controllers handling [feature] — paths, endpoint annotations, method signatures | ● | ● | ● |
| 2 | Services in the same domain — class names, public method signatures | ● | ● | ● |
| 3 | Domain models/entities — class names, key fields, enum values | | ● | ● |
| 4 | `find-by-id + throw` patterns already encapsulated in ReadService classes | | ● | ● |
| 5 | Related exception classes and where they're thrown | | ● | ● |
| 6 | Validation annotations / guard clauses hinting at business constraints | | ● | ● |
| 7 | Existing tests that already verify behavior this requirement touches | ● | ● | ● |

Two further cuts:
- At **Minimal**, the scope is the target file and its direct callers — not the domain. Say so in the prompt instead of naming a domain.
- Skip **6** when a spec document already fixed the invariants (see Document Input). Re-deriving them from guard clauses redoes work the spec settled, and lands them as weaker `[코드추론]` evidence besides.

Explorer prompt:

> "Scan [target file + its direct callers | the [feature domain]] in this project and report the categories below — **file paths and signatures only, no full implementations**.
> Cap each category at the **8 most relevant** entries. If there are more, list the top 8 and add a `+N more` count line rather than enumerating them.
> Category 7 means tests whose behavior overlaps [requirement] — not an inventory of the domain's test suite.
>
> [the numbered categories selected above]"

After discovery, directly read only the 2–3 most relevant files to identify business invariants (guard clauses, state transitions, validation annotations).

**Reusable code scan**: From the Explore results, identify existing services, utilities, and exception classes that already handle overlapping concerns. In particular, if "find-by-id + throw" patterns are encapsulated in a ReadService, inject that service rather than wiring a repository directly — reflect this in the code snippets.

**Existing code modification** (brownfield only, per Step 0): identify the change targets and judge whether their current structure makes the new requirement hard to add — that judgment decides whether Section 0 is included.

**Variation point scan** (skip at Minimal depth — a bug fix is not the moment to redesign an axis): find the axis this domain keeps changing along — branching on an enum/type/channel, policy values hardcoded in a service, near-duplicate methods differing in one step. That axis is where the next requirement lands, so it is the abstraction candidate for `0-2`.

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

Ask in **rounds of up to 4 questions at a time**, in Korean, and stay inside the depth
budget from Step 0 (Minimal 2–4 total, Standard 5–8, Comprehensive 8–12). Wait for answers
before starting the next round. Cover: goal/problem, affected modules, API style, data
source, and success definition, along with any domain/invariant questions raised in Step 1.

The budget is a target, not a cap. Go over it when an answer is contradictory or dangerously
vague; go under it when the spec document or the code already answers the question. Padding to
reach the number is worse than asking three good questions.

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

Read and use the template from `assets/plan-template.md` — fill every section that Step 0's depth calls for, omitting the rest plus any that truly don't apply (e.g., API Design for batch or refactoring work).

#### Domain Context & Invariants (Section 2)

**Rule: never guess.** If you don't know the business reason behind a concept or invariant, it means you should have asked in Step 2. If something is still unclear when you reach this section, **stop and ask the user before continuing** — do not fill the section with inferred or assumed content.

Write **domain context** as prose sentences, not bullet points. A developer reading this for the first time should understand the domain's key concepts and assumptions from these sentences alone. Only write what you know from Step 1 code analysis or Step 2 answers.

Write **business invariants** as complete declarative sentences: "If X, then Y must always hold" / "Z is never permitted when W." Include what breaks if the invariant is violated — this is what makes the rule stick in the reader's mind. If you can't state the violation consequence with confidence, ask the user.

> Bad: `No amount change after approval`
> Good: `The amount of an approved contract can never be changed under any circumstances. Allowing this causes settlement discrepancies and audit failures.`

Give each invariant a stable **ID** (`INV-001`, …) and an **출처** tag. Section 7 then references the ID instead of restating the sentence, and tdd-team can carry the same IDs into its invariant table and its final coverage check — so "every invariant has a test" becomes a lookup rather than a judgment call.

| 출처 | Means | Review weight |
|------|-------|---------------|
| `[문서]` | Stated in the spec/ticket as written | Lowest — already agreed |
| `[사용자확인]` | Answered by the user in Step 2 | Low |
| `[코드추론]` | Read off a guard clause or enum, motivation not confirmed | **Highest — flag these for the user explicitly** |

Also extract invariants from code discovered in Step 1 — enum state transitions, validation annotations, and guard clauses are all domain rules in disguise. But they land as `[코드추론]`: code shows the constraint exists, not why it exists or what it protects. Never promote one to `[사용자확인]` without an actual answer.

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

After writing the document, run these six checks and fix what you can inline — no need to re-review after fixing.

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

**6. Invariant coverage**: does every `INV-xxx` appear in at least one Section 7 entry, and does every Section 7 test trace back to an invariant or an explicit requirement? A test with no upstream is either an unwritten invariant or scope creep — resolve which.

**Report the result, don't just fix silently.** Show the outcome as part of Step 4 so the user sees what was checked:

```
자체 검증: 6개 항목 중 5개 통과
- FAIL 2번 (플레이스홀더): 섹션 4-2의 "예외 처리 추가" → 구체 문구로 교체함
- FAIL 6번 (불변성 커버리지): INV-003을 검증하는 테스트가 섹션 7에 없음 — 확인 필요
```

A check you fixed is reported as fixed. **A check you could not fix without a decision blocks the handoff**: do not proceed to Step 5 until it is resolved, and say so in Step 4 rather than passing an incomplete plan to tdd-team.

### Step 4: Request Feedback (Mandatory)

After writing the document, ask the user in a normal assistant message:

> "계획 문서를 작성했습니다. 수정하거나 보완할 부분이 있으신가요?
> 특히 [단계 구성 / 누락된 항목 / 범위]에 대한 의견을 주시면 반영하겠습니다."

If `0-2` has an entry, ask about it in the same message and delete it from the document if rejected — never leave it as "추후 검토":

> "섹션 0-2에 [변화 지점] 추상화([제안])를 제안했습니다. 지금 도입할지, 케이스가 더 쌓일 때까지 미룰지 판단해주세요."

Do NOT proceed to implementation without explicit approval.

### Step 5: Hand Off to tdd-team (Terminal State)

Once approved, ask:

> "계획 문서가 완성되었습니다. tdd-team으로 이어서 구현을 시작할까요, 아니면 여기서 마칠까요?"

If they continue and `tdd-team` is available, read its `SKILL.md` and pass the plan document path as input. If it is unavailable, or they choose to stop, say so and share the plan path.
