# Mapping runtime retention, space and durable receipt

Spec 0063 Item 06 implements the background-controller policy on top of the
[reviewed revision-1 contracts](mapping-runtime-replica-contracts.md),
[independent captures](mapping-replica-capture.md) and
[transactional app selection](mapping-runtime-startup.md). Installation and
scheduled/SSH/Mutagen orchestration are Items 07–08; real-machine storage and
operating evidence is commissioned in Item 11.

## Controller entry points and authority

Explicit development/maintainer commands (machine-local bases, outside Mapping
and source synchronization roots):

```sh
# MacBook: inspect the current operation and last policy observations.
python3 tool/mapping_replica.py --base /absolute/local/replica status
python3 tool/mapping_replica.py --base /absolute/local/replica cleanup

# Mini: supply every frozen live transfer/operation export identity.
python3 tool/mapping_source.py --base /absolute/local/source-state cleanup --protected-export <UUID>
python3 tool/mapping_source.py --base /absolute/local/source-state acknowledge --protected-export <UUID>
```

`acknowledge` reads the exact validated MacBook receipt JSON on stdin and returns
that same receipt only after durable source publication. Omit a `--protected-export`
only when ownership inspection has proved that export is no longer needed by
transfer/preparation. An idle transport or a dead SSH client is insufficient.
The source also independently retains unresolved recorded operations and rejects
acknowledgement during live source ownership. These commands operate on non-store
exports/metadata, not canonical Mapping or personal ObjectBox files.

`Replica.cleanup()`, `Replica.audit_space(...)`, `Replica.acknowledge(generation,
send=...)`, `Coordinator.cleanup(protected_export_ids=...)`,
`Coordinator.audit_space(...)` and `Coordinator.acknowledge(...)` are controller
integration seams. `send` must be Item 08's bounded, noninteractive authenticated
transport to the source owner, returning its exact receipt response. The source
pin set must be frozen through the source request. Scheduled callers use installed
release commands/helpers, not checkout defaults. Mutating entry points acquire
their ownership locks; do not recursively acquire the same exclusive flock while
composing an invocation. Item 08 owns the encompassing single-flight invocation
and transport reconciliation.

`mapping_retention.py` is a shared **non-store** policy helper, installed with both
Python owners. It has no standalone dataset authority. Incoming is read/accounted
but never pruned or rewritten here: only Mutagen owns incoming writes. The app
continues to select/pin small metadata and performs no bulk cleanup.

## Local protection and pruning

Cleanup takes `locks/pipeline.lock`, then the exact app-owned
`locks/selection-retention.lock` (bounded default acquisition **5 seconds**).
App launch holds the latter through catalog readiness, session publication and
atomic activation. Cleanup cannot cross an overlapping launch before its concrete
root is pinned. It validates supported metadata before destructive decisions.

Always retain:

- Selected **active** and **one validated recovery** generation, bound to exact
  inventory and persisted eligibility bytes.
- Every held `session-<sessionId>.lock` generation, including native owners.
- Both full old/new tuples of an unresolved selection transaction. A committed
  journal is retired only when it exactly matches current complete selection and
  all referenced eligibility bindings still validate. Its obsolete prior recovery
  then becomes prunable; an unresolved prepared journal remains conservative.
- The newest **complete eligible pending** generation, ordered by UTC eligibility
  time then UUID, strictly later than selected active/recovery order. Old selected
  eligibility cannot reactivate as pending. Missing/unexpected files, changed sizes,
  writable/relinked files or unsupported metadata cannot count as a complete
  pending generation. This is cheap metadata/stat validation, not payload hashing.
- Generations/candidates referenced by unresolved producing/validating operations,
  and durable captures awaiting a confirmed source receipt. The latter retain the
  validation evidence necessary to retry a lost acknowledgement. Source production
  bounds that outstanding receipt; it is not a licence to produce more exports.

Additional generations are allowed only for these actual session/native,
operation/receipt or unresolved-transaction protections. A newer pending update
never displaces another session's root. Cleanup does not remove protected data to
meet a space target.

Only terminal, ownership-released candidate operations authorize removal of
incomplete/abandoned captures. A directory with missing producer evidence is
reported as protected/unresolved, not inferred abandoned from its age or PID.
Live supervisors/children inherit pipeline/release descriptors; even a terminal
record cannot authorize pruning while a surviving child still holds the pipeline.
`running`/`outcome-unknown` records retain data and release identities after a lock
becomes free until exact-operation reconciliation resolves them. Timeout/client
exit never constitutes that reconciliation. Release/helper pruning belongs to
Item 07 and must honor both inherited locks and these unresolved release identities.

Cleanup publishes its protected identities and pruning **intent before deletion**.
It changes directory permissions only for already-unprotected readonly trees,
rejecting symlinks/nonregular/hardlinked operands. Deletions and parent metadata
changes are flushed. An interrupted removal is retryable: leftover eligibility for
a proven terminal unprotected producer can be removed after its directory is gone.
Receipt/acknowledgement/operation/failure evidence is retained. Lock inodes are never
unlinked or replaced. Unknown versions/releases and conflicting selection/receipt
bindings fail closed with an actionable diagnostic.

## Session, native cache and worker lifetime

`sessions/<UUID>.json` records a host/boot/process-start/token identity. Only its
held OS flock is liveness authority. A stale record or reused PID does not protect
a directory; process crash releases session descriptors. Keeping diagnostic session
records does not keep a live pin.

`MappingSessionProtection` owns the process pin; `MappingRuntimeSession.close()`
requests release but waits for native-owner tokens. The
`RegionAwareRouteElevationSampler` future cache retains a token **before** a lazy
native open, through the pending open and the dataset lifetime. Provider disposal
awaits pending opens and closes cached GDAL datasets/transforms/spatial references;
failed opens release their token. Cache invalidation closes abandoned entries.
Native-close failure retains the token until process death. UI disposal alone is
not native-resource closure. Even with no open DEM, a running app keeps its root
pinned for later imports/lazy reads. There is no new DEM worker in this item;
future worker implementations must retain equivalent protection until dataset close
and worker join, including workers that outlive UI ownership.

## Durable receipt and source cleanup

1. `Replica.receipt(generation)` verifies the successful local publication witness,
   supported schema/profile/releases, independent immutable complete generation,
   exact source completion, inventory and passed local validation-report binding.
   A leftover receipt without that witness cannot be sent.
2. Send that same schema-1 `mapping-durable-receipt` through the trusted transport.
   Source checks generation, inventory, exact persisted completion SHA-256,
   controller compatibility and receipt identity, then atomically writes/flushes
   `receipts/<generation>.json` before returning the exact receipt.
3. MacBook confirms exact equality and persists the same record at
   `acknowledgements/<generation>.json`. A lost response, wrong echo or failed local
   acknowledgement write leaves local validation evidence protected. Retry uses
   the same receipt ID/bytes; conflicting acknowledgements are rejected.
4. Source cleanup retains every unacknowledged or live-transfer/operation export
   and its **current completed surface**, even when acknowledged. The current
   surface remains available for unchanged-generation reuse. After an acknowledged
   export has a complete successor and no owner needs it, it is prunable. Source
   receipt evidence survives pruning, so reconnect retries remain idempotent.

A changed source publication checks for the sole outstanding unacknowledged export
**before making another full capture**. It reports a blocked pipeline rather than
accumulating exports or full scratch copies on every tick. After acknowledgement,
one new independent candidate may coexist with the acknowledged current surface;
unchanged bytes reuse the existing generation, while changed bytes publish a new
validated export. Terminal abandoned source captures are prunable only after
source dispatch/preparation/publication coordination is free. Publication backups,
journals and validation/recovery evidence are not erased by this policy.

## Storage accounting and insufficient space

Supply the completed/manifest-derived `mapping-integrity` inventory to the `space`
command on stdin, **before initial provisioning and every refresh**, on both hosts:

```sh
python3 tool/mapping_replica.py --base /absolute/local/replica space --stage provision
python3 tool/mapping_replica.py --base /absolute/local/replica space --stage refresh --incoming-remaining-bytes 0
python3 tool/mapping_source.py --base /absolute/local/source-state space --stage refresh
```

The default MacBook plan requires **one full incoming dataset plus one full
independent capture**, beyond currently occupied space, plus **64 MiB reserve**.
The controller may supply an inspected remaining incoming-byte count; zero means
transfer has completed, but the full independent-copy cost remains. Capture checks
space again under pipeline ownership immediately before copying. Source capture
uses the production resolver's fresh inventory and requires a full independent
copy plus reserve before invoking capture, including publication backup/validation
copies where that bridge is used.

Reports contain exact observed `datasetBytes`, planned per-stage/additional bytes,
available filesystem bytes, reserve, operation/generation/local path and outcome.
Existing incoming, candidates, generations, prepared mini exports, source captures,
installed releases, backups and publication-validation scratch are accounted
separately, with file counts, logical and allocated bytes **per directory identity**.
These totals include protected data; join identities to cleanup's protected/reason
observations for inspection. Directory walking measures existing occupation only;
it does not derive the app-required file set. `st_blocks` is diagnostic and can
overcount APFS shared extents; actual free space decides admission. No CoW savings
or historical **3.963 GiB** dataset total is assumed. Reserve covers metadata and
headroom, not a promise against unrelated concurrent disk consumption; copy errors
still fail ineligibly with context.

On insufficient space, the failed stage is recorded, no protected data is deleted,
and capture cannot become eligible. Free unrelated storage or expand the configured
local volume; run safe controller cleanup to reclaim only unprotected material,
then rerun the audit/refresh. Do not force-remove active/recovery/native data,
merge incoming into active, or use SMB fallback.

## Inspection and recovery

`status.lastPolicyReports` and `logs/{cleanup,space,receipt,source-production}.json`
expose observed timestamps, protected identities/reasons, planned/completed pruning,
unresolved operation/release IDs, receipt confirmation, low-space context and blocked
source production. These are **last observations**, not fresh liveness authority.

- **Busy:** inspect the same operation; defer while an inherited lifetime lock is
  held. Do not remove lock files or start duplicate remote/local work.
- **Unknown outcome:** bounded inspection/reconciliation of the original operation
  must confirm ownership ended and durable success/failure. Then use the existing
  owner `reconcile` command before retrying conflicting work. Incomplete canonical
  publication still requires guarded source recovery, independently of cleanup.
- **Lost acknowledgement:** retry `Replica.acknowledge` with the same validated
  receipt. Source returns its previously stored exact receipt, even after an old
  export is pruned; confirmed local receipt retry is also a no-op after local pruning.
- **Unidentified capture:** inspect producer/request evidence and reconcile its
  identity through the controller; absence of a controller flag is not release.
- **Unsupported metadata:** select/register a compatible installed reader/writer
  before resuming. Do not edit versions/digests or remove retained data to bypass it.

Disposable Python tests and Python/Dart lock integration cover retention, races,
native-owner lifetime, crash release, unknown surviving work, receipt failure/retry,
bounded production and both hosts' low-space accounting. Automated checks use no
live canonical Mapping, SMB, credentials, API keys or personal databases. Physical
power-loss durability, multi-gigabyte allocation and installed transport/runner
behavior remain explicit commissioning evidence.
