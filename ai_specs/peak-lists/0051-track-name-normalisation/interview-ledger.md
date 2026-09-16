---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should Track name normalisation be a one-time maintenance action for existing stored Tracks, or a persistent preference for future imports?

Recommended Answer:
- Add a one-time `Normalise Track Names` maintenance action directly below `Recalculate Track Statistics`.
- Update every stored `GpxTrack.trackName` while retaining its separate `trackDate`.
- Normalise new imports as well, so dates do not return to stored names.

Answer: agreed

Decision: Track name normalisation is a bulk persisted Track maintenance action, and import-time Track naming must use the same normalisation.

Reason: This repairs existing data while keeping future imported names consistent without adding a preference that would create mixed naming conventions.

### L2

Status: current

Question: Which trailing date formats should Track name normalisation remove?

Recommended Answer:
- Remove only unambiguous trailing dates in `dd-MM-yyyy` or `dd/MM/yyyy` form, optionally enclosed in parentheses and separated from the name by whitespace, a hyphen, or an underscore.
- Leave dates elsewhere in a name unchanged.
- Leave a name containing only a date unchanged rather than making it blank.

Answer: agreed

Decision: Remove only the defined trailing date suffixes and preserve all other Track-name content.

Examples:
- `Mt Anne (10-03-2025)` becomes `Mt Anne`.
- `Mt Anne (10/03/2025)` becomes `Mt Anne`.
- `Mt Anne - 10-03-2025` becomes `Mt Anne`.
- `Mt Anne_10-03-2025` becomes `Mt Anne`.

### L3

Status: current

Question: Should the action follow the existing Settings confirmation-and-result dialog pattern?

Recommended Answer:
- Use the exact tile, confirmation, success, and failure copy supplied in the interview.
- Cancel performs no write.
- Success reports updated and unchanged counts.
- Disable the action while another Track maintenance action is running.
- A failure retains stored names.

Answer: agreed

Decision: Track name normalisation must use the established Settings maintenance-action UX, including confirmation, loading exclusion, result counts, and failure recovery.
