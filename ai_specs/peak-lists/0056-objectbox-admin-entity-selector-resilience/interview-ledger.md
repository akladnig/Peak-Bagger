---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: When ObjectBox Admin receives duplicate entity descriptors, should the Entity selector treat them as one entity and remain usable?

Recommended Answer:
- Show exactly one option per entity name.
- Preserve the current selection by name after refresh.
- Never crash; do not change data, navigation, or admin-action behavior.

Answer: agreed

Decision: ObjectBox Admin must canonicalize duplicate entity descriptors by entity name for the Entity selector, preserve the selected entity by name across refreshes, and avoid the DropdownButton assertion failure without changing unrelated admin behavior.

Reason: The current selector can receive duplicate dropdown values and fail during build, preventing access to the ObjectBox Admin screen.
