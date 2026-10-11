---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What development layout should this change support?

Answer: Peak Bagger exists under both `/Volumes/Development` and `~/Development`. The home-directory copy is up to date. The external volumes will move to the Mac mini, while development should remain possible on both machines, primarily the MacBook.

Decision: Treat `~/Development/mapping/peak_bagger` on the MacBook as the initial authoritative working copy and `/Volumes/Development/mapping/peak_bagger` on the mini as its synchronized working-file mirror.

Constraints:
- Preserve the external volume names and project layout on the mini.
- Initial synchronization must not let the older external-drive copy overwrite current MacBook work.

### L2

Status: current

Question: Should switching machines provide the same unfinished edits or an independent local Git workflow?

Recommended Answer:
- Synchronize uncommitted source edits in both directions.
- Edit, build, and test locally on either Mac.
- Execute commits, branch changes, merges, and rebases only in the MacBook checkout.
- The mini mirror has no active `.git` directory.
- Git operations initiated on the mini use SSH to the MacBook and require it to be reachable.
- Hand development between machines rather than run different branches concurrently.

Answer: agreed - so the .git directory on /Volumes should be deleted?

Decision: The MacBook is the sole Git-owning machine. Exclude `.git` from synchronization and remove the mini copies' active Git metadata from the synchronized project directories.

Constraints:
- The recommended migration default is to move mini-side `.git` directories outside the synchronization roots as temporary backups, after checking for unique commits, branches, stashes, and working-file changes.
- Never continuously synchronize two independent Git working trees or synchronize `.git` itself.
- Do not silently redirect Git operations into a mini-side repository if the MacBook cannot be reached.

### L3

Status: current

Question: How should the MacBook access the Mapping data store after `/Volumes/Services` moves to the mini?

Recommended Answer:
- Mount the mini's Services share over SMB, preserving `/Volumes/Services/Mapping` on the MacBook.
- Keep Mapping datasets outside the project Mutagen sessions.
- Keep each machine's ObjectBox database and build caches local.
- Running the app requires access to the mounted store; editing source remains possible offline.

Answer: agreed - are any files in the mapping data store required in the running app or only in build?

Decision: Use the SMB-mounted Mapping data store for the short-term runtime arrangement, without synchronizing live app databases or bulk Mapping data with project source.

Reason: The running app reads Mapping sources and performs startup preflight; these datasets are not bundled by the build.

### L4

Status: current

Question: Must the MacBook run Peak Bagger when the mini is unreachable?

Answer: in the short term Offline source editing and builds are sufficient, in the long term I will need to run independently offline, so confirm the files needed for this and their size, along with what is easily transferable now.

Decision: Support offline editing and builds now. Preserve independent offline runtime as a future requirement and record the inspected runtime file inventory, sizes, and transfer feasibility in the Spec.

Constraints:
- Do not implement a local Mapping replica or change runtime store discovery as part of this setup.
- The current manifest-referenced runtime set contains 25 files totaling 4,255,657,108 bytes, approximately 3.96 GiB.
- Startup checks readability of all region-manifest dataset references, including all three declared DEMs, even though route elevation currently selects the ELVIS runtime DEM.
- Independent offline runtime also needs suitable offline tiles, personal app data, and local host dependencies.

### L5

Status: current

Question: Should synchronized working-file mirrors also cover `trip_routing` and `flutter_map_tile_caching`?

Recommended Answer:
- Give each sibling project its own Mutagen session and MacBook-owned Git checkout.
- Change Peak Bagger's dependency paths to `../trip_routing` and `../flutter_map_tile_caching`.
- Preserve the same sibling-directory layout on both Macs.

Answer: yes

Decision: Include all three projects in the development setup and replace Peak Bagger's external-volume absolute package paths with relative sibling paths.

Reason: Both sibling packages already exist under the MacBook's local development root, but Peak Bagger's current package declarations still depend on `/Volumes/Development`.

### L6

Status: current

Question: How should synchronization behave through offline use and reconnection?

Recommended Answer:
- Start Mutagen automatically at MacBook login.
- Synchronize saved working-file changes in both directions with `two-way-safe` while connected.
- Retain offline edits locally and synchronize automatically when the mini becomes reachable.
- Propagate ordinary file deletions.
- Report incompatible edits as conflicts requiring explicit resolution; never automatically prefer either endpoint.
- Flush all three sessions and confirm no pending changes, conflicts, or connection errors before handing development to the other machine.

Answer: agreed

Decision: Provide automatic background synchronization and reconnection with explicit conflict handling and a verified three-session handover procedure.

Constraints:
- Conflicts are synchronization outcomes, not permission to overwrite one machine's work.
- A failed flush or unreachable endpoint must not be presented as a successful handover.

### L7

Status: current

Question: How should `dart_defines.local.json` be managed between the two Macs?

Recommended Answer:
- Exclude it from Mutagen and Git.
- Seed a missing valid mini configuration once from the MacBook over SSH.
- Preserve an existing mini copy rather than overwrite it automatically.
- Synchronize `dart_defines.example.json` as the shared configuration-field example.

Answer: agreed

Decision: Keep API-key configuration machine-local, with a one-time secure seed only when the mini lacks a usable copy.

Constraints:
- Do not expose API-key values in logs, documentation, or synchronization configuration.
- Future local edits to the file do not propagate through Mutagen.
