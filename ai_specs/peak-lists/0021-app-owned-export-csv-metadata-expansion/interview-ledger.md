---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should the app-owned export/import CSV remain backward-compatible with the previous app-owned header, or move to one new exact contract?

Answer: just keep the new format

Decision: The app-owned export/import CSV must use one new exact case-sensitive ordered header contract only, and the previous app-owned header is no longer supported by app-owned import.

Answer History:
- Initial answer: replace the old app-owned contract with `name,altName,elevation,rating,difficulty,gridZoneDesignator,mgrs100kId,easting,northing,points,osmId,country,region,county,range,sourceOfTruth,duration`.
- Revised answer: expand the exact replacement header to `name,altName,elevation,prominence,rating,difficulty,duration,viaFerrata,gridZoneDesignator,mgrs100kId,easting,northing,points,osmId,peakbaggerPid,country,region,county,range,notes,verified,sourceOfTruth`.

Negative Requirements:
- Do not keep support for the previous app-owned export header.
- Do not accept reordered or mixed old/new app-owned headers.

### L2

Status: current

Question: When importing the app-owned export CSV, should blank metadata cells clear stored values or leave existing values unchanged?

Recommended Answer:
- Treat the app-owned export CSV as the source of truth for explicit non-blank values it carries.
- Blank values preserve the existing stored value on existing peaks.
- Blank `duration` preserves existing duration fields on existing peaks.

Answer: agreed

Decision: The app-owned export CSV preserves existing stored values when a carried field is blank on an existing peak row, while non-blank values still override the stored value and newly created peaks still use normal model defaults for fields left blank in the CSV.

Answer History:
- Initial answer: blank values should clear the stored value for carried fields.
- Revised answer: keep the existing behavior so a blank entry does not clear the field and instead keeps the existing field value.

Reason: The user chose the safer existing preservation behavior for blank values on existing peaks.

### L3

Status: current

Question: How should `duration` round-trip in the expanded app-owned export/import contract?

Recommended Answer:
- Expand the shared `Peak duration` parser globally to accept `H:MM`, `<int>-<int> hour(s)`, `<int>-<int> day(s)`, `<int> day`, and `<int> days`.
- App-owned export writes the exact stored `durationLabel` when present.
- Otherwise export derives parser-safe values: `H:MM` for sub-day values and `<int> day(s)` for exact whole-day values.

Answer: agreed

Decision: The shared `Peak duration` parser must accept exact single-value day forms in addition to the existing clock and range forms, and the app-owned export/import contract must round-trip `duration` through that shared parser.

Answer History:
- Initial answer: export derived exact whole-day values as parser-safe day ranges.
- Revised answer: update the shared parser to accept exact `<int> day(s)` values and use that simpler exact-day form in the contract.

Negative Requirements:
- Do not add exact whole-hour forms such as `4 hours` in this change.

### L4

Status: current

Question: How should `rating` normalize in the app-owned export/import contract?

Answer: normalise to 1 decimal place everywhere

Decision: `rating` must normalize to one decimal place everywhere it is imported, stored, and exported for the app-owned export/import contract.

Constraints:
- Valid non-blank `rating` values are numeric `0` through `5` inclusive.
- Export writes ratings with exactly one decimal place when present, such as `4.0` or `4.4`.
- Blank `rating` preserves the existing stored value on existing peaks.

### L5

Status: current

Question: Should the new `difficulty` column be validated against region-specific ladders during app-owned import?

Recommended Answer:
- Treat `difficulty` as trimmed free text.
- Blank clears the stored value.
- Do not reject unknown labels during app-owned import.

Answer: agreed

Decision: App-owned import must treat `difficulty` as trimmed free text rather than validating it against a fixed region-specific allowlist.

Reason: The project stores `Peak difficulty` as region-specific text and does not define one universal validation contract for all regions.

### L6

Status: current

Question: Should the expanded app-owned contract include additional metadata fields that were previously left out of the round-trip format?

Answer: I'm thinking that maybe it would be a good idea to also include prominence, viaFerrata, notes, verified, and peakbaggerPid

Decision: Expand the app-owned export/import contract to include `prominence`, `viaFerrata`, `notes`, `verified`, and `peakbaggerPid` so those fields also participate in the full source-of-truth round-trip contract.

Answer History:
- Initial answer: preserve non-exported fields such as `prominence`, `viaFerrata`, `notes`, `verified`, and `peakbaggerPid` on existing peaks.
- Revised answer: include those fields in the app-owned contract instead, with blank cells following the field-specific preserve-existing rules.

### L7

Status: current

Question: How should the non-null `verified` field behave in the app-owned export/import contract?

Recommended Answer:
- Export `verified` as exact lowercase `true` or `false`.
- Import accepts only `true`, `false`, or blank.
- Blank preserves the existing stored value on existing peaks.

Answer: agreed

Decision: `verified` exports as lowercase boolean text and imports as `true`, `false`, or blank, where blank preserves the existing stored value for existing peaks and leaves newly created peaks at the model default `false`.

Negative Requirements:
- Do not accept alternate boolean spellings such as `TRUE`, `yes`, or `1`.

### L8

Status: current

Question: How should blank `sourceOfTruth` behave in the app-owned export/import contract?

Recommended Answer:
- Non-blank values are trimmed and stored exactly as provided.
- Blank preserves the existing stored value on existing peaks.
- Do not add a new allowlist validator in this change.

Answer: agreed

Decision: Blank `sourceOfTruth` preserves the existing stored value for existing peaks and leaves newly created peaks at the model default `OSM`, while non-blank values are trimmed and stored exactly as provided.

### L9

Status: current

Question: What values are valid for `peakbaggerPid` in the app-owned export/import contract?

Recommended Answer:
- Blank preserves the existing stored `peakbaggerPid` on existing peaks.
- Only positive integers are valid non-blank values.
- Reject `0`, negative integers, and non-integer text.

Answer: agreed

Decision: `peakbaggerPid` must round-trip as blank-or-positive-integer data only, where blank preserves the existing stored value for existing peaks and leaves newly created peaks with `null`.

### L10

Status: current

Question: Should blank `points` be treated as `0` or remain invalid in the app-owned export/import contract?

Recommended Answer:
- Keep `points` required.
- Export always writes an integer `points` value.
- Import rejects blank or non-integer `points`.

Answer: agreed

Decision: `points` remains a required integer column in the app-owned export/import contract and does not participate in blank-clears-existing semantics.

Reason: `points` defines explicit list membership row data rather than nullable peak metadata.

### L11

Status: current

Question: For app-owned import rows that create a new peak, how should blank `name`, `region`, and `country` behave?

Answer: name is required and blank name fails app-owned import for that row/file. If region is blank set to country. If both are blank fail the import

Decision: On app-owned import rows that create a new peak, blank `name` fails the import atomically, blank `region` falls back to `country`, and rows with both blank `region` and blank `country` fail the import atomically.

Reason: Existing-peak preserve-on-blank rules do not fully define create-path behavior because new peaks have no prior stored values to preserve.
