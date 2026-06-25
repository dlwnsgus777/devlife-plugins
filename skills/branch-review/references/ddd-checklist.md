# DDD Checklist — Design Quality (D)

Check these only when the diff touches domain model classes, services, or repository boundaries.

- **Ubiquitous language** — names match the domain terminology a business expert would use
- **Value objects** — domain concepts identified by value (Money, Email) must be immutable types, not raw primitives; flag primitive obsession
- **Aggregate boundaries** — external code accesses aggregates only through the root
- **Rich domain model** — invariants live inside domain objects, not services; flag anemic models where classes are pure data containers
- **Domain events** — significant state transitions are explicit events, not buried side effects
- **Repository per aggregate** — not per table; flag arbitrary query repositories
- **Domain services** — cross-aggregate logic that belongs to no single entity
