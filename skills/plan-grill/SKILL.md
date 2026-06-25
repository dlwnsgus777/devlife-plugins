---
name: plan-grill
description: Runs plan-creator then immediately grills the user on the resulting plan. Use when the user wants to both create a plan and stress-test it in one flow. Trigger on "plan-grill", "계획 작성하고 검증해줘", "계획 짜고 심문해줘", "계획 만들고 파고들어줘".
---

# Plan Grill

This is a two-phase workflow that chains plan-creator and grill-me.

## Phase 1: Create the Plan

Run the `plan-creator` skill — Steps 1 through 3 only (context gathering, clarifying questions, writing the document).

**Skip plan-creator's Step 4 (feedback request).** After writing the plan document, output this message in plain text:

> "계획 문서 작성 완료. 검토 후 준비되시면 'grill me'라고 입력해 주세요."

Wait for the user to type "grill me" before proceeding.

## Phase 2: Grill the Plan

When the user types "grill me", run the `grill-me` skill using the plan document as context.

Interview the user relentlessly about every aspect of the plan until reaching a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.
