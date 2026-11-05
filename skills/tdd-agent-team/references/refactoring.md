# Refactoring Guide

The rules for restructuring production and test code without changing what it does — in the **Refactor step** of Red-Green-Refactor, and in **Tidy First** before the cycle. The rules are language-agnostic; Java (Spring) is the worked example. In another stack, apply the same rule with that stack's idiom.

| Moment | What | Scope |
|---|---|---|
| **Tidy First** — before the cycle | Restructure so the requested change is easy to make | Exactly the confirmed tidy items, nothing else |
| **Refactor** — at the end of every task's cycle | Make the task's minimal code and its tests readable and well-designed | That task's scope: its `scope_production` files and its `test_class` |

In both, **behavior never changes and no functionality is added.** Every test that passes before you start must pass after.

## 1. Tidy First: Only the Confirmed Items

Restructure the existing code so the requirement is easy to add, without changing what it does.

- Change only the code the tidy item names, with only the restructuring it names. A tidy item is not a licence to clean up the neighbourhood.
- If the item cannot be done without changing behavior, stop and report it blocked — the item was wrong about being structural.
- Add none of the requirement's new behavior — that arrives in the cycle as a task, test first. For an abstraction item, see the example in `references/tidy-first-scan.md` section 2.

## 2. Refactor: Named Techniques Against Named Smells

### One responsibility per class — check this first

The smell table looks at one method at a time, so it misses a class that grows a responsibility per task. Before using it, go through every production class in the task's scope:

1. **State its responsibility in one sentence.** If the sentence needs "and" — it validates *and* calculates *and* notifies — the class has more than one.
2. **Group its methods by the fields and dependencies they use.** Two or more groups that share nothing are two classes sharing a file.
3. **Count the reasons it would change.** A policy change and a storage change landing in the same class are two reasons.

Any one of these showing more than one responsibility makes the class a candidate: Extract Class, one class per reason, or record why it stays under `deferred`.

### Smell → technique

Check every production file in the task's scope against these smells and apply the named technique. Look between tasks too: the scope may hold earlier tasks' code, each written as its own minimum, and duplication and misplaced responsibility hide there. Skip a file that is already clean, and give the reason in `refactor-result`.

| Smell | Technique |
|---|---|
| Duplicate logic | Extract Method / remove duplication (DRY) |
| A hardcoded value or special case the tests now check with more than one input | Replace with the general form those tests demand |
| Unclear or misleading names | Rename Variable / Rename Method |
| A method doing more than one thing | Extract Method |
| Uses another class's data, or does its job (Feature Envy) | Move Method / Extract Class |
| Mixes high- and low-level steps instead of descending one level at a time | Compose Method |

If a simpler structure exists, use it even when the "clever" one is technically nicer.

## 3. Design Principles (SOLID, applied lightly)

- **SRP** — one class, one responsibility (check it as in section 2).
- **OCP** — extend through an interface *when a second case exists*; do not pre-build extension points.
- **LSP** — a subtype must be usable wherever its parent is.
- **ISP** — small, specific interfaces over one wide one.
- **DIP** — depend on abstractions at layer boundaries.

Apply a principle only when the code already needs it. When a principle asks for more structure and the code works fine without it, keep it simple (KISS, YAGNI).

YAGNI covers what nobody needs yet — an interface with one implementation, a hook for a case that does not exist, a layer or helper used once. It never covers splitting what a class already does: a class with two responsibilities gets split.

### The right layer

Dependencies point inward only, so domain rules can change and be tested without the database or outside systems:

| Layer | Holds | May depend on |
|---|---|---|
| Domain | entities, value objects, domain rules | nothing external |
| Application | use cases, orchestration | Domain |
| Infrastructure | persistence, external clients — implements Domain interfaces | Domain |
| Presentation | controllers, request/response DTOs | Application |

Anti-patterns — move any you find. If the right home is an existing file outside the task's scope, record it under `deferred` instead:

| Anti-pattern | Instead |
|---|---|
| Controller accesses the database directly | Controller calls an application service |
| Entity returned as the API response | Map to a response DTO (`OrderResponse.from(order)`) |
| Business logic in the controller | Put it in the domain or application layer |
| Domain imports infrastructure | Domain defines an interface; infrastructure implements it |

### Reuse what already exists

Call an existing service instead of wiring a repository yourself — e.g. a read service that already does "find by id, throw if missing". A second copy of that logic drifts from the first.

## 4. Readable by Itself

- Clear, self-documenting names over comments. A comment explains *why*, never *what*.
- Inside a class, public methods come first, private methods after — a reader sees what the class offers before how it works.

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

## 5. Tests: Follow the Structure, Then Tidy Them

Tests are yours to change in two ways, and only these two:

- **Following a structural change.** Moving a class or renaming a method can leave a test that no longer compiles or no longer reaches the code. Fix it yourself — imports, references, call names.
- **Tidying the task's tests.** Duplicated setup → a helper or fixture, unclear names, assertion style — by the test-writing rules (path in your role file).

In both, **what a test checks never changes**: not an assertion, not an input, not which behavior it exercises — and no test is added or deleted. If a change would need that, it is a behavior change — undo it. Record every test change under `test_changes` in your result.

## 6. Scope and `deferred`

- **New files are in scope.** Moving in-scope code into a new class — Extract Class, Move Method, a new DTO — belongs to the task. List the new file under `files_modified`.
- **Nothing else outside the scope is yours to change** — another task's files, code the session never touched. Another teammate may be editing it right now.
- **Record what you leave alone under `deferred`** — where, which smell, which technique you would apply, and why you left it:
  - a smell outside the scope;
  - a class you kept with two responsibilities;
  - a move whose target lies outside the scope.
