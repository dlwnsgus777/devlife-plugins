# Tidy First Scan

How the lead finds tidy candidates when the requirements document names none. Run it during the Setup exploration, only on code the requested change will modify. A brand-new feature with no existing code to change has no candidates.

Ask one question of that code: **what in its current structure makes this requirement hard to add?** A tidy item exists only to make this change easy; a smell the change does not run into is left alone.

## 1. Landing Spot

For each place the change must touch, ask where the new requirement goes and what in the current structure makes adding it there hard:

| Blocker | Looks like | Example | Typical restructuring |
|---|---|---|---|
| Scattered edits | the same new rule would have to be added in several classes or methods | an order-amount cap must go into both `create()` and `update()` | Extract Method / Move Method so the rule has one home |
| No seam | responsibilities are tangled, so there is no method or class where the new behavior could be added on its own | discount math sits inside `checkout()` next to payment and stock updates, with no place for a new discount rule | Extract Method / Extract Class to create the seam |
| Repeated branch | the same conditional appears in several spots, and the change adds a branch to each | `if (grade == VIP)` appears in price, shipping and points, and a new `GOLD` grade needs a branch in each | Consolidate the conditional into one place |
| Overloaded signature | the change needs one more value threaded through many parameters | adding a delivery time slot means one more parameter on four methods | Introduce Parameter Object |

Each blocker is one candidate.

## 2. Abstraction (strict)

Propose extracting an abstraction only when all three hold:

1. **This requirement itself adds a case** to an axis the code branches on (a type, channel, or policy switch);
2. that axis then has **two or more concrete cases**, counting the new one;
3. the domain says the axis **keeps growing** — the document says so, or the user confirms it at Setup 5.

A single case, or a structural smell with no domain reason, is no proposal — an interface with one implementation is an anti-pattern. The abstraction is extracted from the existing cases; the new case is a task.

E.g. the requirement adds KakaoPay, and payment methods keep growing. Before:
```java
int fee(PaymentType type, int amount) {
    if (type == CARD) return amount * 3 / 100;
    if (type == BANK) return 500;
    throw new IllegalArgumentException();
}
```
The tidy item extracts the interface from the existing cases only:
```java
interface PaymentMethod { int fee(int amount); }
class CardPayment implements PaymentMethod { public int fee(int amount) { return amount * 3 / 100; } }
class BankPayment implements PaymentMethod { public int fee(int amount) { return 500; } }
// No KakaoPayment here — that is the task's work.
```

## 3. Writing a Candidate

For each candidate, record:

- **Blocker** — what in the current code makes the change hard to add (file and method).
- **Restructuring** — the named technique.
- **Landing spot** — where the change goes once the blocker is removed.

No blocker found → no candidates. Never invent one to have something to show.
