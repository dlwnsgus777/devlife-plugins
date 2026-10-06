# Refactoring Guide

How `tdd-refactor` changes the structure of production code in this skill, without changing what it does. The rules are language-agnostic; Java (Spring) is the worked example. In another stack, apply the same rule with that stack's idiom.

`tdd-refactor` works in two moments, and this guide covers both:

| Moment | What | Scope |
|---|---|---|
| **Tidy First** — before the cycle | Restructure so the requirement can land in one place | Exactly the confirmed tidy items, nothing else |
| **Refactor** — after the cycle | Make GREEN's minimal code readable and well-designed | The production files this session changed |

In both, **behavior never changes and nothing is added.** The safety-net tests pass before you start and must pass after.

GREEN's rules (`references/implementation.md`) still hold for what you leave behind — scope, the right layer, no anti-patterns. You never edit test files; when a test must follow a moved class or a renamed method, you list the edit for RED (section 5).

## 1. Tidy First: Only the Confirmed Items

- A tidy item — from the requirements document, or a lead's candidate the user approved — names what blocks the change, the restructuring, and where the change lands afterwards. Apply **that technique to that code.** A tidy item is not a licence to clean up the neighbourhood.
- If the item cannot be done without changing behavior, stop and report it blocked — the item was wrong about being structural.
- A confirmed abstraction item is extracted here **from the cases that already exist**. The new case it is meant to receive is behavior, and arrives in the cycle as a task.

## 2. Refactor: Named Techniques Against Named Smells

After the cycle, check every production file the session changed against these smells and apply the named technique. Look across tasks: GREEN wrote each task's minimum in isolation, so duplication and misplaced responsibility hide **between** tasks. Skip a file with a stated reason if it is already clean — "no refactoring needed" without a reason is not acceptable.

| Smell | Technique |
|---|---|
| Duplicate logic | Extract Method / remove duplication (DRY) |
| Hardcoded value or special case that a general form now covers | Replace with the general form the tests already demand |
| Unclear or misleading names | Rename Variable / Rename Method |
| Method over ~10 lines without reason, or doing more than one thing | Extract Method |
| Uses another class's data more than its own (Feature Envy) | Move Method |
| Handles a responsibility that belongs to another class | Move Method / Extract Class |
| Mixes high- and low-level steps instead of descending one level at a time | Compose Method |
| A layer or helper wrapping code used exactly once | Inline it |

Identify all opportunities first, then apply them as one batch and run the safety net. If anything fails, revert the batch and apply changes one at a time, testing after each, to find the one that broke it. If a simpler structure exists, use it even when the "clever" one is technically nicer.

## 3. Design Principles (SOLID, applied lightly)

- **SRP** — one class, one responsibility.
- **OCP** — extend through an interface *when a second case exists*; do not pre-build extension points.
- **LSP** — a subtype must be usable wherever its parent is.
- **ISP** — small, specific interfaces over one wide one.
- **DIP** — depend on abstractions at layer boundaries.

These justify a structure only when the code already needs it. Simplicity (KISS) and not building ahead (YAGNI) win any tie.

## 4. Readable by Itself

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

## 5. When a Test Must Follow

Moving a class or renaming a method can leave a test that no longer compiles or no longer reaches the code. **Do not edit the test.** Write the exact mechanical edits it needs — file, old text, new text — and send them to RED directly. These edits follow structure only: imports, references, call names. An assertion, an input, or which behavior a test checks never changes in a refactor; if your change would require that, it is a behavior change — undo it.
