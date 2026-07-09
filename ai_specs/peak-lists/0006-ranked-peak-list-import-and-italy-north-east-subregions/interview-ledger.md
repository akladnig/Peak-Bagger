---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should the new generated region peak-list files be imported through the existing peak-list flow or as a separate dataset concept?

Recommended Answer:
- Keep the existing HWC-style peak-list import behavior.
- Add a second header-detected format for generated region ranking files.
- Match ranked rows against existing peaks by `osmId`.
- Never create a new `Peak` from a ranked row.

Answer: Do not create a new peak. match against the osmId in the peak lists. Also, I forgot, determine the required import format from the header, keep the existing import format and add a new format

Decision: Add a header-detected `ranked peak list CSV` import path alongside the existing HWC peak-list importer; ranked rows match existing peaks by `osmId` only and never create peaks.

Negative Requirements:
- Do not replace the existing HWC importer.
- Do not add a separate dataset-sync entity or workflow for ranked files.

### L2

Status: current

Question: What canonical term should describe the new generated ranking CSV format?

Recommended Answer:
- Call it `ranked peak list CSV`.
- Use it for header-detected imports produced by ranking tools such as `tool/rank_fvg_peaks.dart`.
- Avoid `FVG format` as the canonical term because the same format will be used for other regions.

Answer: Agreed

Decision: The canonical term is `ranked peak list CSV`.

Reason: The format is reusable across regions and should not be named after the first region that uses it.

### L3

Status: current

Question: Which additional ranked CSV fields should become first-class `Peak` fields, and how should rating be stored?

Recommended Answer:
- Add `rating` as a single-decimal `double?` constrained to `0.0` through `5.0`.
- Add `difficulty` as `String` with default `''`.
- Add `viaFerrata` as `String` with default `''`.
- Add `notes` as `String` with default `''`.
- Keep raw imported `viaFerrata` labels such as `No`, `Yes`, and `Optional` rather than collapsing them to a boolean.

Answer: add rating as single decimal place double, with a range of 0.0 to 5.0 ... agreed

Decision: Extend `Peak` with `rating`, `difficulty`, `viaFerrata`, and `notes`, preserving raw ranked CSV labels and enforcing single-decimal `rating` storage in the `0.0` to `5.0` range.

### L4

Status: current

Question: What should ranked imports store for `PeakListItem.points`?

Recommended Answer:
- Store the same fixed points value for every ranked-imported item.
- Do not derive points from rating, ordering, or file name.

Answer: actually - back to points - set it 1 not 0.

Decision: Every `PeakListItem` imported from a ranked peak list CSV must use `points: 1`.

Answer History:
- Initial answer: use `points: 0`.
- Final answer: use `points: 1`.

Negative Requirements:
- Do not derive `points` from `rating`.
- Do not derive `points` from file order or list identity.

### L5

Status: current

Question: How should ranked imports update stored peak fields when the CSV value is blank?

Recommended Answer:
- Non-blank ranked CSV values overwrite the corresponding `Peak` field.
- Blank ranked CSV values do not clear an existing stored value.
- Ranked import must remain atomic when validation fails.

Answer: agreed for question 9

Decision: Ranked CSV blanks mean "no update" for mapped peak fields; they do not clear existing values, and validation failures must remain atomic.

Examples:
- Blank `prominence` keeps the existing `Peak.prominence`.
- Blank `notes` keeps the existing `Peak.notes`.

### L6

Status: current

Question: What should happen when a ranked CSV contains missing, unknown, or duplicate `osmId` values?

Recommended Answer:
- Fail the entire import.
- Do not save or update the target `PeakList`.
- Do not update any `Peak` rows.
- Use row-specific failure messages for missing, unknown, and duplicate `osmId` problems.

Answer: agreed

Decision: Ranked imports must fail atomically on missing `osmId`, unknown `osmId`, or duplicate `osmId` rows.

Constraints:
- Missing `osmId` error shape: `row N is missing osmId (Peak Name)`.
- Unknown `osmId` error shape: `row N references unknown osmId 123456789 (Peak Name)`.
- Duplicate `osmId` error shape: `duplicate osmId 123456789 on row N`.

Reason: Ranked files are tool-generated invariants, so these conditions signal a data-integrity problem rather than a row-level skip.

### L7

Status: current

Question: Should ranked imports use a fixed list name from the file or the typed dialog name?

Recommended Answer:
- Use the dialog-entered list name.
- Do not derive the list name from the file name because the same format will be used for multiple regions and list variants.

Answer: I should clarify that additional non fvg lists will be created for Slovenia and Veneto etc., so I was wrong saying the list name should be fixed. It really needs to be entered via the dialog

Decision: Ranked imports must use the user-entered peak-list name from the existing import dialog.

Answer History:
- Initial answer: use fixed canonical names derived from the FVG files.
- Final answer: use the existing dialog-entered list name because the format will be reused across regions.

Negative Requirements:
- Do not force ranked list names from file names.

### L8

Status: current

Question: How should ranked imports determine and store `Peak.sourceOfTruth`, and what regional validation rules apply?

Recommended Answer:
- Determine the label from the ranked CSV `region` column, not from the typed list name or file name.
- Supported mappings for this change:
  - `Friuli Venezia Giulia` -> `FVG`
  - `Veneto` -> `VENETO`
- Every imported row in one file must resolve to the same supported ranked-import region.
- Unknown or mixed ranked-import regions fail the entire import.
- Leave Slovenia unresolved for now.

Answer: agreed

Decision: Ranked imports determine `Peak.sourceOfTruth` from the CSV `region` column using `Friuli Venezia Giulia` -> `FVG` and `Veneto` -> `VENETO`; unsupported or mixed ranked-import regions fail the entire import.

Constraints:
- Unsupported region error shape: `unsupported region "Slovenia" on row N`.
- Mixed-region error shape: `mixed ranked-import regions in one file`.

### L9

Status: current

Question: How strict should ranked CSV header detection be?

Recommended Answer:
- Detect ranked CSV only when the header row contains this exact case-sensitive set of columns:
  - `name`, `osmId`, `rating`, `elevation`, `prominence`, `latitude`, `longitude`, `country`, `region`, `range`, `county`, `difficulty`, `viaFerrata`, `notes`
- If the file matches neither known format, fail the import.

Answer: agreed

Decision: Ranked peak list CSV detection is exact and case-sensitive against the full generated header set.

### L10

Status: current

Question: After a ranked import sets `sourceOfTruth` to a region label, should those peaks remain protected from future OSM refreshes under the app's current non-`OSM` rule?

Recommended Answer:
- Yes.
- Once `sourceOfTruth` becomes `FVG` or `VENETO`, the peak is no longer refresh-eligible from OSM under the current app behavior.

Answer: agreed

Decision: Peaks updated by ranked imports become non-`OSM` protected once `sourceOfTruth` is `FVG` or `VENETO`.

### L11

Status: current

Question: How should the importer handle ranked CSV `rating` values that contain more than one decimal place, such as `4.33`?

Recommended Answer:
- Accept the row.
- Round to one decimal place before saving.
- Reject the import only when a non-blank rating is non-numeric or outside `0.0` through `5.0`.

Answer: agreed

Decision: Ranked import rounds valid ratings to one decimal place before saving and rejects non-blank non-numeric or out-of-range ratings.

Examples:
- `4.33` -> `4.3`
- `4.35` -> `4.4`

### L12

Status: current

Question: Should this spec introduce separate stored/search subregions under `italy-nord-est` rather than keeping every northeast region under one key?

Recommended Answer:
- Yes.
- Introduce these canonical Italy North East subregion keys:
  - `fvg`
  - `veneto`
  - `trentino-alto-adige`
  - `emilia-romagna`
- Treat them as stored/search subregions under the broader `italy-nord-est` umbrella, not as full top-level manifest regions in this spec.

Answer: OK that sounds good, so these two other regions will need to be added to italy-nord-est: Trentino Alto Adige & Emilia Romagna ... agreed

Decision: Add `fvg`, `veneto`, `trentino-alto-adige`, and `emilia-romagna` as Italy North East subregion keys for stored peak/list data and Search popup filtering, without requiring new top-level manifest regions in this spec.

### L13

Status: current

Question: How should the new subregions interact with existing northeast data and non-peak search entities?

Recommended Answer:
- Do not back-classify existing `italy-nord-est` peaks in this spec.
- Apply the new subregion filters only to peaks and lists explicitly stored with those subregion keys.
- Tracks, routes, and maps remain on the broader existing region model.
- In `All` search mode, a selected subregion narrows peak results only; non-peak entities remain governed by the broader model.

Answer: agreed

Decision: New northeast subregion filters apply only to explicitly stored peak/list subregion keys in this spec; existing `italy-nord-est` data is not back-classified, and non-peak search entities stay on the broader region model.

### L14

Status: current

Question: How should the Search popup expose the new northeast subregions to users?

Recommended Answer:
- Keep the existing single `Filter` menu.
- Add these exact user-facing options:
  - `FVG`
  - `Veneto`
  - `Trentino Alto Adige`
  - `Emilia Romagna`
- Keep existing broader region options such as `Italy North East` in the same menu.
- Show the selected subregion label on the filter button.
- Keep the subregion options available even when current results are empty.

Answer: That is fine for now

Decision: The Search popup keeps one filter menu and adds exact subregion options `FVG`, `Veneto`, `Trentino Alto Adige`, and `Emilia Romagna`, while preserving existing broader region options.

### L15

Status: current

Question: Should ranked imports protect existing `HWC` peaks or overwrite matched peaks outside Tasmania?

Recommended Answer:
- Ignore current `sourceOfTruth` protection for ranked imports.
- Ranked imports are for supported non-Tasmanian regions in this spec.
- If a ranked row is valid and the `osmId` matches, update the mapped fields even when the existing peak is marked `HWC`, then set `sourceOfTruth` to the ranked region label.
- Keep the Tasmania-specific HWC importer behavior unchanged.

Answer: HWC is actually specific to Tasmania only, so it is ok to overwrite for regions outside of Tasmania ... agreed

Decision: Ranked imports must overwrite matched supported non-Tasmanian peaks regardless of their current `sourceOfTruth`, then set `sourceOfTruth` to the ranked-import region label.

Answer History:
- Initial answer: keep `HWC` peaks protected from ranked metadata overwrites.
- Final answer: `HWC` is Tasmania-specific, so ranked imports for supported non-Tasmanian regions may overwrite those peaks.

### L16

Status: deferred

Question: What exact ranked-import `sourceOfTruth` label and region mapping should be used for Slovenia?

Answer: I don't know about Slovenia - that is a tbd

Decision: Slovenia ranked-import support is deferred until its `sourceOfTruth` label and region mapping are defined.
