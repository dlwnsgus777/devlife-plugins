# Test Writing Guide

How to write a test in this skill. The rules are language-agnostic; Java (JUnit 5 + AssertJ) is the worked example. In another stack, apply the same rule with that stack's idiom — the table at the end maps the Java constructs.

This guide covers **what a test looks like**. When to run tests, and in what order, is your role definition's business.

## 1. What Deserves a Test

- **Every scenario the task names, in one pass.** List the scenarios of the expected behavior before writing, and give each one its own test case. A scenario with no test is not unverified — it is unbuilt, because GREEN builds exactly what the tests demand.
- **Each business rule at its boundary**: the case that violates it, the nearest case that satisfies it, and every state or input the rule itself names.
- **Not** constructors or factories with no behavior, trivial accessors, or plain data holders (DTOs, records). A test case with no business rule behind it is redundant — leave it out.

## 2. One Behavior per Test

- A test verifies one behavior. If its name needs "and", split it.
- Its failure reason must be the missing behavior — not a typo, a setup crash, or a missing import.
- The assertion states a business requirement. Expectations come from the requirement, never from what the code currently does.

## 3. Same Rule → One Test, Different Rules → Separate Tests

- **Cases that apply the same business rule are combined into one test**, with one case per input. Copy-pasted tests that differ only in their data are the defect this rule prevents.
- **Different rules stay in separate tests**, always. If the cases cannot be expressed as inputs to one assertion, they are not the same rule.

```java
@ParameterizedTest(name = "{0} + {1} = {2}")
@DisplayName("두 수를 더하면 합을 반환한다")
@CsvSource({"2, 3, 5", "-2, -3, -5", "0.5, 0.25, 0.75"})
void test01(double a, double b, double expected) {
    // arrange
    Calculator calculator = new Calculator();

    // act
    double result = calculator.add(a, b);

    // assert
    assertThat(result).isEqualTo(expected);
}

@Test
@DisplayName("0으로 나누면 예외가 발생한다")   // a different rule — its own test
void test02() { ... }
```

## 4. Names Carry the Domain Rule

- The **human-readable name is the domain rule sentence** from the task, in the domain's language — `@DisplayName("결제 완료된 주문은 취소할 수 없다")`, not `testCancelWhenPaid`.
- The **method name carries no meaning beyond order**: sequential (`test01`, `test02`, …), within what the runner's discovery pattern allows.
- When one class covers several logical groups (happy path vs. failures, several domain concepts), group them; each group gets the domain sentence as its display name, an English identifier, and its own sequential numbering.

```java
@Nested
@DisplayName("주문 취소")
class OrderCancellation {
    @Test @DisplayName("결제 완료된 주문은 취소할 수 없다") void test01() { ... }
    @Test @DisplayName("주문을 취소하면 재고가 복원된다") void test02() { ... }
}
```

## 5. Structure: Arrange · Act · Assert

Every test has three marked sections — `// arrange`, `// act`, `// assert` (or the language's comment form). One act per test. A setup so large it dwarfs the act is a design signal: simplify the interface, don't hide the setup.

## 6. Test Data: Use the Project's Fixtures

- Build domain objects through the project's fixture builders, never with `new` or a raw builder. Override only the fields the scenario is about; the fixture supplies safe defaults for the rest.
- Wrap repeated persistence (`repository.save(fixture.build())`) in a private helper; never duplicate fixture logic across tests.

```java
// ✅ the fixture supplies defaults; the test states only what matters
Contract contract = saveContract(aFittingContract().status(APPROVED));

// ❌ every field spelled out — the scenario is lost in the noise
Contract contract = repository.save(new Contract(1L, "name", APPROVED, ...));
```

## 7. Test Strategy per Layer

| Layer | Test type | Doubles |
|---|---|---|
| Domain | Pure unit test | **No mocks** — domain logic has no external dependencies to replace |
| Application | Unit test | Mock the repositories / ports |
| Infrastructure | Integration test | Real dependencies (e.g. Testcontainers) |
| Presentation | API test | Framework test client (e.g. MockMvc) |

Outside these, use real code and reach for a mock only when unavoidable. A test that must mock everything is a coupling signal — inject the dependency instead. Never verify mock call counts as a stand-in for behavior.

## 8. Never Delete an Existing Test

A test that existed before this session is never deleted, renamed away, or weakened without the user's explicit permission. Tests you wrote this session are yours to merge or remove while refining them — say so in your result file when you do.

## Other Stacks

| Rule | Java (JUnit 5) | Python (`unittest`) | TypeScript (jest / vitest) |
|---|---|---|---|
| Domain-sentence name | `@DisplayName("…")` | docstring as the first line of the test | `it("…")` / `test("…")` |
| Sequential method name | `test01` | `test_01` (discovery needs the `test` prefix) | the description is the name — no separate identifier |
| Same rule, many inputs | `@ParameterizedTest` + `@CsvSource` | one test looping `with self.subTest(...)` | `it.each([...])` |
| Grouping | `@Nested` class + `@DisplayName` | separate `TestCase` class per group | nested `describe("…")` |
| Section markers | `// arrange` | `# arrange` | `// arrange` |
