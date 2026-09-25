---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should the request's `NaturalFeatures` terminology replace the existing Natural Feature terminology?

Recommended Answer:
- Use `Natural Feature` as the canonical term.
- Search the existing singular `NaturalFeature` ObjectBox/Dart entity.
- Use `natural features` only for the collection.

Answer: yes

Decision: The Natural filter searches `NaturalFeature` records; `Natural Feature` remains the canonical singular project term.

### L2

Status: current

Question: How should the Search popup's entity filters behave when categories can be independently enabled?

Recommended Answer:
- Remove the All button.
- Combine results from every enabled category.
- Show no results when every category is disabled.

Answer: agreed

Decision: Peaks, Tracks/Routes, Natural, Roads, and Maps are independent toggle filters. The active filters produce one union result set, and no active filters produce no results.

### L3

Status: current

Question: When should the Search popup reset its filter selection?

Recommended Answer:
- Reset on every Search popup open.
- Enable Peaks, Tracks/Routes, and Natural.
- Disable Roads and Maps.
- Do not persist the selection across popup closes or app restarts.

Answer: agreed

Decision: Every Search popup opening starts with Peaks, Tracks/Routes, and Natural enabled; Roads and Maps disabled; and no persisted category selection.

### L4

Status: current

Question: What should selecting a Natural search result do on the map?

Recommended Answer:
- Close Search and center the map on the Natural Feature at the normal map zoom.
- Do not add a detail popup or selection state.

Answer: agreed

Decision: Natural-result selection follows the existing Natural Feature map-navigation behavior without creating a new details surface or persistent selection.

### L5

Status: current

Question: Which Natural Feature fields should match a Search popup query?

Recommended Answer:
- Match `name` and non-empty `altName` case-insensitively with substring semantics.
- Exclude OSM identity, tag, administrative, coordinate, and source-of-truth fields.

Answer: agreed

Decision: Natural search matches only `NaturalFeature.name` and non-empty `NaturalFeature.altName`.

### L6

Status: current

Question: What should a Natural Feature search result display below its title?

Recommended Answer:
- Use the normalized Natural Feature `tag` and resolved map region.
- Display them as `Tag · Region`.
- Keep an alternate name out of the row unless it is the matched query.

Answer: agreed

Decision: A Natural result shows its primary name as the title and its natural type plus resolved map region as the subtitle. When the alternate name is the matching value, include that alternate name in the row without replacing the primary title.

### L7

Status: current

Question: How should an active Track date filter interact with categories that do not have a Track date?

Recommended Answer:
- Return only Track-date-matching Tracks and their associated Peaks.
- Preserve enabled category toggles while suppressing Natural, Roads, and Maps until the date filter is cleared.

Answer: agreed

Decision: A Track date range retains existing date-qualified Peak and Track behavior and suppresses Natural, Roads, and Maps without changing their selected state.
