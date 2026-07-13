---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What new peak-list import capability should be added?

Answer: add a new import format for peak list import that exactly matches the peak list export format

Decision: Add a third header-detected peak-list import format that round-trips the app-owned peak-list export CSV contract rather than asking users to reshape exported files before re-importing them.

Negative Requirements:
- Do not replace the existing HWC peak-list import format.
- Do not replace the existing ranked peak list CSV import format.

### L2

Status: current

Question: What should happen when the new export-format import references an `osmId` that is not already in the local peak database?

Recommended Answer:
- Create the missing `Peak` from the exported row data.
- Keep the format round-trippable across app instances.

Answer: Create missing peaks (Recommended)

Decision: When the new export-format import sees an `osmId` that is not already stored locally, it must create the missing `Peak` from the imported row data instead of failing or skipping the row.

### L3

Status: current

Question: What exact shared header contract should the export-matching import use, and should older exported files remain supported?

Answer: only support the new format. In fact add county and range as well. the header should now be "name	altName	elevation	gridZoneDesignator	mgrs100kId	easting	northing	Points	osmId	country	region	county	range	sourceOfTruth" and these should match the Peak entity exactly

Decision: The shared peak-list export/import CSV contract must use only the new exact header row `name`, `altName`, `elevation`, `gridZoneDesignator`, `mgrs100kId`, `easting`, `northing`, `Points`, `osmId`, `country`, `region`, `county`, `range`, `sourceOfTruth` in that order, and the importer must not support the older 9-column export format.

Negative Requirements:
- Do not keep support for the previous export header.

### L4

Status: current

Question: When importing the new export-matching format, how should `PeakList.region` be set?

Recommended Answer:
- If the typed list name matches an existing list, keep that list's current `PeakList.region`.
- Otherwise create the list with the current default region.

Answer: Use existing on update, default on create (Recommended)

Decision: Export-format imports must preserve the existing `PeakList.region` when updating an existing list and must use the current default region when creating a new list.
