---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What vertical criterion should be added to peak correlation?

Recommended Answer:
- Compare the stored peak elevation to GPX elevation at the closest point on the track segment.
- Require the absolute difference to be within a 10 m default vertical threshold as well as the horizontal threshold.

Answer: agreed

Decision: Peak correlation must require both horizontal proximity and a peak-to-track elevation difference within the elevation threshold, which defaults to 10 m.

### L2

Status: current

Question: Should the feature use elevation or height as its canonical term?

Recommended Answer:
- Use elevation, measured in metres above sea level.
- Label the setting `Peak elevation threshold`.

Answer: agreed

Decision: Use elevation as the canonical term and label the new setting `Elevation threshold` within Peak Correlation.

### L3

Status: current

Question: What should happen when either the peak or closest track position lacks elevation data?

Recommended Answer:
- Do not correlate the peak.
- Do not fall back to horizontal-only matching.

Answer: agreed

Decision: A peak lacking stored elevation, or whose closest track position cannot provide elevation, is not correlated.

### L4

Status: current

Question: Should the elevation threshold be a persistent setting and what values should it support?

Recommended Answer:
- Add `Elevation threshold` beside `Distance threshold` in Peak Correlation.
- Persist an independent choice from 10 m through 100 m in 10 m increments, defaulting to 10 m.

Answer: agreed

Decision: Persist an independent elevation threshold with values 10, 20, ..., 100 m and default it to 10 m.

### L5

Status: current

Question: When should a changed correlation threshold update existing tracks?

Recommended Answer:
- Save the setting immediately.
- Apply it to new and explicitly rebuilt tracks only; do not automatically rebuild existing tracks.

Answer: agreed

Decision: Threshold changes do not recalculate persisted peak correlations until a track is explicitly recalculated or a new track is processed.

### L6

Status: current

Question: How should track elevation be calculated between two GPX samples?

Recommended Answer:
- Linearly interpolate the endpoint elevations at the horizontally closest point on the segment.
- Treat a missing or invalid endpoint elevation as unavailable.

Answer: agreed

Decision: Track elevation is linearly interpolated at any position within each finite segment; both segment endpoint elevations are required. A peak correlates when any position meets both thresholds.

### L7

Status: current

Question: How should a user test revised correlation for one track?

Answer: Add a filled `Recalculate Track Statistics` button above the `Hide this track on the map` switch. It must run the Settings-screen recalculation for the selected track only.

Decision: The selected track's info panel provides the individual recalculation entry point, which rebuilds its statistics and peak correlation from stored GPX XML using current correlation settings.

### L8

Status: current

Question: Should single-track recalculation require confirmation?

Recommended Answer:
- Show `Recalculate Track Statistics?`.
- Use `This will rebuild statistics and peak correlation for this track from stored GPX XML. Do you wish to proceed?`.
- Provide `Cancel` and `Recalculate` actions.

Answer: agreed

Decision: Individual recalculation requires confirmation; cancellation leaves the selected track unchanged.

### L9

Status: current

Question: How should individual recalculation present loading, success, failure, and concurrent-action states?

Recommended Answer:
- Disable the button and show `Recalculating...` with inline progress while it runs.
- Prevent global and other individual track recalculations until it finishes.
- Keep the panel open, refresh its data on success, and show `Track Statistics Recalculated` with `Track statistics and peak correlation were refreshed.`.
- On failure, retain prior saved data, re-enable the button, and show `Track Statistics Recalculation Failed` with the error.

Answer: agreed

Decision: The action must expose deterministic busy, success, and failure states while preserving the prior persisted track on failure.
