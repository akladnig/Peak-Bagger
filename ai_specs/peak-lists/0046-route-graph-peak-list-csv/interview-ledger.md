---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What spatial relationship should select peaks for the CSV?

Recommended Answer:
- Treat a peak as matched when it is within the existing peak-correlation distance threshold of a route-graph way.

Answer: Use the same threshold as peak correlation for GPX tracks.

Decision: Select a peak when it lies within 50 m of a route-graph-way segment.

### L2

Status: current

Question: Which OSM ways count as highways?

Recommended Answer:
- Use every imported OSM `way` with a `highway` tag, including paths, tracks, and footways.

Answer: Agreed.

Decision: The full route-graph highway set is eligible; roads-only filtering is out of scope.

### L3

Status: current

Question: Which source provides the highway geometry?

Answer: Use the highways location defined in `region_manifest.json`.

Decision: Resolve and parse the selected manifest region's `highways` paths. Do not use `RouteGraphWayIndex`, which lacks geometry and duplicates ways across spatial chunks.

### L4

Status: current

Question: What happens when a selected manifest highway file is absent?

Recommended Answer:
- Fail before producing a CSV, write the selected region and missing path to stderr, and exit 1.

Answer: Agreed.

Decision: Missing manifest-listed highway inputs are fatal and must leave no output CSV.

### L5

Status: superseded

Question: What region values are supported and how do they select peaks?

Recommended Answer:
- Accept canonical manifest keys case-insensitively, default to `tasmania`, and select stored peaks by exact canonical `Peak.region` match.

Answer: Agreed. Allow region names as per the manifest region key.

Decision: Superseded by L17.

### L6

Status: current

Question: Where should the single CSV be written?

Recommended Answer:
- Accept `--output <path>`; otherwise write `<BushwalkingRoot>/Peak_Lists/<region>-route-graph-peak-list.csv` and require the parent directory to exist.

Answer: Agreed.

Decision: The tool writes one CSV to the supplied output path or the region-derived default in `Peak_Lists`; it does not create parent directories.

### L7

Status: current

Question: Should the tool persist a generated `PeakList`?

Recommended Answer:
- Only write the CSV and do not mutate ObjectBox.

Answer: Agreed.

Decision: The exporter is read-only with respect to the ObjectBox database.

### L8

Status: current

Question: What points value should generated CSV memberships use?

Recommended Answer:
- Use `1` for every row, matching the app's default peak-list membership value.

Answer: Agreed.

Decision: Every generated row writes `1` in the `points` column.

### L9

Status: current

Question: What deterministic row order should the generated CSV use?

Recommended Answer:
- Sort by case-insensitive peak name and then `osmId`, matching the current app exporter.

Answer: Agreed.

Decision: Generated rows use the app exporter's name-then-`osmId` order.

### L10

Status: superseded

Question: Which ObjectBox store should the shell tool read?

Recommended Answer:
- Use the GUI's primary macOS ObjectBox directory, including legacy migration preparation.

Answer: Agreed.

Decision: Superseded by L16. The tool does not open ObjectBox.

### L11

Status: current

Question: What happens when no peaks match?

Recommended Answer:
- Write a valid header-only CSV, report zero matches, and exit 0.

Answer: Agreed.

Decision: An empty successful selection produces a header-only CSV.

### L12

Status: current

Question: What happens when the output CSV already exists?

Recommended Answer:
- Replace it atomically and report the output path and matched count.

Answer: Agreed.

Decision: Repeated successful runs atomically replace the target CSV.

### L13

Status: current

Question: How should the shell script run the Dart tool?

Recommended Answer:
- Build a release macOS Flutter executable when sources are newer, then execute it with supplied arguments.

Answer: Agreed.

Decision: A root-level shell launcher builds and runs the standalone Dart entry point as a macOS Flutter executable; it is not a plain `dart run` command.

### L14

Status: current

Question: Does the GPX elevation threshold apply to highway correlation?

Recommended Answer:
- Use only the shared 50 m horizontal threshold because highway geometry has no elevation values.

Answer: Agreed.

Decision: Highway matching is two-dimensional; do not infer or require an elevation match.

### L15

Status: current

Question: Which region names should `--help` show?

Recommended Answer:
- List canonical manifest keys that resolve to one or more effective `highways` paths directly or through a manifest-priority ancestor; a listed but absent source file still fails when selected.

Answer: Agreed. A child region without `highways` uses the nearest manifest-priority ancestor's declaration.

Decision: `--help` prints the supported canonical region keys that resolve to effective highway paths directly or through an ancestor.

### L16

Status: current

Question: What peak source should the tool use instead of ObjectBox?

Answer: Use the default `~/Documents/Bushwalking/Features/peaks.csv`. It will contain every field from the ObjectBox `Peak` entity.

Decision: Read the default `~/Documents/Bushwalking/Features/peaks.csv` source CSV without opening ObjectBox. The source has the 25 `Peak` fields, including latitude and longitude required for matching; output remains the existing 22-column app-owned export CSV.

### L17

Status: current

Question: How should selected manifest regions expand source-region eligibility and preserve source-region values in the output?

Answer: Use aliases and aggregate-region unions. Preserve the matching source-region key rather than replacing it with the selected aggregate.

Decision: `--region` accepts canonical manifest region keys case-insensitively and defaults to `tasmania`. Resolve a selected key's effective `highways` paths from its own non-empty declaration or, when absent, by repeatedly removing the final segment of its manifest `priority` until an ancestor with a non-empty declaration is found. For a selected non-composite manifest region, eligible normalized source-region values are its key and every `peakListFilterAliases` value, even when it inherits effective highway paths. For a selected composite manifest region, eligible normalized source-region values are the keys and aliases of every non-composite manifest region whose non-empty effective `highways` paths are included in the selected region's effective `highways` paths. Normalize a source `region` by trimming and case-folding it; write that normalized matching value to the output and never replace an administrative source region such as `fvg` with a selected aggregate key. A region is invalid only when neither it nor any manifest-priority ancestor declares one or more `highways` paths.
