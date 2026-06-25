---
description: Use when implementing any feature or bugfix in a
  Java/Spring Boot codebase, before writing production code.
name: test-driven-development
---

# Test-Driven Development (TDD) -- Java Edition

## Overview

Write the test first.\
Watch it fail.\
Write the minimal code to make it pass.

**Core principle:**\
If you didn't watch the test fail, you don't know if it actually tests
the right behavior.

Violating the letter of these rules is violating the spirit of TDD.

------------------------------------------------------------------------

## When to Use

### Always

-   New features
-   Bug fixes
-   Refactoring
-   Behavior changes
-   Performance improvements that must preserve behavior

### Exceptions (ask your human partner)

-   Throwaway prototypes
-   Generated code
-   Pure configuration files

### Do NOT Write Tests For

-   **Simple object creation** — constructors, static factory methods, or builders that only assign fields. These have no behavior to verify.
-   **Trivial getters/setters** — if the only assertion is `assertThat(obj.getName()).isEqualTo("name")` after setting it, the test adds no value.
-   **Data classes / DTOs / records** — plain data holders without business logic do not need tests.

    ```java
    // ❌ Do not test this — no behavior
    @Test
    void createOrder() {
        Order order = new Order("id", "userId");
        assertThat(order.getId()).isEqualTo("id");
    }

    // ✅ Test this — business behavior exists
    @Test
    void order_is_cancelled_when_payment_fails() {
        Order order = new Order("id", "userId");
        order.cancelDueToPaymentFailure();
        assertThat(order.getStatus()).isEqualTo(OrderStatus.CANCELLED);
    }
    ```

Thinking "skip TDD just this once"?\
That's rationalization. Stop.

------------------------------------------------------------------------

## The Iron Law

    NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST

If you wrote production code before writing a failing test:

-   Delete it.
-   Do not keep it as reference.
-   Do not "adapt" it.
-   Do not look at it.
-   Delete means delete.

Implement fresh from the tests. Period.

------------------------------------------------------------------------

# The TDD Cycle

    RED → GREEN → REFACTOR

1.  RED -- Write a failing test.
2.  GREEN -- Write the minimal code to pass.
3.  REFACTOR -- Improve structure without changing behavior.

Repeat.

------------------------------------------------------------------------

## RED -- Write a Failing Test

Write one minimal test that expresses a single behavior.

### Good Example (JUnit 5 + AssertJ)

``` java
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class RetryServiceTest {

    @Test
    void retries_failed_operation_three_times() {
        RetryService retryService = new RetryService();

        final int[] attempts = {0};

        String result = retryService.retry(() -> {
            attempts[0]++;
            if (attempts[0] < 3) {
                throw new RuntimeException("fail");
            }
            return "success";
        });

        assertThat(result).isEqualTo("success");
        assertThat(attempts[0]).isEqualTo(3);
    }
}
```

------------------------------------------------------------------------

## Verify RED -- Watch It Fail (Mandatory)

Gradle:

    ./gradlew test --tests RetryServiceTest

Maven:

    mvn -Dtest=RetryServiceTest test

Confirm:

-   The test fails (not errors).
-   The failure message matches your expectation.
-   It fails because the feature is not implemented.

Never skip this step.

------------------------------------------------------------------------

## CHECKPOINT: RED Complete — STOP (Mandatory)

⛔ **STOP. Do not write any production code yet.**

After RED, you MUST:

1.  Show the written test code to the user.
2.  Request feedback in this exact format:

> "Could you provide feedback on this test?
> I'd especially appreciate input on [test case coverage / missing scenarios]."

3.  **Wait silently.** Do NOT continue to GREEN under any circumstance until the user sends an explicit approval message (e.g., "proceed", "LGTM", "다음으로", "진행해").
4.  If the user gives feedback without approving, incorporate it and repeat this checkpoint.

------------------------------------------------------------------------

## GREEN -- Minimal Production Code

``` java
public class RetryService {

    public <T> T retry(Supplier<T> supplier) {
        for (int i = 0; i < 3; i++) {
            try {
                return supplier.get();
            } catch (Exception e) {
                if (i == 2) throw e;
            }
        }
        throw new IllegalStateException("Unreachable");
    }
}
```

Only implement what the test requires. Nothing more.

------------------------------------------------------------------------

## CHECKPOINT: GREEN Complete — STOP (Mandatory)

⛔ **STOP. Do not begin refactoring yet.**

After GREEN, you MUST:

1.  Show the written implementation code to the user.
2.  Request feedback in this exact format:

> "Could you provide feedback on this implementation?
> I'd especially appreciate input on [design decisions / edge case handling]."

3.  **Wait silently.** Do NOT continue to REFACTOR until the user sends an explicit approval message.
4.  If the user gives feedback without approving, incorporate it and repeat this checkpoint.

------------------------------------------------------------------------

## REFACTOR -- Improve Structure

After GREEN is confirmed, evaluate whether REFACTOR is needed using this checklist:

**REFACTOR is required if any of the following apply:**

-   Duplicate logic exists between production code or across tests
-   Method or variable names are unclear or misleading
-   A method exceeds ~10 lines without a clear reason
-   Domain concepts are modeled poorly (e.g., primitive obsession, missing abstraction)

**REFACTOR may be skipped only if:**

-   The GREEN implementation is already clean and minimal
-   You explicitly state: `"REFACTOR skipped — [specific reason why the current implementation is already clean]"`
-   Saying "no refactoring needed" without a stated reason is not acceptable.

When refactoring:

-   Remove duplication
-   Improve naming
-   Extract methods
-   Improve domain modeling
-   Simplify structure

Behavior must not change. Run the full test suite after each refactoring step to confirm.

------------------------------------------------------------------------

## CHECKPOINT: REFACTOR Complete — STOP (Mandatory)

⛔ **STOP. Do not begin the next RED cycle yet.**

After REFACTOR (or after explicitly skipping it with a stated reason), you MUST:

1.  Show either the before/after diff of the refactoring, or the skip reason.
2.  Request feedback in this exact format:

> "Could you provide feedback on this refactoring?
> I'd especially appreciate input on [structural changes / naming]."

3.  **Wait silently.** Do NOT start the next RED until the user sends an explicit approval message.
4.  If the user gives feedback without approving, incorporate it and repeat this checkpoint.

------------------------------------------------------------------------

## When to End the Cycle

The RED → GREEN → REFACTOR cycle ends when **all of the following are true**:

-   All planned test scenarios for the current feature are GREEN.
-   No new failing behavior can be identified within the agreed scope.
-   The user explicitly confirms the feature is complete.

When ending, state explicitly:

> "All scenarios are covered and GREEN. TDD cycle for [feature name] is complete."

Do NOT add speculative tests or behaviors beyond the agreed scope to extend the cycle.

------------------------------------------------------------------------

## Test Data Setup

**Always use Fixture builders to create entities in tests.**

Do not construct entities directly via `new` or raw `.builder()` — use the project-defined Fixture factory methods instead.

``` java
// ❌ Do not do this — raw builder, fragile and verbose
FittingContract contract = FittingContract.builder()
    .outletNumber("9999991")
    .consultantName("홍길동")
    .contractStatus(ContractStatus.ACTIVE)
    // ... many fields ...
    .build();

// ✅ Do this — Fixture provides safe defaults, tests state only what matters
FittingContract contract = fittingContractRepository.save(
    aFittingContract()
        .outletNumber("9999991")
        .contractStatus(ContractStatus.TERMINATED)
        .build()
);
```

**Rules:**
- Fixture methods (e.g., `aFittingContract()`, `aContact()`) supply all required defaults.
- Override only the fields relevant to the test scenario.
- Wrap `repository.save(fixture.build())` in a private helper method (e.g., `createTerminatedContract(...)`) to keep test bodies readable.
- Never duplicate fixture logic across tests — extract shared setup into a helper.

------------------------------------------------------------------------

# Final Rule

    Production code → a test existed and failed first
    Otherwise → not TDD
