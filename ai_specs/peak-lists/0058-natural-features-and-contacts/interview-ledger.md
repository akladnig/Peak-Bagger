---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: How should the requested plural natural-features entity be named and scoped in the app?

Answer: Use a singular `NaturalFeature` ObjectBox/Dart entity, a `Natural Features` ObjectBox Admin label, and no map, peak-list, peak-search, or other peak-specific integration.

Decision: Natural Features are a separate admin-maintained domain from Peaks.

### L2

Status: current

Question: How should imported OSM elements be identified across nodes, ways, and relations?

Recommended Answer:
- Persist the numeric JSON ID as `osmId` and add `osmType` with `node`, `way`, or `relation`.
- Match refresh records by `(osmType, osmId)`.

Answer: agreed

Decision: OSM feature identity is the composite `(osmType, osmId)`; `osmId` alone is not unique.

### L3

Status: current

Question: Which source elements are importable, and how is their representative coordinate calculated?

Recommended Answer:
- Import only named elements with non-empty `natural` tags, using untagged export elements only to resolve geometry.
- Use direct node coordinates, area centroids for closed ways and multipolygon relations, and length-weighted line centroids for open ways and other resolvable relations.
- Skip unrecoverable geometry without a network lookup.

Answer: agreed

Decision: The local export supplies all geometry; only named natural-tagged elements become Natural Features, and each uses the specified deterministic centroid rule.

### L4

Status: current

Question: How should source tags populate Natural Feature fields?

Recommended Answer:
- Seed `altName` from `tags.alt_name`, reject an alternate name equal to `name`, and retain it across refreshes.
- Set `tag` from `natural`, except use a non-empty `water` tag value for `natural=water` and otherwise use `water`.
- Set initial `country` to `Australia`, `region` to `Tasmania`, and `county` to an empty string.

Answer: agreed

Decision: The importer uses the agreed name, alternate-name, tag, water fallback, and Tasmania defaults without inferring county or using other alternate-name tags.

### L5

Status: current

Question: What are the Natural Feature refresh and failure semantics?

Recommended Answer:
- Refresh is an atomic upsert that preserves ObjectBox IDs, updates matches, and inserts new source identities.
- Source omissions do not delete stored records.
- Preserve `altName`, `country`, `county`, and `region`; also preserve `name` when `altName` is non-empty.

Answer: agreed

Decision: A failed refresh commits no changes; a successful refresh preserves the stated locally curated fields and updates the remaining OSM-derived fields for eligible records.

### L6

Status: current

Question: How should Natural Feature provenance affect refresh eligibility?

Recommended Answer:
- Add `sourceOfTruth`, default imports to `OSM`, and expose `OSM` and `Manual` in the details pane.
- Refresh only records whose source of truth is `OSM`; `Manual` records remain unchanged and can later be changed back to `OSM`.

Answer: agreed

Decision: `sourceOfTruth` is the explicit, reversible refresh-protection control for Natural Features.

### L7

Status: current

Question: What should the Settings refresh action display and report?

Recommended Answer:
- Place `Refresh Natural Features` directly under `Refresh Peak Data`, start immediately, use the existing busy state, and show no confirmation.
- Report created, updated, protected, and skipped counts; report failures without changing persisted data.

Answer: agreed

Decision: The Settings action follows the exact local-upsert status and error-feedback contract.

### L8

Status: current

Question: What Natural Feature administration and editing capabilities are required?

Answer: Do not add an Add Natural Feature button. Allow editing every field except `id`, `osmType`, and `osmId`; coordinate and MGRS editing must work as for Peak editing. Add `altName` and `sourceOfTruth`.

Decision: ObjectBox Admin provides a Peak-style editable Natural Feature details pane while preserving identity fields as read-only.

### L9

Status: current

Question: What Contact entity, validation, and admin flow are required?

Recommended Answer:
- Use a `Contact` entity with generated `id`, `firstName`, `surname`, and `nickname`; show the collection as `Contacts`.
- Add `Add Contact`; require at least one trimmed name field, permit duplicates, and retain standard save, cancel, selection, and deletion behavior.

Answer: agreed

Decision: Contacts are independent, minimally validated address-book records with no relationships to current app entities.

### L10

Status: current

Question: How should ObjectBox Admin identify, search, and delete Natural Features and Contacts?

Recommended Answer:
- Search Natural Features by name, alternate name, tag, OSM type, and OSM ID; search Contacts by all three name fields.
- Display Contacts with a composed name, nickname fallback, and separate stored-field columns.
- Confirm deletion for both entities; a deleted source feature is recreated as `OSM` on the next matching refresh, while Contacts remain deleted.

Answer: agreed

Decision: Admin search, display, sorting, and deletion use the agreed entity-specific rules without adding a source-suppression store.

### L11

Status: current

Question: What verification must cover the parser, persistence, and UI contracts?

Recommended Answer:
- Use injected file-reader and MGRS-converter seams with focused geometry fixtures and ObjectBox persistence coverage.
- Cover settings and ObjectBox Admin widget flows, then run generation, analysis, focused tests, the schema guard, and the full suite.

Answer: agreed

Decision: Verification must be deterministic, fixture-based, and cover parser, transaction, admin, and Settings behavior without depending on the external source file.
