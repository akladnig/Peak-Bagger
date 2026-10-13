# Coordinated Mapping publication and source exports

Implements Spec 0063 Item 03 and the reviewed
[revision-1 contracts](mapping-runtime-replica-contracts.md). The mini remains
authoritative at `/Volumes/Services/Mapping`. This is maintainer tooling; Flutter
startup and route-point handlers never invoke it.

## Owners and prerequisites

Run source mutation/preparation on the **mini**, with Services directly attached.
The controller refuses macOS SMB/NFS Services mounts and other host platforms.
Use Python 3, the project's Dart SDK/dependencies, and compatible host GDAL/PROJ.
The default mini-local base is `~/.local/share/peak-bagger-mapping-source`;
`--base /absolute/path` changes it. The base must be disjoint from Mapping and
outside all three source-workspace synchronization roots, including the running
checkout. The default produces this layout:

| Directory / file | Owner and meaning |
| --- | --- |
| `dispatch.lock`, `publication.lock`, `prepare.lock`, `release-<UUID>.lock` | Process-lifetime ownership; never delete lock files to recover |
| `publication.json`, `journals/`, `plans/`, `publication-publishers/`, `publication-capabilities/` | Publication intent, per-target progress, original capabilities and per-command completion |
| `backups/<publicationId>/` | Independent old app set, extra target preimages, directory-output snapshots; not synchronization inputs |
| `requests/`, `operations/`, `operation.json`, `logs/` | Recoverable operation identity, diagnostic progress and outcomes |
| `captures/<generationId>/payload` | Protected independent source capture, not exposed to transfer |
| `validation/`, `publication-validation/` | Profile results and post-publication validation evidence |
| `prepared/<generationId>/{payload,integrity.json,completion.json}` | Immutable completed synchronization surface |
| `receipts/` | Exact durable independent receipt acknowledgements |
| `publisher-compliance.json`, `external-publishers/` | Explicit reviewed register acknowledgement and original external script backup |

Published payloads and completion/integrity records are read-only. Logs, ownership,
configuration, validation reports and recovery state stay outside the payload and
outside the prepared surface. The export is **not** the whole Mapping tree.

The checked-in commands are explicit maintainer/development entry points. Item 07
installs complete versioned artifacts and executable dependencies outside changing
source workspaces; Item 08 schedules the installed controller. Scheduled work must
use those releases, not these checkout defaults. `DatasetBridge` accepts pinned
executable/command vectors and a concrete release cwd; copies them at invocation
construction. `--release-id UUID`, `--compatible-source-release UUID` and
`--compatible-controller-release UUID` carry installed identities/support forward.
Checkout defaults use deterministic development UUIDs for the `source-preparer-v1`
and `controller-v1` families, schemas 1 and profile `mapping-runtime-v1`. Unknown
completion versions, fields, profiles or unregistered release identities fail closed.

## One guarded maintenance transaction

Prepare exports, edited manifests, polygons and CSVs **outside Mapping**. Save
the complete related update as a JSON command array outside Mapping. For example,
`/tmp/mapping-maintenance/peaks-plan.json`:

```json
[
  {"publisher":"promote","arguments":["--target","Peaks/tasmania-peaks.json","--source","/tmp/mapping-maintenance/tasmania-peaks.json"]},
  {"publisher":"fingerprints","arguments":[]}
]
```

Then, from the mini's project checkout:

```sh
python3 tool/mapping_source.py maintenance run --plan /tmp/mapping-maintenance/peaks-plan.json
python3 tool/mapping_source.py --operation <returned-UUID> status
```

`run` begins a detached supervisor and returns an **accepted operation**, not
completion. Inspect its operation record/log until `succeeded`. The supervisor
holds one publication lock across the **whole array**, including child commands,
fingerprints/manifest changes, source validation and durable completion. There are
no unlocked gaps between related updates. A failed command is not skipped simply
because its existing target still parses. The plan records pending/running/succeeded
steps; finish recovery resumes unfinished commands and does not replay successful ones.

An empty plan (`maintenance run`) certifies the existing complete source through
the same capture/profile checks, establishing initial publication evidence. The
canonical manifest pair and required geometry must already permit a complete
independent backup; a failed initial preflight is a prerequisite diagnostic.

### Exact entry points for the complete reviewed register

| Publisher alias | Entry point and authority |
| --- | --- |
| `promote` | `tool/mapping_source_promote.dart`: only the exact files declared by `mapping-maintenance-promote`, no directory/wildcard/override authority |
| `fingerprints` | Existing `tool/update_region_peak_fingerprints.dart`; its original manifest-only capability |
| `thelist` | Existing `tool/download_tasmania_thelist_dem.dart` and typed staged `tool/publish_thelist_dem.sh`; original `--output-file` substitutions remain scoped to its declared output placeholder |
| `elvis` | Existing `tool/elvis_dem.dart` with `build-runtime`, `build-topo` or `build-all` and existing flags; original runtime/file and topo/directory capabilities |
| `bootstrap-tool-contract` | Existing absent-only `tool/mapping_store.dart bootstrap-tool-manifest`; restricted atomic no-overwrite capability |
| `tool-contract` | Explicit `tool/mapping_store.dart replace-reviewed-tool-manifest`; fixed reviewed fixture and exact tool-contract target only |
| `restore-tool-contract`, `restore-output-snapshot` | Recovery helpers using the original exact tool-contract or named publisher output capabilities; not general store-write shells |

Unwrapped canonical writes through the resolver fail **before writer dispatch**.
Child permissions require the live supervisor's Unix socket and ownership token;
children cannot complete the outer transaction. The resolver journals prior/next
SHA-256, preserves preimages, flushes committed files and parent directories, and
reports successful publication only afterwards. Disposable injected roots remain
available to tests and do not grant live canonical write authority.

Manual Overpass peaks/highways, Natural Features, Copernicus, TasMap, polygon and
manifest updates use `promote`. Keep all associated region/polygon manifests and
fingerprint updates in the same plan. FVG/Veneto/Slovenia highway updates belong in
one plan, followed by whole-source coverage merge/generation validation. Current
manual permissions enumerate the audited files; a new target/publisher requires a
reviewed exact declaration, inventory update and renewed compliance acknowledgement.

ELVIS `build-all` is one `elvis` plan step, so both derivatives share the outer
transaction. Topo bytes are backed up under their original directory capability
for recovery but are **not** app export inputs. Read-only `validate-source`,
theLIST preparation without publication and Local Topo rendering remain non-store
work; their output promotion must use the guarded procedure.

### External Slovenia export and enabling source preparation

The inventoried external `slovenia-highways.sh` fetches into its cwd. Install its
self-contained cwd guard on the mini before allowing export:

```sh
python3 tool/mapping_source.py install-external-guard
```

This updates only `/Volumes/Development/overpass_turbo/slovenia-highways.sh`, retains
its reviewed shell shebang/body, and saves an independent original outside source
sync roots. It rejects Mapping cwd and symlink aliases before any fetch/write.
Fetch into a non-store preparation directory, then promote the resulting JSON in
the same multi-region maintenance plan. The external README's historical direct
Mapping-cwd invocation is superseded by this procedure.

The installer requires a shell shebang on the first line. Live inspection on
2026-10-13 found that the existing script began directly with its portable `curl`
command, contrary to the earlier audit assumption. The maintainer preserved the
original and added `#!/bin/sh` before installing the guard with the pinned source
release. Launching an interactive `sh` does not supply the script's missing shebang.

Provision the reviewed 14-tool fixture through a `tool-contract`-only plan before
using the new manual capability; a missing tool contract can instead use the
restricted bootstrap alias. Verify publication succeeded and inspect the register,
then explicitly acknowledge all registered repo/external/manual procedures:

```sh
python3 tool/mapping_source.py enable --confirm-publisher-register 1
python3 tool/mapping_source.py prepare
```

`enable` requires successful canonical publication evidence, parsed current named
capabilities and the exact installed external cwd guard. Preparation rechecks
capability and external-script digest drift. Missing/noncompliant publishers block
export. This does not install a Mutagen session, controller or schedule.

## Capture, validation and immutable completion

Preparation retains its own operation/release lock while taking the publication
lock for the complete independent copy. It releases canonical capture coordination
only after copying every production catalog-authorized reference. Required DEMs,
display-only polygons and the manifest pair are included; raw ELVIS, topo derivatives,
tool-only files, Local Topo service payloads and personal app data are excluded.
No writable hard links or directory globs derive the required set.

The background pipeline rederives the captured set, streams SHA-256/byte sizes,
requires exact inventory equality and applies the reviewed profile:

- Production manifest/path checks and every required/display polygon parser.
- The importer's shared pure peak parser/MGRS enrichment and declared-order raw-byte
  regional fingerprints; no fingerprint rewrite to make validation pass.
- Every highway envelope/positive identity, production coverage merge policy and
  selected-way checks, followed by the existing pure chunk/generation builder.
- Natural Feature pure geometry plan, MGRS conversion and recorded production skips.
- Entire strict TasMap CSV parser, including the required nullable-value `Parent` header.
- Read-only GTiff/BigTIFF, supported numeric band 1, positive dimensions, finite
  invertible transform and usable WGS84 transformation; decode **every band-1 block**,
  reject decode errors/nonfinite non-NoData samples, close dataset/SRS/transforms on
  success/failure. PAM and ambient sidecar discovery are disabled.

The matrix's geographic, freshness, connectivity, raster accuracy and NoData
coverage limitations still apply. Integrity is byte equality, not semantic truth.
Identical permitted diagnostics are aggregated with exact occurrence counts,
retaining every distinct message/identity. Live validation found 627,587 identical
ineligible Natural Feature skips, plus four distinct messages: unaggregated evidence
was 58,373,281 bytes, exceeding the app/local reader's 16 MiB metadata bound.
Aggregation retains all outcomes in a small report; local capture checks the final
report size before publication and fails ineligible if distinct evidence still
exceeds the bound. Neither payloads, fingerprints nor required checks are changed.

Composite regions are unions of sources rather than imported ownership regions.
They may contain the same OSM peak identity in distinct valid source files, as
Italy NE/NW do under the existing NE-over-NW importer precedence. Validation still
parses every declared file, rejects duplicate identities within each file, and
rejects cross-file duplicates within a noncomposite region. A composite does not
override importer ownership or authorize dropping a source from the export.

Only after validation and durable metadata publication is the directory moved to
`prepared/<generationId>`. File and directory flush failures leave the operation
failed/unresolved and publish no valid completed surface. Unchanged complete
publications reuse the existing export without another copy/hash/profile pass.
Changed publication with identical captured bytes also reuses it. A changed dataset
cannot accumulate exports: finish durable receipt of the sole unacknowledged export
first, or preparation reports blocked **before another full scratch copy**. The
acknowledged current surface stays available for reuse; a complete successor makes
the old acknowledged unowned export prunable.

Space checks use manifest-derived byte totals before each independent copy, plus
a 64 MiB reserve. Account separately for publication backups, validation scratch,
candidate capture and the protected export; insufficient space fails that stage
without deleting protected data. [Item 06 storage accounting and controller cleanup](mapping-runtime-retention.md)
record existing occupation per identity, additional bytes and available space.

## Status, interruption and recovery

Lock acquisition is bounded to **5 seconds**, Unix-socket responses to **30 seconds**,
child progress polling to **5 seconds**, no-progress diagnostics to **10 minutes**,
and a child-stage budget to **2 hours**. These are limits/diagnostics, not a
refresh-completion promise. A stage may span many controller ticks. Expiry records
`outcome-unknown` while its detached owner keeps inspecting/waiting; it does not kill
healthy work, duplicate preparation, clear transfer progress or authorize completion.
The budget must be tuned explicitly by a release for measured workloads.

SSH/client exit does not end the supervisor. Children inherit lifetime-lock file
descriptors, preserving protection if the supervisor dies while they survive.
Status reports actual pipeline ownership separately from diagnostic PID/timestamps.
Release files, operation records and incomplete captures remain until ownership is
proven ended. Never remove/replace lock files, steal tokens, or edit state to `complete`.

```sh
python3 tool/mapping_source.py --operation <original-UUID> status
# Only after dispatch/child ownership is actually free:
python3 tool/mapping_source.py --operation <original-UUID> reconcile
python3 tool/mapping_source.py maintenance recover
# Or restore independent old bytes through original named capabilities:
python3 tool/mapping_source.py maintenance recover --rollback
```

`reconcile` cannot enter a still-owned pipeline. It resolves abandoned operation
state; it does not certify a partially published canonical dataset. `recover`
retains the publication ID/backups/journal, obtains a new live ownership token,
finishes pending plan commands (or restores old bytes), validates the full result
and writes durable completion/validated rollback evidence. Changed previously
prepared bytes are rejected in finish recovery; restore the original preparation
input or choose rollback. A free OS publication lock alone never permits capture.
Canonical completion additionally binds a successful durable supervisor outcome.
Failed validation/completion includes operation/dataset context in logs/reports.

For tool-contract-only rollback, the original contract is restored and untouched
app sources are validated. Directory-output snapshots use their original named
output authority and verified backup inventory. Retain backups/journals for an
incomplete publication; do not overwrite/remove them to force another update.

### Composite peak validation failure during initial setup

The initial live tool-contract transaction `1ce02fd9-22b8-4440-b0c0-1ac5a8d9a5d2`
published the reviewed contract but failed whole-source validation with
`Duplicate peak identity: italy:Peaks/italy-nord-ovest-peaks.json`. Read-only
inspection found no duplicates within either Italy peak file and four shared
identities across them. The validator had incorrectly applied an imported-region
uniqueness constraint to the composite `italy` union.

The fix resets cross-file identity tracking only for composite regions, preserving
all file validation, noncomposite uniqueness and raw-byte fingerprint checks.
Disposable behavior-first coverage reproduces the error and verifies both retained
duplicate-rejection cases. Compatible immutable releases were installed/selected
without editing old release artifacts:

| Role | Corrected release |
| --- | --- |
| MacBook controller/local validator | `e88b0e1e-6157-4659-9da4-c47079c576ce` |
| Mini source preparer/validator | `c827d430-9994-4d2d-9fac-fa2f1df6d22c` |

Both retain support for the previous installed and development release identities,
schemas 1, profile `mapping-runtime-v1` and the existing app reader. After bounded
inspection confirmed the failed supervisor/child ownership was released, recovery
was started with the installed dispatcher:

```sh
/Users/adrian/.local/bin/python3.15 -I \
  /Users/adrian/.local/share/peak-bagger-mapping-releases/mapping_release_launcher.py \
  run -- maintenance recover
```

Recovery operation `317d8558-23a9-4d1f-902b-9a25f215de53` resumed the existing
publication and retained plan without replaying the successful tool-contract step.
It completed successfully at **2026-10-13T09:31:39Z** with publication `complete`
and released supervisor/child ownership. Installed publisher-register enablement
then succeeded through the same guarded capabilities/guard checks. An accepted
recovery alone would not have permitted enablement. Do not rerun `maintenance run`, remove backups/journals,
rewrite fingerprints, alter the peak datasets, or patch an immutable release to
bypass this failure.

Verification for the correction: `flutter analyze --no-pub` reported no issues;
the full `caffeinate -i flutter test --no-pub --reporter expanded` run passed
**2,257 tests**, with **5 existing skips**, in **3m09s**; the Python tooling suite
passed **100 tests**. Disposable tests do not substitute for the live source
validation/recovery outcome or for Item 08's scheduled-controller commissioning.

### Item 06 receipt-bound cleanup integration

`Coordinator.receipt_cleanup_scope(receipt, protected_export_ids=...)` is the
source-side integration boundary. The caller must supply its frozen live transfer
and operation pins and keep the scope held for any cleanup. It takes source
dispatch/preparation coordination, rejects protected or unsupported identities,
verifies exact generation/inventory/source-completion SHA-256 and supported
controller release, and durably persists the acknowledgement **before** yielding
the generation identity. `Coordinator.acknowledge` returns the same durably accepted
receipt. `Coordinator.cleanup` keeps the current completed surface, every unacknowledged
export and every live/unresolved transfer/preparation identity, and prunes acknowledged
old exports or abandoned captures only after their real owners end. Retained receipt
evidence permits reconnect retries after pruning. See [implemented policy and recovery](mapping-runtime-retention.md).

Item 04 produces the exact downstream evidence through `Replica.receipt`, which
checks the local independent generation, passed report and durable publication
outcome before returning a receipt. See [local capture/eligibility and controller
handoffs](mapping-replica-capture.md); an unchecked incoming or leftover receipt
file cannot authorize source cleanup.

## Verification and commissioning boundary

Automated tests use disposable manifests/files/processes/sockets, including a real
tiny compressed GDAL raster. They require no real Mapping payloads, SMB, SSH
credentials or API keys. They cover full derivation, malformed payloads with valid
digests, stale fingerprints, source/publisher exclusion, incomplete/crashed writers,
multi-command resumption, inherited child protection, failed validation/completion,
immutable reuse, unknown metadata and receipt-bound protection.

This implementation does not claim live canonical modification, an installed
external guard, an enabled producer, scheduled/Mutagen commissioning or physical
power-loss testing. Flush/rename and process-fault behavior are tested locally;
installed release/host dependency and live operating evidence belong to Items 07–11.
