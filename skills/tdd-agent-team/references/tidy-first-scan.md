# Tidy First Scan

How the lead finds tidy candidates when the requirements document names none. Run it during the Setup exploration, only on code the requested change will modify. A brand-new feature with no existing code to change has no candidates.

The question is never "is this code clean?" — it is **"can this requirement land in one place?"** A tidy item exists to make *this* change easy, not to improve the codebase.

## 1. Landing Spot

For each place the change must touch, ask where the new requirement has to go and what in the current structure stops it from going there in one piece:

| Blocker | Looks like | Typical restructuring |
|---|---|---|
| Scattered edits | the same new rule would have to be added in several classes or methods | Extract Method / Move Method so the rule has one home |
| No seam | responsibilities are tangled, so there is no method or class where the new behavior could be added on its own | Extract Method / Extract Class to create the seam |
| Repeated branch | the same conditional appears in several spots, and the change adds a branch to each | Consolidate the conditional into one place |
| Overloaded signature | the change needs one more value threaded through many parameters | Introduce Parameter Object |

Each blocker is one candidate. **A smell the requirement never touches is not a candidate**, however bad it is.

## 2. Abstraction (strict)

Propose extracting an abstraction only when all three hold:

1. **This requirement itself adds a case** to an axis the code branches on (a type, channel, or policy switch);
2. that axis then has **two or more concrete cases**, counting the new one;
3. the domain says the axis **keeps growing** — the document says so, or the user confirms it at Setup 5.

A single case, or a structural smell with no domain reason, is no proposal — an interface with one implementation is an anti-pattern. The abstraction is extracted from the existing cases; the new case is a task.

## 3. Writing a Candidate

For each candidate, record:

- **Blocker** — what in the current code stops the change from landing in one place (file and method).
- **Restructuring** — the named technique.
- **Landing spot** — where the change goes once the blocker is removed.

No blocker found → no candidates. Never invent one to have something to show.
