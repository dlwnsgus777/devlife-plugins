# Implementation Guide

How GREEN writes production code in this skill: **the minimum that makes the tests pass, in the right place.** The rules are language-agnostic; Java (Spring) is the worked example. In another stack, apply the same rule with that stack's idiom.

This guide covers **what the code looks like**. The order of work — red check, pass, report — is your role definition's business. Readability, design, and refactoring are not here: `tdd-refactor` owns them after the cycle (`references/refactoring.md`).

## 1. Scope: Exactly What the Tests Demand

- Implement only what the task's tests require. No unrequested features, no "just in case" parameters, hooks, or patterns. A behavior no test asks for is a new task, not part of this one.
- If the change balloons far beyond what the tests need — it could plausibly be half the size — rewrite it simpler before you report.
- Touch only the files listed under "In-scope files" in `context.md`.

## 2. Minimum to Pass — and Stop

- Write the simplest code that turns the tests green. Hardcoding and a plain conditional are acceptable; a later task's tests will force the generalization when it is really needed.
- **Do not refactor.** No renaming, extracting, or restructuring of the code you just wrote, and none of the code around it. `tdd-refactor` cleans up once every task is green; a refactor mixed into the pass step hides which change broke a test and collides with RED running ahead.

## 3. The Right Place, Even When Minimal

Minimal is about how much code, not where it goes. Code put in the wrong layer now is code someone must move later, so these hold from the first line.

**Business rules live in the domain, in domain language.**

- A guard clause states its rule in the domain's words; its exception message is what a user or caller would understand.
- Never write invariant IDs (`INV-001`) into code — not in comments, names, or messages.

```java
public void cancel() {
    if (status == PAID) {
        throw new OrderException("결제 완료된 주문은 취소할 수 없습니다");
    }
    status = CANCELLED;
}
```

- Prefer reusing an existing service over wiring a repository yourself — e.g. a read service that already does "find by id, throw if missing".

**Dependencies point inward only:**

| Layer | Holds | May depend on |
|---|---|---|
| Domain | entities, value objects, domain rules | nothing external |
| Application | use cases, orchestration | Domain |
| Infrastructure | persistence, external clients — implements Domain interfaces | Domain |
| Presentation | controllers, request/response DTOs | Application |

**Anti-patterns — never write these, however small the change:**

| Anti-pattern | Instead |
|---|---|
| Controller accesses the database directly | Controller calls an application service |
| Entity returned as the API response | Map to a response DTO (`OrderResponse.from(order)`) |
| Business logic in the controller | Put it in the domain or application layer |
| Domain imports infrastructure | Domain defines an interface; infrastructure implements it |
| Abstract class or interface with a single implementation | Use the concrete class until a second case actually exists |

## 4. Never Touch Tests

Test files are not yours — not to fix a typo, not to loosen an assertion, not through a shell command. If a test looks wrong, report it to the lead; do not make it pass by changing it.
