# Implementation Guide

The rules for production code in the **Green step** of Red-Green-Refactor: **the minimum that makes the failing tests pass.** The rules are language-agnostic; Java (Spring) is the worked example. In another stack, apply the same rule with that stack's idiom.

This guide covers **what the code looks like**, not the order of work. Readability, design, and refactoring are outside it (`references/refactoring.md`).

## 1. Scope: Exactly What the Tests Demand

Code no test asks for is code no test checks.

- Implement only what the task's tests require. No unrequested features, no "just in case" parameters, hooks, or patterns. A behavior no test asks for is a new task, not part of this one.
- Before you report, check what you added against the tests: a branch, method, class, or parameter that no test exercises comes out.
- Touch only the files listed under "In-scope files" in your role file.

## 2. Minimum to Pass — and Stop

Write the minimum code that passes the tests, then stop. Once the tests pass, the behavior is pinned, and any restructuring after that can be checked against them.

- Hardcoding and a plain conditional are acceptable.
- **Do not refactor.** No renaming, extracting, or restructuring of the code you just wrote, and none of the code around it — cleanup is a separate step.

## 3. Domain Language

- A guard clause reads as the business rule — names and its exception message in domain terms a user or caller would understand.
- Never write session bookkeeping into code or tests — anything whose meaning lives only in `_workspace/`: invariant IDs (`INV-001`), task or tidy numbers, workspace paths, teammate names. Code must still make sense after the session ends.

```java
public void cancel() {
    if (status == PAID) {
        throw new OrderException("결제 완료된 주문은 취소할 수 없습니다");
    }
    status = CANCELLED;
}
```
