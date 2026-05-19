---
name: backend-development-standards
description: Analyze legacy backend systems with focus on business impact, stability, and long-term maintainability.
---

# Backend Development Standards

## AUTO-TRIGGER
Apply to ALL backend tasks: planning, coding, testing. Read BEFORE starting.

## Core Principles

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

**TDD Flow**
RED → GREEN → REFACTOR
1. Write failing test FIRST
2. Minimal code to pass
3. Refactor while green

**Pragmatic Development**
- Solve ACTUAL problem, not imaginary ones
- No "we might need..." features
- Add complexity ONLY when needed NOW
- YAGNI (You Aren't Gonna Need It)

## Planning Template

**Problem Definition**
- What problem RIGHT NOW? [state clearly]
- What's NOT included? [list out-of-scope]

**Layer Design**
```
Domain: entities, interfaces
Application: usecases, DTOs
Infrastructure: implementations
Presentation: controllers, endpoints
```

**TDD Implementation Order**
```
Per layer: Test → Code → Refactor
Order: Domain → Application → Infrastructure → Presentation
```

**Validation**
- [ ] Solves actual requirement (not future "what if")?
- [ ] Tests written first?
- [ ] Single responsibility per class?
- [ ] Dependencies point inward?
- [ ] No unnecessary abstraction?

## Anti-Patterns

**Architecture**
❌ Controller accesses DB directly
❌ Entity as API response
❌ Business logic in Controller
❌ Domain depends on Infrastructure

**Over-engineering**
❌ Abstract classes "for future flexibility" (1 impl exists)
❌ Caching "for performance" (no measured issue)
❌ Patterns "just in case"
❌ Features not requested

**TDD**
❌ Code before test
❌ Multiple behaviors in 1 test
❌ Mocking domain objects

## Test Strategy

**Per Layer:**
- Domain: Pure unit (no mocks)
- Application: Mock repositories
- Infrastructure: Integration (testcontainer)
- Presentation: API tests (MockMvc)

**Test Format:** `methodName_scenario_expected`

## Key Rules

- Test first, code second, refactor third
- Domain = pure logic, zero external deps
- Interfaces in Domain, impls in Infrastructure
- DTOs for layer boundaries
- Dependencies flow: outside → inside
- Implement ONLY what's needed NOW
- Add complexity when requirement CONFIRMED

## Mandatory Actions

1. Read this skill BEFORE any work
2. Define problem & non-goals
3. Write test FIRST
4. Design layers
5. Implement with TDD
6. Validate against checklist
