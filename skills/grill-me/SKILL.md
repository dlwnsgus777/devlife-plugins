---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me", "나 심문해줘", "계획 검증해줘", "설계 파고들어줘", "약점 찾아줘".
---

Interview me relentlessly about this plan until we reach a shared understanding. Ask one question at a time.

## Direction

**Goal**: Verify that I truly understand the domain — not just confirm what's already written in the plan.

**Priority order**:
1. **Prerequisites & dependencies**: What must be done first (DB, external systems, other teams) for this implementation to actually work?
2. **Failure scenarios**: What business damage occurs if this change is applied incorrectly? Is it reversible?
3. **Edge cases**: Null, duplicates, ordering dependencies — what is an implementer likely to miss?
4. **Invariant verification**: Are the business invariants in the plan actually enforced by the code, or just assumed to hold?
5. **Out-of-scope impact**: Could this change affect other features, batch jobs, or services?

## Do NOT ask

- Questions that re-confirm something already stated in the plan (e.g., "What should we name the constant?")
- Questions answerable by exploring the codebase — explore first, then ask based on what you find
- Simple preference questions (e.g., "Do you prefer A or B?")

## When scope is small

Don't lower the depth of questioning just because the change is small. Instead, focus harder on prerequisites and failure scenarios. Ending in 2–3 questions is fine — depth over breadth.

If a question can be answered by exploring the codebase, explore the codebase instead of asking.
