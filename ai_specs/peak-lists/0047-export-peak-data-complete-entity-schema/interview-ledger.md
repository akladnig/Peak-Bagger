---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should every field in the ObjectBox `Peak` entity include the internal ObjectBox `id` field as a CSV column?

Recommended Answer:
- Yes. Export every declared `Peak` field, including `id`, as a complete record extract.
- Use blank CSV cells for nullable values.

Answer: agreed

Decision: The export must include `id` and every declared `Peak` field; null values are blank CSV cells.

Reason: The export is a complete ObjectBox `Peak` record extract rather than a partial user-facing report.

### L2

Status: current

Question: Should the CSV replace its current title-cased partial header with the `Peak` declaration order?

Recommended Answer:
- Yes. Use exact lower-camel-case Dart field names in declaration order.
- Preserve the existing export path, filename, background-job progress, and failure behavior.

Answer: agreed

Decision: The CSV header and column order must be `id`, `osmId`, `peakbaggerPid`, `name`, `altName`, `elevation`, `prominence`, `country`, `county`, `range`, `rating`, `durationMinutes`, `durationLabel`, `difficulty`, `viaFerrata`, `notes`, `latitude`, `longitude`, `region`, `gridZoneDesignator`, `mgrs100kId`, `easting`, `northing`, `verified`, and `sourceOfTruth`.

Reason: This is an intentional replacement of the existing partial, title-cased CSV header contract with a complete schema-aligned export.
