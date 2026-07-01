---
name: plan-grill
description: Runs plan-creator then immediately grills the user on the resulting plan. Use when the user wants to both create a plan and stress-test it in one flow. Trigger on "plan-grill", "계획 작성하고 검증해줘", "계획 짜고 심문해줘", "계획 만들고 파고들어줘".
---

# Plan Grill

This is a two-phase workflow that chains plan-creator and grill-me skills.

## Phase 1: Create the Plan

Use the `Skill` tool to invoke `plan-creator` with the user's arguments. This will:
- Gather context from the codebase
- Ask clarifying questions via `AskUserQuestion`
- Write the plan document

**Skip plan-creator's Step 4 (feedback request).** After the plan document is written, output this message in plain text:

> "계획 문서 작성 완료. 준비되시면 'grill me'라고 입력해 주세요."

**Phase 1 중 어떤 상호작용(수정 요청, 피드백 등)이 오더라도 반드시 같은 안내 문구로 끝내야 한다. 절대로 "구현을 진행할까요?"나 구현 관련 질문으로 넘어가지 않는다.**

Wait for the user to type "grill me" before proceeding.

## Phase 2: Grill the Plan

When the user types "grill me", use the `Skill` tool to invoke `grill-me` with the plan document as context.

The grill-me skill will interview the user relentlessly about every aspect of the plan until reaching shared understanding, resolving each branch of the decision tree one question at a time.
