# Installed Mapping pipeline releases

Spec 0063 Item 07 implements the [reviewed v1 contracts](mapping-runtime-replica-contracts.md#compatibility-and-installed-release-contract).
The mini is the canonical Mapping data store owner. These tools install executable
artifacts and local protocol metadata; they do not publish canonical datasets.

## Artifact and machine boundaries

Each machine has one installation base, normally
`~/.local/share/peak-bagger-mapping-releases`, with:

- `releases/<UUID>/`: frozen complete Python modules, compiled Dart executables,
  required shell helpers/fixtures and `release.json`.
- `selected.json`: one atomic release/manifest-digest/peer/data-base tuple.
- `selection-transaction.json`: durable old/new selection intent until recovery.
- `uses/<operation UUID>.json` and `.lock`: durable invocation evidence and an
  inherited OS lifetime lock; `launcher-uses/` similarly protects the manager.
- `mapping_release_launcher.py`: stable stdlib-only dispatcher. It pins/verifies
  the selected manager before importing it. It is deployed idempotently; a
  differing dispatcher protocol is reported as drift, not overwritten.

The MacBook role is `controller`; the mini role is `source-preparer`. The data
base is **disjoint** from the installation. MacBook default app data base is
`~/Library/Application Support/com.example.peakBagger/MappingRuntimeReplica`;
mini source state/export base is `~/.local/share/peak-bagger-mapping-source`.
Other configured local replica bases must match the app's machine-local
`mapping-runtime.json`. Installation rejects canonical Mapping, the three
source-workspace roots, and incoming/payload/generation namespaces.

The controller includes the source dataset validator AOT executable. The source
preparer additionally includes AOT promotion/restoration/tool-contract/fingerprint/
theLIST/ELVIS/non-store-path executables, the internal theLIST shell helper, and
the three retained contract fixtures. An exact installed `bin/dart` shim maps
reviewed `dart run tool/<name>.dart` publisher prefixes to these AOT executables;
it cannot run arbitrary Dart source. Fixtures and resolver helper paths resolve
inside the pinned release. Publisher scratch goes to `<data base>/preparation`
through `MAPPING_PREPARATION_BASE`, never the frozen release or a checkout.

Build-time package resolution uses the project's existing Flutter/Dart and sibling
dependencies, including `pubspec.lock`; AOT embeds the executable Dart/package
closure. Installed invocation needs no Flutter SDK, Pub cache, package config,
source checkout, or ObjectBox database. The validator opens no ObjectBox store.

Stable documented host prerequisites are macOS/arm64 for the currently built
artifacts, Python **3.10+**, system POSIX/SSH tools, and local Homebrew GDAL/PROJ.
Release dependency inventories hash the concrete interpreter, standard-library
source/native modules, GDAL command executables, recursive non-system GDAL dylibs
(including loader aliases), and `proj.db`. The installed environment pins
`GDAL_LIBRARY_PATH`, `PROJ_DATA` and GDAL command PATH, removes ambient Python
package-path/user-site injection, and retains only basic user/locale/temp values.
System macOS libraries/tools remain OS prerequisites.

Keep these versioned host dependencies in place while invocations own a release.
Do not remove old uv/Cellar runtimes, run Homebrew cleanup, or patch them in place
while their releases have live/unresolved owners. Host-dependency replacement
requires new host sealing and compatibility inspection. Drift fails before stage
dispatch. This is not a package-manager interception or a promise that arbitrary
external deletion of machine dependencies can be recovered automatically.

## Build, host sealing and install

Build on a complete, locally resolved checkout. Installation assembly may use
source; **installed** invocation cannot. Generate fresh lowercase release UUIDs
for changed bytes. The source and controller explicitly list each other's UUIDs,
and retain identities still present in generations/operations. Both roles keep
schemas `1`, profile `mapping-runtime-v1`, reader
`e442ea38-fc1d-4ca0-b07d-223b01df6c35`.

```sh
# Run once per role; use fresh external bundle directories.
python3 tool/mapping_releases.py build \
  --role controller --release-id "$CONTROLLER" \
  --source-release "$SOURCE" \
  --source-release 36363ecc-d359-5591-ba2a-a6a7ffff0e60 \
  --controller-release "$CONTROLLER" \
  --controller-release fb5e6371-026c-5381-8994-eb5d74a17321 \
  --output "$HOME/MappingReleaseBundles/controller-$CONTROLLER"

# Repeat with --role source-preparer, --release-id "$SOURCE" and
# --output "$HOME/MappingReleaseBundles/source-$SOURCE".
```

Copy a complete source bundle to a new directory on the mini using existing alias
**`mini`**, normal SSH authentication and bounded noninteractive SSH/SCP. Do not
put credentials in a bundle or use a source Mutagen session to deliver installation
metadata. Both current hosts are arm64; cross-architecture transfer requires a
matching target build and verification.

```sh
scp -r -o BatchMode=yes -o ConnectTimeout=10 \
  "$HOME/MappingReleaseBundles/source-$SOURCE" \
  "mini:/Users/adrian/.local/share/source-bundle-$SOURCE"

# On mini, use its stable Python >=3.10, not its old /usr/bin/python3 (3.9).
PYTHON="$HOME/.local/bin/python3.15"
BUNDLE="$HOME/.local/share/source-bundle-$SOURCE"
"$PYTHON" -B "$BUNDLE/tool/mapping_releases.py" seal "$BUNDLE"
"$PYTHON" -B "$BUNDLE/tool/mapping_releases.py" install "$BUNDLE"
```

Use `-B` for uninstalled bundle commands: Python bytecode caches are not release
artifacts. Omitting it can add `tool/__pycache__` and correctly cause an incomplete
artifact-set diagnostic; remove only that uninstalled bundle's generated cache
or deliver a fresh complete bundle, then retry with `-B`.

`seal` verifies the transferred artifact set and records **that host's** dependency
identities in an uninstalled bundle. It does not reinterpret an installed release
or repair missing artifacts. `install` verifies completeness/hashes/dependencies,
copies into external staging, flushes/freezes it, and renames the complete tree.
Matching repeat installs reuse the same UUID; partial, conflicting or drifted
trees fail. Failed install never changes selection. No required metadata is inside
Mutagen incoming staging.

Exchange the resulting small `release.json` manifests outside source/incoming.
They contain no credentials. Select only after checking both manifests and retained
data:

```sh
# MacBook; peer-manifest is the mini's sealed source release.json.
python3 tool/mapping_releases.py select "$CONTROLLER" \
  --peer-manifest "$SOURCE_MANIFEST" \
  --data-base "$HOME/Library/Application Support/com.example.peakBagger/MappingRuntimeReplica"
python3 tool/mapping_releases.py install-launcher

# Mini; run the installed retained manager or the verified external bundle tool.
"$PYTHON" -B "$BUNDLE/tool/mapping_releases.py" select "$SOURCE" \
  --peer-manifest "$CONTROLLER_MANIFEST" \
  --data-base "$HOME/.local/share/peak-bagger-mapping-source"
"$PYTHON" -B "$BUNDLE/tool/mapping_releases.py" install-launcher
```

Use `--base ABSOLUTE_PATH` before the subcommand for a custom installation base.
Selection checks mutual controller/source support, schemas/profile/app reader,
retained eligibility/completion/receipt/operation/session/selection evidence and
the completed retained-generation chain. Unknown combinations fail closed before
selection or reader-registration publication. No protected generation is rewritten,
rehashed at startup, mutated, or deleted to make an upgrade pass.

## Installed commands and inspection

Future maintainer/scheduled commands invoke the stable installed dispatcher:

```sh
BASE="$HOME/.local/share/peak-bagger-mapping-releases"
# MacBook: use its recorded interpreter path, currently:
PYTHON=/opt/homebrew/anaconda3/bin/python3.13
"$PYTHON" -I "$BASE/mapping_release_launcher.py" inspect
"$PYTHON" -I "$BASE/mapping_release_launcher.py" run -- status
"$PYTHON" -I "$BASE/mapping_release_launcher.py" run -- capture "$GENERATION" --transfer-complete

# Existing SSH alias; remote preparation is detached and returns operation identity.
ssh -T -o BatchMode=yes -o ConnectTimeout=10 \
  -o ServerAliveInterval=15 -o ServerAliveCountMax=2 mini \
  '/Users/adrian/.local/bin/python3.15 -I /Users/adrian/.local/share/peak-bagger-mapping-releases/mapping_release_launcher.py run -- prepare'
```

Inspection reports selected upgrade, installed role/manifest/dependency identities,
incomplete/drifted releases, and each invocation's pinned UUID/manifest/owner/data
base. Stage dispatch logs `release`, `role`, `operation` and concrete helper root;
detached logs retain the original stage release ID. It never calls the three-source
readiness/handover gate. Source edits, partial delivery, pauses and machine handover
do not change installed helpers. Existing source session identities/scope/ownership
remain those in [source operations](two-mac-mutagen-operations.md).

The 30-second installed dispatch/inspection budget and 5-second installation lock
wait are noninteractive; detached work keeps the existing 2-hour stage budget,
10-minute no-progress diagnostic and lifetime/data locks. Expiry is an unknown
outcome, not success or permission to delete binaries. Item 08 adds the 60-second
LaunchAgent, transport integration and pipeline-wide scheduling/reconciliation.
App startup only reads local v1 `reader-compatibility.json` and generation evidence;
it never runs/verifies remote binaries or installs dependencies.

## Upgrade, interruption recovery and retirement

1. Build/seal/install fresh UUIDs without replacing old release trees. Preserve
   explicit support for every UUID still represented by retained data/work.
2. Exchange freshly inspected peer manifests and `select` the supported pair.
   Selection writes durable prior/next intent, publishes the next tuple atomically,
   then persists commit. Already pinned invocations keep old helpers/commands and
   inherited locks. An uncommitted transaction recovers the complete prior tuple;
   committed intent recovers the complete next tuple.
3. MacBook selection registers v1 source/controller identities outside payloads for
   the shipped app reader. Failed selection may leave a compatible registration
   ahead of selection, which grants no eligibility itself; old evidence remains
   readable. Unknown schema/profile/reader registration is rejected locally.
4. After an interrupted controller/SSH/client, inspect the **original** stage UUID:

   ```sh
   "$PYTHON" -I "$BASE/mapping_release_launcher.py" run \
     --target-operation "$OPERATION" -- status
   # Only when the original stage's lifetime lock is free:
   "$PYTHON" -I "$BASE/mapping_release_launcher.py" run \
     --target-operation "$OPERATION" -- reconcile
   "$PYTHON" -I "$BASE/mapping_release_launcher.py" reconcile-release "$OPERATION"
   ```

   On mini, issue the same installed commands over bounded SSH. A successful stage
   requires its exact durable generation/publication outcome witness. Missing stage
   evidence can become a failed, never-dispatched use only after both invocation
   and dispatch/pipeline locks are free. Running/unknown stages must reconcile first.
   A live inherited child/remote supervisor prevents release reconciliation even
   after controller or SSH-client exit. Never unlink lock files or steal another
   operation identity. A free PID alone is not authority.
5. Retire only an unselected release with no live manager/invocation lock and no
   unresolved use. Explicit command:
   `"$PYTHON" -I "$BASE/mapping_release_launcher.py" retire "$OLD_RELEASE"`.
   Dataset cleanup is the separate Item 06 controller policy. Retirement cannot
   touch active/recovery payloads, export receipts or source sessions.
6. Safe rollback is `select` of a retained release that still supports the **current**
   peer and retained records, using the same preflight/atomic procedure. If an old
   release lacks a now-used UUID/profile, build a compatible v1 rollback release.
   Do not hand-edit schema/UUID records or silently regenerate old eligibility.

If the stable dispatcher reports pending selection recovery, invoke a known retained
manager explicitly with `--base "$BASE" inspect`; it recovers the transaction before
normal dispatch. Drifted artifacts/dependencies remain diagnosed; recover the real
matching bundle/dependency or select a verified compatible release. No automatic
source-workspace execution fallback exists.

## Verification and installation evidence

Disposable Python tests cover complete/repeatable installation, omitted/partial
artifacts, helper/dependency drift, failed and post-rename-interrupted upgrades,
old/new pins, surviving children, explicit reconciliation, incompatible retained
schemas and preservation, source-checkout unavailability, installed source
inspection and detached local capture. Flutter tests consume registered UUIDs
locally and exercise the real installed AOT validator/GDAL profile on generated
tiny rasters, including every malformed-payload category.

Live installation identities, actual paths/prerequisites and command outcomes are
recorded in Item 07's completion evidence. These checks do not claim Item 11's
multi-gigabyte refresh, live handover, power-loss or performance commissioning.
