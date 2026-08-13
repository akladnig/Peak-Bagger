---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What does removing a listed climbed peak mean?

Recommended Answer:
- Remove the peak correlation from that one track.
- Remove it from both the track's `Peaks Climbed` list and the peak's `My Ascents` list.
- Do not delete the `Peak` or `GpxTrack` record.

Answer: agreed

Decision: A removal deletes one persisted peak correlation between a specific track and peak, and both popup surfaces must reflect it permanently during normal use.

### L2

Status: current

Question: What should an explicit rebuild of track statistics and peak correlation do to a manually removed correlation?

Recommended Answer:
- Recalculate from the stored GPX data and current correlation rules.
- Allow a previously removed peak to return when it matches those rules.

Answer: agreed

Decision: A manual removal is not a permanent exclusion; explicit peak-correlation rebuilds may restore it.

Reason: Persistent exclusions would require a separate override data model.

### L3

Status: current

Question: Should a correlation removal require confirmation?

Recommended Answer:
- Show `Remove Peak Correlation?` with `Cancel` and `Remove` actions.
- Identify both the peak and track in the message.
- On confirmation, update in place without an undo or success dialog.

Answer: agreed

Decision: Both entry points require the same confirmation contract; cancellation changes nothing and success has no undo or completion dialog.

### L4

Status: current

Question: Where should users initiate a correlation removal?

Recommended Answer:
- Add one trailing trash icon to every row in `Peaks Climbed`.
- Add one trailing trash icon to every row in `My Ascents`.
- Use tooltip `Remove peak correlation` and preserve ascent-row navigation.

Answer: agreed

Decision: Each displayed correlation row exposes a compact trailing removal control in both existing popup surfaces.

### L5

Status: current

Question: What should happen if the removal cannot be saved?

Recommended Answer:
- Keep both popups open and leave the correlation unchanged.
- Show `Failed to remove peak correlation: ...` inline in the initiating popup.
- Re-enable the trash control so the user can retry.
- Commit the source correlation and derived bagged history atomically.

Answer: agreed

Decision: A failed removal is recoverable in place and cannot leave the track correlation and `My Ascents` history inconsistent.

### L6

Status: current

Question: Which other views should update after a successful removal?

Recommended Answer:
- Immediately refresh all ascent-derived views, including peak-list counts and dashboard summaries.
- Keep the current popup open with its removed row gone.

Answer: agreed

Decision: Successful removal invalidates and refreshes all ascent-derived UI state, not only the initiating row.
