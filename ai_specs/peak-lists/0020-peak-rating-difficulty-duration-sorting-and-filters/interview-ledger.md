---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which canonical term should this feature use for the peak difficulty field, given the existing glossary term `Hiking difficulty` for track segments?

Recommended Answer:
- Use `Peak difficulty` as the canonical term.
- Treat it as a region-specific grade stored on `Peak`.
- Keep the visible UI label as `Difficulty`.
- Do not normalize peak difficulty into the existing track-segment `Hiking difficulty` concept.

Answer: agreed

Decision: The feature uses `Peak difficulty` as the canonical peak-specific term, separate from `Hiking difficulty`.

### L2

Status: current

Question: What should the new duration field represent, and how should mixed input formats behave?

Recommended Answer:
- Store `Peak.durationMinutes` as the numeric sort/filter source of truth.
- Store `Peak.durationLabel` as the human-readable source label.
- Treat the value as an estimated standard out-and-back walking duration for the peak.
- Parse exact formats such as `0:30` and `4:15` directly.
- Parse ranges such as `4-5 hours` and `2-3 days` using the upper bound for `durationMinutes`.
- Show `durationLabel` in the UI when present, otherwise show a formatted duration.

Answer: The minimum duration will be 15 mins and max around 20 days. Some durations may be described as "2-3 days" or "4-5 hours" as well as "0:30" or "4:15". agreed

Decision: `Peak duration` is an estimated standard out-and-back walking duration stored as both numeric minutes and a human-readable label, with exact and range formats supported.

Constraints:
- Support at least 15 minutes through about 20 days.
- Use the upper bound of a range as the numeric sort/filter value.

### L3

Status: current

Question: How should `Peak difficulty` sort and filter when peaks from different regions use different grading systems?

Recommended Answer:
- Treat `Peak difficulty` as a region-specific exact-match filter.
- Show only difficulty options that exist in the current scope.
- Group mixed-region map difficulty options by region.
- Use an app-owned per-region difficulty order where available, with alphabetical fallback where no ladder exists.
- In mixed-region sorting, order by region first, then that region's difficulty order, then peak name.
- Do not invent a global cross-region difficulty scale.

Answer: agreed

Decision: `Peak difficulty` stays region-specific for both sorting and filtering, with grouped mixed-region filter options and per-region sort order plus alphabetical fallback.

Negative Requirements:
- Do not normalize all regions into one global difficulty scale.

### L4

Status: current

Question: Should `My Peak Lists` get filtering controls too, or sort-only behavior in this iteration?

Recommended Answer:
- `My Peak Lists` is sort-only for this iteration.
- Add visible columns in this order: `Rating`, `Peak Name`, `Height`, `Ascent Date`, `Ascents`, `Difficulty`, `Duration`.
- Allow `Rating`, `Difficulty`, and `Duration` to sort alongside the existing columns.
- Keep map support filter-only for these fields.

Answer: agreed

Decision: `My Peak Lists` is sort-only in this iteration and adds sortable `Rating`, `Difficulty`, and `Duration` columns in the agreed column order.

### L5

Status: current

Question: What exact `Peak duration` filter options and matching rules should the map use?

Recommended Answer:
- Options: `Any`, `4h`, `8h`, `12h`, `2d`, `5d`, `10d`, `2d+`.
- `4h`, `8h`, `12h`, `2d`, `5d`, and `10d` match peaks where `durationMinutes <= threshold`.
- `2d+` matches peaks where `durationMinutes >= 2880`.
- Missing durations are excluded whenever a non-`Any` option is active.

Answer: agreed

Decision: The map `Peak duration` filter uses the exact option set `Any`, `4h`, `8h`, `12h`, `2d`, `5d`, `10d`, and `2d+`, with mixed `<=` and `>=` matching rules.

Answer History:
- Initial recommendation: generic upper-bound options ending at `20d`.
- Revised answer: use `Any`, `4h`, `8h`, `12h`, `2d`, `5d`, `10d`, and a specific `2d+` option.

### L6

Status: current

Question: How should `Rating` be shown to users, and what exact filter contract should the map use?

Recommended Answer:
- Show `Rating` with 5 stars using full, half, and empty states.
- Keep the stored value as the existing numeric 0-5 rating.
- Use `Any` plus threshold options for `3.0`, `3.5`, `4.0`, and `4.5`.
- Apply map filtering when `peak.rating >= selectedThreshold`.
- Show blank when the rating is missing, and exclude missing ratings when a non-`Any` filter is active.
- Accessibility should announce values like `4.5 out of 5 stars`.

Answer: agreed

Decision: `Rating` is rendered as stars for users, while numeric 0-5 values remain the source of truth for sorting and filtering, with map threshold options at 3.0, 3.5, 4.0, and 4.5.

Answer History:
- Initial open question: decimal text versus stars.
- Final answer: stars for the user-facing UI, numeric thresholds for behavior.

Negative Requirements:
- Do not show both stars and decimal text in the `My Peak Lists` rating cell in this iteration.

### L7

Status: current

Question: Where should `Peak duration` be editable and importable in this iteration?

Recommended Answer:
- Add editable duration support to the ObjectBox Admin peak editor using the human-readable duration label.
- Add an optional `duration` column to ranked peak-list CSV import.
- Parse imported duration text into both stored duration fields.
- Leave existing peaks without duration valid and blank until populated.
- Fail invalid imported duration values with clear row-level errors, like rating.
- Do not auto-infer duration from tracks, routes, or external services.

Answer: agreed

Decision: `Peak duration` is maintained through the ObjectBox Admin peak editor and ranked peak-list CSV import, with parse validation and no automatic derivation.

### L8

Status: current

Question: How should map filter entry, panel behavior, and session persistence work?

Recommended Answer:
- Use one visible `Filter` control instead of three always-visible FABs.
- Apply changes immediately when an option is selected.
- Close on outside tap, Escape, Back, or equivalent dismiss actions while keeping current selections.
- Include `Clear filters`, which resets all filters to `Any` and keeps the panel open.
- Keep filters applied while changing peak lists or visible regions.
- Preserve the current map filter selection when leaving and returning to `Map` in the same app session.
- Do not silently clear filters when the current visible peaks stop offering a previously selected value.

Answer: agreed. Use a standard filter icon followed by the label Filter

Decision: The map uses one visible `Filter` control with immediate-apply behavior, `Clear filters`, and same-session persistence across map list/region changes and route revisits.

Negative Requirements:
- Do not add three always-visible filter FABs.
- Do not silently clear active filters when the visible or selected peak set changes.

### L9

Status: current

Question: How should the map `Difficulty` filter work when multiple regional grading systems are visible at once?

Recommended Answer:
- Keep the control single-select overall.
- Group difficulty options by region.
- Selecting an option means matching one exact `(region, difficulty)` pair.
- Show region context in the selected value when needed, such as `T4 (Slovenia)`.
- Use `Any` to clear the difficulty filter.

Answer: agreed

Decision: The map `Difficulty` filter is a single-select control whose mixed-region options are grouped by region and match one exact `(region, difficulty)` pair at a time.

### L10

Status: current

Question: How much of the provided filter popup mockup should this feature copy?

Recommended Answer:
- Use the mockup as a styling reference only.
- Render exactly three fixed filter containers: `Rating`, `Difficulty`, and `Duration`.
- Use dark rounded row containers with a trailing dropdown styled like the mockup's rightmost control.
- Keep `Clear filters`.
- Keep out of scope: `Saved filters`, `AND`, `Add filter`, nested filters, per-row delete icons, and dynamic add/remove rows.

Answer: agreed

Decision: The map filter popup follows the mockup's visual language for three fixed rows and trailing dropdowns, without adopting its saved-filter or dynamic-builder features.

Source: `/Users/adrian/Desktop/filter.png`

### L11

Status: current

Question: What exact active-count label and styling should the map `Filter` control use?

Recommended Answer:
- Show `Filter` with unselected styling when no filters are active.
- Show `1 Filter`, `2 Filters`, or `3 Filters` with selected styling when that many non-`Any` filters are active.
- Count `Rating`, `Difficulty`, and `Duration` independently when their value is not `Any`.

Answer: show it as 1 Filter, 2 Filters, 3 Filters with selected styling. and just Filter and unselected styling for no active filters

Decision: The map `Filter` control shows `Filter` in its unselected state when no filters are active, and otherwise shows `1 Filter`, `2 Filters`, or `3 Filters` in its selected state.
