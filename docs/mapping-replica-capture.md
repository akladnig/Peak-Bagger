# Mapping runtime replica: independent capture and eligibility

Implements Spec 0063 Item 04 against the approved
[revision-1 contracts](mapping-runtime-replica-contracts.md) and
[completed source exports](mapping-source-publication.md). The mini remains the
canonical Mapping data store. Automatic transport/controller integration is Item
08; launch selection is Item 05; [retention/receipt acknowledgement](mapping-runtime-retention.md)
is implemented by Item 06.

## Local layout and authority

Supply a machine-local replica base outside canonical Mapping and the three
source-workspace synchronization roots. The only future Mutagen beta is
`<base>/incoming`; alpha is the mini's completed `prepared` surface.

| Relative location | Owner / meaning |
| --- | --- |
| `incoming/<generationId>/{payload,integrity.json,completion.json}` | Transport-writable export observation; never an app root |
| `candidates/<operationId>/payload` | Independent in-progress copy; retained after failure until safe cleanup |
| `generations/<generationId>/{payload,integrity.json,completion.json,validation.json}` | Frozen generation; metadata siblings are not Mapping references |
| `eligibility/<generationId>.json` | Versioned generation/inventory/completion/local-report binding |
| `receipts/<generationId>.json` | Independent durable receipt, exportable only through successful-outcome checks |
| `acknowledgements/<generationId>.json` | Exact durably accepted source response; receipt/evidence remain protected until confirmed |
| `requests/`, `operations/`, `operation.json`, `logs/`, `failures/` | Detached requests, authoritative per-operation outcomes, diagnostic current mirror, logs and failed reports |
| `locks/{pipeline,release-<UUID>}.lock` | OS lifetime ownership; surviving children inherit descriptors |

Configuration, app selection/sessions, installed releases and other local state
also remain outside incoming and immutable payloads. This stage reads incoming
but never writes it, has no canonical Mapping capability/fallback, and never
opens personal ObjectBox data. Local write operands reject incoming and symlink
aliases before creating directories or publishing records.

## Explicit maintainer/development entry points

Prerequisites: Python **3.10+**, project Dart SDK/dependencies, compatible host
GDAL/PROJ. From the project checkout:

```sh
python3 tool/mapping_replica.py --base /absolute/local/replica capture <generation-UUID> --transfer-complete
python3 tool/mapping_replica.py --base /absolute/local/replica --operation <returned-operation-UUID> status
python3 tool/mapping_replica.py --base /absolute/local/replica eligible <generation-UUID>
python3 tool/mapping_replica.py --base /absolute/local/replica receipt <generation-UUID>
```

`capture` returns an **accepted** detached operation and log path, not completion.
`--transfer-complete` is the transport seam's handoff after completed transfer/
flush of the intended generation; it is never integrity or eligibility evidence.
Without it capture fails at transfer. Idle Mutagen status, an arrived manifest or
elapsed timeout alone cannot authorize eligibility: coherent source metadata,
independent captured-byte hashes and the whole local profile must also pass.
Item 08 supplies real transfer/status reconciliation; this stage does not dispatch
SSH or Mutagen.

`Replica.capture(...)` is the synchronous integration/test entry point under the
same pipeline/release locks; `start_capture(...)` is detached. `DatasetValidator`
accepts copied command vectors and a concrete cwd for a pinned installed release.
CLI `--dataset-executable /absolute/installed/executable` replaces the development
`tool/mapping_source_dataset.dart validate` command. Scheduled callers must inject
the installed command/cwd. `--release-id`, `--compatible-source-release` and
`--compatible-controller-release` carry registered UUIDs; default development
UUIDs use the same v1 families as source preparation.

## Integrity, validity and publication

1. Observe strict source completion/inventory for the exact generation: schema 1,
   supported source release/profile `mapping-runtime-v1`, UUIDs, UTC completion
   time, ordered inventory and its reviewed compact SHA-256. Reject duplicate JSON
   keys, unknown fields/versions, unsafe paths and absent manifest-pair references.
2. Record [space accounting](mapping-runtime-retention.md) from current inventory
   sizes and existing directory identities before transfer/copy; completed incoming
   still needs a full independent copy plus **64 MiB reserve**. Do not delete
   protected data to fit an update.
3. Make exclusive new-inode streamed copies outside incoming, never writable hard
   links. NoFollow/non-regular checks and pre/post size/inode/mtime/ctime comparisons
   reject ordinary concurrent replacement/truncation. Flush captured files.
4. Verify exact captured path set, sizes and **SHA-256 of every raw byte**, rejecting
   symlinks/hard links. Pass the peer inventory unchanged to the shared production
   validator, which rederives the manifest-authorized set and requires exact
   equality. All declared DEMs, display polygons and catalogs remain required.
5. Apply the approved matrix: production manifests/path containment; every required/
   display polygon; peak parser/MGRS and declared-order raw-byte fingerprints;
   highway envelope/coverage merge/chunk preparation; Natural Feature pure plan,
   MGRS and reported skips; complete TasMap CSV; full band-1 GTiff/BigTIFF decoding
   with native-resource closure and disabled sidecar discovery/PAM writes.
6. Recheck captured hashes after semantic validation, and incoming completion/
   inventory identity before/after work. Capture the **exact persisted source
   metadata bytes**, not a reencoded completion. Changed metadata/candidate bytes
   prohibit publication. Later incoming payload writes cannot affect the copy.
7. Persist the passed report beside the payload, freeze files `0444`/directories
   `0555`, flush files/directories, and rename to the exact generation directory.
   Then atomically persist external eligibility, receipt and successful operation
   outcome. JSON publication flushes a temporary sibling, renames on the same
   filesystem and flushes the parent.

Matching hashes prove equality to the completed export, not dataset validity.
The matrix's geographic-truth, freshness, connectivity, raster-accuracy and NoData
coverage limitations still apply. Allowed production skips remain diagnostics.
There is no fingerprint repair to make a candidate pass.

The **per-operation outcome is the durable publication commit witness**:
`validation.operationId` selects `operations/<operationId>.json`, requiring
`succeeded`, the exact generation/release and `outcomeRecordSha256` binding the
eligibility object. It is written after generation, eligibility and receipt
publication completes durably. A visible eligibility/receipt left by interrupted
publication is insufficient. `eligible`/`receipt` enforce this chain; source
acknowledgement must use `receipt`, not blindly read a leftover file. The diagnostic
`operation.json` mirror is not the commit witness.

An unchanged completed identity reuses its immutable local generation and receipt
without recopying/rerunning the profile, even if incoming later changes. Different
completion/inventory under the same generation UUID is rejected. Genuine later
content requires a new generation. Multi-gigabyte hashing/native work stays in
this background maintainer stage.

## Reader handoff — Item 05

`Replica.eligible(generation)` demonstrates cheap reader checks: supported exact
envelopes/identities, inventory digest, persisted source-completion and local-report
SHA-256, passed validation/profile/release, and successful operation commit witness.
It checks immutable/independent modes, regular files and symlink-free generation
boundaries without hashing payloads. The app reader must implement this same small-
metadata chain, then normal local preflight/catalog loading and exact catalog/
inventory path-set equality. It must not launch this stage or contact the mini,
SMB or Mutagen during startup.

Item 05 transactionally selects and session-pins the concrete
`generations/<UUID>/payload` directory, preserving active/recovery on failed pending
checks. Cheap reads rely on controller-owned immutability; uncontrolled same-user
manual edits require background revalidation and cannot retain trusted eligibility.

## Ownership, failure and bounded recovery

One pipeline lock spans synchronous/detached capture, validation and publication.
Later calls report busy while it is owned. Lock acquisition is bounded to **5
seconds**; status probes are nonblocking. Supervisor and validator children inherit
pipeline/release descriptors. Client exit, PID or heartbeat alone never releases
protection. Never delete/replace lock files or release another owner's token.

Validator process supervision uses **5-second** polling, a **10-minute** no-output
progress threshold and **2-hour** budget. Expiry records `outcome-unknown` while
supervising the same child; it does not kill/duplicate it, infer validation or erase
transfer progress. Actual successful child completion plus required validation/
publication is the success evidence. Copy/hash work stays background/owned; Item
08 integrates controller stage budgets/inspection. Healthy work can span ticks.

Status separates outcome from `supervisorOrChildOwnsPipeline`. Failures record stage,
operation/generation IDs, incoming/candidate/final paths and affected dataset/parser
errors in logs and `failures/<operationId>.json` when a valid source inventory was
available. Missing/unfinished transfer metadata fails transfer; corrupt bytes fail
capture; profile/generation/eligibility publication fails validation; receipt
failure identifies receipt. Secondary failure-state persistence errors are reported.

```sh
# Only after bounded inspection proves inherited pipeline ownership has ended:
python3 tool/mapping_replica.py --base /absolute/local/replica --operation <original-UUID> reconcile
```

Reconciliation refuses a live lock/different current ID. It marks abandoned running/
unknown work failed or restores the mirror from an already durable authoritative
outcome. It never upgrades partial data to passed validation. Incomplete candidates
and partially published records remain ineligible. Item 06 removes them only after
ownership ends, permitting Item 08's safe retry. Previous validated data is never
rewritten/deleted/partially merged by this stage.

## Receipt/retention/controller handoffs — Items 06–08

- `Replica.receipt(generation)` returns schema-1 evidence bound to generation,
  inventory, exact source completion, passed local report, validating operation
  and controller release. It does not require app activation.
- `Replica.acknowledge` passes the exact receipt to source `Coordinator.acknowledge`
  / `receipt_cleanup_scope` with frozen
  live transfer/operation pins. Source acknowledgement is persisted before cleanup;
  retry a lost acknowledgement idempotently. Idle transfer never replaces receipt.
  Source production already bounds changed exports behind its sole outstanding
  unacknowledged generation.
- Implemented `Replica.cleanup` freezes local operation ownership under `pipeline`
  and app `selection-retention` before cleanup; protect
  `protectedGenerationIds`, `protectedExportIds`, operation-specific candidates and
  inherited release/helper lifetime until owners really end. Item 06 additionally
  coordinates active/recovery/newest pending and app/native session pins.
- Account for incoming, independent candidate, retained generations, source exports
  and release artifacts separately. The reserve check is not full retention policy
  or measured commissioning-space evidence.
- Item 07 installs the complete Python owner/shared helpers and production dataset
  executable/native dependencies, atomically selects compatible releases and
  retains in-use ones. Item 08 integrates persistent one-way transport, generation-
  specific transfer completion, outcome reconciliation and scheduled retry.

## Verification boundary

Disposable Python tests cover independent inodes/modes, incoming mutation during/
after validation, changed candidate/metadata, strict completion, interrupted copy/
post-rename publication, process crash, surviving child ownership, detached status,
unchanged reuse, low space, receipt/outcome binding and preservation of good data.
Flutter integration runs Python → real Dart profile → GDAL with tiny generated
GeoTIFFs, then rejects fresh-hash malformed upstream content in every matrix
category and stale fingerprints while retaining the good generation. Inventory/
direct-I/O guards freeze the newly authorized local-only adapter sites.

Tests require no user Mapping files, live SMB, SSH credentials or API keys.
Physical power-loss durability, real multi-gigabyte space/transfer costs, installed
releases, automatic sessions and performance commissioning belong to later items.
