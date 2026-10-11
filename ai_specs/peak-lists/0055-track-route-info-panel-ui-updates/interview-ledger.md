---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What Track/Route information-panel UI updates are requested?

Answer: Compact the 2D/3D distance display, rename and extend the highest-elevation summary, refine elevation-profile hover and axis presentation, and provide a pointing cursor for selectable panel controls.

Decision: Deliver the specified UI changes without changing unrelated map or application controls.

### L2

Status: current

Question: Should the time to and from the highest elevation be elapsed GPX timestamp time or moving time?

Recommended Answer:
- Calculate elapsed time from the track start to the highest-elevation profile sample and from that sample to the track end.
- Include pauses.
- Display `distance / HH:MM` when timestamps and the position are available; otherwise retain distance alone.

Answer: agreed

Decision: Use elapsed recorded GPX time, including pauses, with a distance-only fallback.

### L3

Status: current

Question: Which controls should show a pointing-hand cursor?

Recommended Answer:
- Apply it to every enabled pointer-selectable control in the Track/Route information panels and elevation profile.
- Cover the profile interaction area, Distance and Time selectors, Export, Recalculate Track Statistics, edit/close controls, peak-correlation removal, and the visibility switch.
- Leave disabled controls and controls outside these surfaces unchanged.

Answer: agreed

Decision: Apply the pointing cursor to all enabled interactive controls within the stated Track/Route surfaces only.

### L4

Status: superseded

Question: What should replace the elevation profile's bottom-axis `m` marker?

Recommended Answer:
- Display the unrounded minimum recorded elevation as a numeric tick without a unit, such as `1022`.
- Retain a rounded chart range for readable grid spacing.

Answer: agreed

Decision: Superseded by `spec.md` Requirement 5: the y-axis base label is the existing rounded chart-range minimum, rendered as a numeric tick without a unit suffix.

### L5

Status: current

Question: How should timestamp data appear in the elevation hover popup?

Recommended Answer:
- Retain the x-axis value and elevation.
- Add the recorded local clock time, then an `HH:MM elapsed` line underneath.
- Omit both lines when timestamps are unavailable, independent of the active axis mode.

Answer: agreed

Decision: Timestamped profile samples show local time and elapsed time from the first timestamped sample; untimed profiles show neither time line.

### L6

Status: current

Question: Do the existing highest-peak fields target a correlated Peak or the track's maximum elevation point?

Recommended Answer:
- Preserve the current maximum-elevation calculation.
- Rename the fields `To highest elevation` and `From highest elevation` rather than implying a correlated Peak.

Answer: agreed

Decision: Preserve the maximum-recorded-elevation calculation and use `Track highest elevation` terminology.

Reason: The current values do not use a correlated `Peak`; the revised labels must accurately describe their source.
