# Project Rules & AI Agent Guidelines

## 1. Base Principles

* **Unknown info**: State "I don't know" or "not available."
* **Missing context**: Ask before generating code or answers.
* **Convention alignment**: Match existing naming, structure, and formatting; refer to other project files.
* **Data integrity**: When implementing from provided data, verify nothing is missing before coding.

## 2. Code Structuring

* **Class method order**: Public → Private

## 3. Test Case Rules

* Eliminate redundant test cases unrelated to business rules.
* Combine test cases that apply the same business rule.
* List all scenarios for expected behavior.
* **Never run tests after writing them** (no Gradle execution).

## 4. TDD Rules

* **No Test Deletion**: Never delete tests without explicit permission.
* **AAA Pattern**: Add comments in test methods — `// arrange` / `// act` / `// assert`

## 5. Feedback Rules

* Request feedback after each stage (implementation, testing, design).
* Only proceed when explicitly instructed.
* Format: **"Could you provide feedback on this [implementation/test/design]? I'd especially appreciate input on [area of focus]."**

## 6. Code Quality

- Clear variable and function names; self-documenting over comments
- Simplest solution (KISS); extract common logic (DRY); add complexity only when required (YAGNI)

## 7. Backend Standards

**SOLID**
- SRP: 1 class = 1 responsibility
- OCP: Interface for extension
- LSP: Subtypes replaceable
- ISP: Small, specific interfaces
- DIP: Depend on abstractions

**Clean Architecture** (dependency: outside → inside)
1. Domain (core, no external deps)
2. Application (uses Domain only)
3. Infrastructure (implements Domain interfaces)
4. Presentation (uses Application)

**Anti-Patterns**
- Controller accesses DB directly
- Entity used as API response
- Business logic in Controller
- Domain depends on Infrastructure
- Abstract classes with only 1 implementation
- Features not requested / patterns "just in case"

**Test Strategy per Layer**
- Domain: Pure unit (no mocks)
- Application: Mock repositories
- Infrastructure: Integration (Testcontainer)
- Presentation: API tests (MockMvc)

## 8. Planning Rule

- Before starting any **action-oriented request** (code implementation, file creation, feature modification), always ask: "계획을 `/plan-creator`로 먼저 작성할까요?"
- Skip for simple questions, code explanations, or read-only requests.
- Skip if the user explicitly says "바로 해줘" or "계획 없이".

## Checkpoints (every 30 min or after key feature)

- Completed / current / next test
- Key class/method structure, test coverage, known issues
- Can return to last working state? Goals achieved? Remaining work?

# Summary instructions

When you are using compact, please focus on test output and code changes
