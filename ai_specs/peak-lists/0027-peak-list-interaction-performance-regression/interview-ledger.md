---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which exact app-owned surfaces should this regression cover?

Recommended Answer:
- Treat this as one `peak-list interaction performance` bug covering:
  - `Map` zoom and pan responsiveness.
  - `Map` `Peak Lists` drawer selection taps, including `All Peaks` and individual list rows.
  - `My Peak Lists` app-bar `Region FAB` taps.
- Keep `Peak list mini-map`, import/export, and peak edit dialogs out of scope unless they prove to be the same regression.

Answer: agreed. The mini-map is responsive, so maybe it was fixed to correctly use the new peak list schema.

Decision: Scope this work to `Map` zoom and pan, `Map` `Peak Lists` drawer selection taps, and `My Peak Lists` `Region FAB` taps, with `Peak list mini-map` explicitly out of scope.

### L2

Status: current

Question: Should this stay a pure responsiveness regression fix or also change user-visible selection or loading behavior?

Recommended Answer:
- Keep this a pure responsiveness regression fix.
- Preserve existing labels, selection rules, and region or list visibility behavior.
- Do not add new loading UI, disabled states, or interaction redesign unless required to avoid incorrect state.

Answer: agreed

Decision: This slice preserves existing user-visible behavior and fixes responsiveness only.

Negative Requirements:
- No intentional UI redesign.
- No new loading copy or disabled-state contract unless correctness requires it.

### L3

Status: current

Question: Can expensive peak-list-derived recomputation finish just after the tap or gesture if visible selection state changes immediately and the final result stays correct?

Recommended Answer:
- Yes.
- Immediate interaction path should update selection or gesture state first.
- Heavier peak-list-derived recomputation may complete asynchronously right after, provided:
  - the final selected lists and rendered peaks end up correct,
  - there is no incorrect intermediate selection shown,
  - there is no new spinner or loading copy unless implementation proves it necessary.

Answer: agreed

Decision: Hot interaction paths may defer expensive peak-list-derived recomputation as long as visible state changes immediately and the final rendered result stays correct.

### L4

Status: current

Question: During `Map` zoom and pan, may peak-list-dependent peak rendering update only after motion settles if that restores smooth interaction?

Recommended Answer:
- Yes.
- Keep basemap and camera motion smooth during continuous zoom and pan.
- Peak-list-dependent peak rendering may be throttled or refreshed at gesture end.
- Do not show wrong peaks for a different completed selection state; brief in-motion lag is acceptable, but the settled map must be correct.

Answer: agreed

Decision: Continuous `Map` motion may prioritize smooth camera interaction and allow peak-list-dependent peak rendering to lag until motion settles, provided the settled map is correct.

### L5

Status: current

Question: What dataset should define whether this regression is fixed?

Recommended Answer:
- Treat it as fixed only when verified against the existing real migrated local data that shows the slowdown now, not just small test fixtures.
- Preserve current data and selection-state semantics.
- Automated tests should still use deterministic fixtures, but final verification should use the real post-`0024` migrated peak-list data shape.

Answer: agreed

Decision: Automated tests may use deterministic fixtures, but final verification must use real migrated local post-`0024` data that reproduces the slowdown.

### L6

Status: current

Question: What responsiveness target should define success on the normal development machine?

Recommended Answer:
- `Map` `Peak Lists` drawer taps and `My Peak Lists` `Region FAB` taps should show the new selection state within about 100 ms and feel effectively immediate.
- Continuous `Map` pan and zoom should stay visually smooth, without multi-second stalls or obvious stepwise blocking.
- After motion stops, any deferred peak-list-dependent peak refresh should settle to the correct final result within about 250 ms.
- Treat these as local responsiveness targets rather than hard real-time guarantees across every device.

Answer: agreed

Decision: Success is defined by near-immediate tap feedback, smooth continuous map motion, and correct deferred settle behavior within about 250 ms on the normal development machine.

### L7

Status: current

Question: If the user taps multiple `Peak Lists` drawer rows or `Region FAB`s quickly while a deferred refresh is still finishing, what should happen?

Recommended Answer:
- Use `latest interaction wins`.
- Keep controls responsive and do not lock the drawer or `Region FAB`s during deferred recomputation.
- Skip or supersede stale in-flight recomputation so only the newest selection state is allowed to settle on screen.
- Final rendered peaks and selection chips must match the most recent user action.

Answer: agreed

Decision: Concurrent rapid selection changes follow a `latest interaction wins` rule and stale recomputation must be superseded.

### L8

Status: current

Question: What regression-proof coverage should this bug fix require?

Recommended Answer:
- Add automated coverage for the changed contract:
  - a widget-level regression test proving `Map` zoom and pan no longer force peak-list-dependent recomputation on every camera tick, or otherwise proving the hot path stays decoupled,
  - a widget or provider regression test proving rapid `Peak Lists` drawer selection and `Region FAB` taps use `latest interaction wins`.
- Keep real migrated local data as the final manual verification step.
- Do not require a fragile time-based performance test with wall-clock assertions.

Answer: agreed

Decision: The fix must add deterministic regression coverage for hot-path decoupling and `latest interaction wins`, while avoiding fragile wall-clock performance tests.

### L9

Status: current

Question: Which currently observed hot paths should this Spec treat as the confirmed regression source?

Answer: The confirmed regression source is the remaining peak-list-derived work still coupled to main-map interaction, not the older camera feedback or per-frame persistence bugs.

Decision: This Spec should target two confirmed hot paths: per-frame main-map peak projection or viewport work during continuous motion, and settled visible-bounds peak-list reconciliation that still performs expensive membership-derived work on the UI isolate.

Reason: The earlier `pan-zoom-optmize1` and `pan-zoom-optmize2` fixes are still in place, the `Peak list mini-map` remains responsive, and the current slowdown tracks the main map's peak-list-derived rendering and selection refresh path instead.

Constraints:
- Do not treat this regression as justification to restore rebuild-time camera sync or per-frame camera persistence.
- Keep `Peak list mini-map` out of scope unless implementation proves it shares the same blocking path.
