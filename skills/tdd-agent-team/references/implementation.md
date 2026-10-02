# Implementation Guide

How production code is written and tidied in this skill. The rules are language-agnostic; Java (Spring) is the worked example. In another stack, apply the same rule with that stack's idiom.

This guide covers **what the code looks like**. The order of work — red check, minimal pass, refactor, report — is your role definition's business.

## 1. Scope: Exactly What the Tests Demand

- Implement only what the task's tests require. No unrequested features, no "just in case" parameters, hooks, or patterns. A behavior no test asks for is a new task, not part of this one.
- If the change balloons far beyond what the tests need — it could plausibly be half the size — rewrite it simpler before you report.
- Touch only the files listed under "In-scope files" in `context.md`.

## 2. First Make It Pass, Then Make It Right

- **Pass step:** the simplest code that turns the tests green. Hardcoding and a plain conditional are acceptable here.
- **Refactor step:** only once green, and only on the production code you just changed (section 6).
- Never both at once — a refactor mixed into the pass step hides which change broke a test.

## 3. Business Rules Live in the Domain, in Domain Language

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

## 4. Layers and Dependencies

Dependencies point inward only:

| Layer | Holds | May depend on |
|---|---|---|
| Domain | entities, value objects, domain rules | nothing external |
| Application | use cases, orchestration | Domain |
| Infrastructure | persistence, external clients — implements Domain interfaces | Domain |
| Presentation | controllers, request/response DTOs | Application |

**Anti-patterns — never write these:**

| Anti-pattern | Instead |
|---|---|
| Controller accesses the database directly | Controller calls an application service |
| Entity returned as the API response | Map to a response DTO (`OrderResponse.from(order)`) |
| Business logic in the controller | Move it into the domain or application layer |
| Domain imports infrastructure | Domain defines an interface; infrastructure implements it |
| Abstract class or interface with a single implementation | Use the concrete class until a second case actually exists |

## 5. Design Principles (SOLID, applied lightly)

- **SRP** — one class, one responsibility.
- **OCP** — extend through an interface *when a second case exists*; do not pre-build extension points.
- **LSP** — a subtype must be usable wherever its parent is.
- **ISP** — small, specific interfaces over one wide one.
- **DIP** — depend on abstractions at layer boundaries.

These justify a structure only when the tests or the existing code already need it. Simplicity (KISS) and not building ahead (YAGNI) win any tie.

## 6. Refactor (after green): Named Refactorings, Behavior Unchanged

This is TDD's refactor step, not Tidy First. Restructuring beyond the code you just wrote is not yours to do: structural changes that make a requirement easier belong to the plan's Tidy First, done and committed before this session started.

After green, check the code you changed against these smells and apply the named technique. Skip with a stated reason if it is already clean — "no refactoring needed" without a reason is not acceptable.

| Smell | Technique |
|---|---|
| Duplicate logic | Extract Method / remove duplication (DRY) |
| Unclear or misleading names | Rename Variable / Rename Method |
| Method over ~10 lines without reason, or doing more than one thing | Extract Method |
| Uses another class's data more than its own (Feature Envy) | Move Method |
| Handles a responsibility that belongs to another class | Move Method / Extract Class |
| Mixes high- and low-level steps instead of descending one level at a time | Compose Method |
| A layer or helper wrapping code used exactly once | Inline it |

Behavior must not change and no functionality is added. Re-run the task's methods after refactoring; if any fails, revert the refactor. If a simpler structure exists, use it even when the "clever" one is technically nicer.

## 7. Readable by Itself

- Clear, self-documenting names over comments. A comment explains *why*, never *what*.
- Inside a class, public methods come first, private methods after.

```java
public class OrderService {
    public OrderResponse cancel(Long orderId) {      // public first
        Order order = orderReader.getById(orderId);
        order.cancel();
        return OrderResponse.from(order);
    }

    private void notifyCancellation(Order order) { … }   // private after
}
```

## 8. Never Touch Tests

Test files are not yours — not to fix a typo, not to loosen an assertion, not through a shell command. If a test looks wrong, report it to the lead; do not make it pass by changing it.
