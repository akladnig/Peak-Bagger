# Moving the development drive to the Mac Mini

Discussion recorded on 7 October 2026.

> **Superseded Git ownership/workflow:** The historical mini-owned Git example
> below and its unresolved ownership questions are superseded by L1/L2 of the
> [MacBook/mini Spec](../ai_specs/peak-lists/0062-macbook-mini-mutagen-development/spec.md).
> The selected workflow has **MacBook-owned Git for all three projects**; follow
> the [handover, SSH Git and conflict-recovery guide](two-mac-mutagen-operations.md).
> This discussion is retained as history.

## User's question

> I now want to move my directly attached drive with `/Volumes/Development`, `/Volumes/Services` etc. to my Mac Mini, but obviously want to continue development on this MacBook (and also on the Mini). Previous discussions have suggested that Mutagen would work. Advise.

## Advice

**Mutagen can work well for this, but the key decision is how you want Git to work across the two Macs.** It is excellent at keeping working files synchronised—including uncommitted changes—but it does not make two development environments into one shared Git repository.

For this setup, keep the drive attached to the Mini, use local storage for development on the MacBook, and choose the synchronisation model per project.

### Recommended layout

| Content | Mac Mini | MacBook | How to share it |
|---|---|---|---|
| Active development projects | On `/Volumes/Development` | Local SSD, e.g. `~/Development` | Git, or selected Mutagen sessions |
| Service configuration/source | On `/Volumes/Services` | Local copy where useful | Git or carefully scoped sync |
| Running service data: databases, container state, logs | On the Mini | Access through the service | Keep runtime data on the Mini |
| Large datasets/assets | On the attached drive | Selected local copies | Separate sync or SMB access |
| SDKs, dependencies, build caches | Installed/generated locally | Installed/generated locally | Recreate independently |

**Mutagen stores an actual local copy.** The editor, compiler and file watchers use the MacBook’s SSD, so development remains responsive and works offline. Changes synchronise over SSH when the Mini is reachable.

An SMB share is useful for accessing bulk files, but local working directories are preferable for Flutter/Xcode development.

### The important Git limitation

There are two sensible ways to organise development.

#### 1. Independent Git clones on both Macs

This is the default recommendation **if you want to commit, switch branches and use coding agents normally on either machine**.

- Each Mac has its own clone and `.git` directory.
- Use Git push/pull to transfer committed work.
- Use a temporary/WIP branch when handing unfinished work between machines.
- Each Mac has independent dependencies, build outputs and tooling.

This supports working on different branches—or running agents on both machines—without filesystem synchronisation interfering.

**Do not add continuous two-way Mutagen sync between those same two working trees.** A checkout on one machine would change the files on the other, without changing its Git branch or repository state.

#### 2. One Git repository, with a Mutagen working-file mirror

This is appropriate **if you want your current unfinished work to follow you almost immediately between machines**.

For example:

```text
Mac Mini
/Volumes/Development/mapping/peak_bagger
    ├── .git       ← Git operations happen here
    └── source     ← synchronised working files
                       ⇅ Mutagen over SSH
MacBook
~/Development/mapping/peak_bagger
    └── source     ← local editing, builds and tests
```

Here, “source” represents the project's working files rather than a required directory name.

- Use `two-way-safe` synchronisation.
- Exclude `.git` from synchronisation.
- Edit and build on either Mac.
- Run Git operations on the Mini, locally or over SSH.
- Hand work over between machines rather than modifying the same project concurrently.

The trade-off is that the MacBook mirror is **not an independent Git checkout**. Editor Git integration, tools that require repository metadata, and coding agents’ Git workflows may need adjustment. You can edit and build offline, but Git operations against the Mini need connectivity.

Mutagen’s own [Git guidance](https://mutagen.io/documentation/synchronization/version-control-systems/) explicitly recommends one VCS-owning endpoint and warns against continuously synchronising two independent clones—even when `.git` is excluded.

**Do not continuously synchronise `.git` itself.** Git’s index, locks and object-store maintenance are unsuitable for this.

### If using Mutagen

Start with **one session per active project**, rather than immediately mirroring all of `/Volumes/Development`.

For a Flutter project, typical exclusions would include:

- `.git`
- `.dart_tool`
- `build`
- Platform-generated dependency/output folders such as `ios/Pods` and ephemeral directories
- `.DS_Store`
- Machine-specific SDK links and caches

Keep source files and relevant lockfiles synchronised. Generate dependencies separately on each Mac. Mutagen’s ignore rules need explicit configuration; it does not automatically use the project’s `.gitignore`.

Use **`two-way-safe`**, which reports conflicting edits rather than choosing one machine’s version automatically. Ordinary deletions still propagate, so synchronisation needs a separate backup.

Before switching machines:

1. Save changes.
2. Flush the project’s Mutagen session.
3. Check that it has no conflicts or errors.
4. Continue on the other machine.

Run the controlling Mutagen daemon on the MacBook with automatic startup. The Mini needs SSH/Remote Login; Mutagen deploys its remote agent automatically. For access away from home, a private network such as Tailscale is a convenient way to reach the Mini.

### Moving the drive and handling paths

The physical move should preserve paths such as `/Volumes/Development` **on the Mini**, provided the volumes mount under the same names. The MacBook will need new local paths.

Use `~/Development` on the MacBook. If existing tooling hardcodes `/Volumes/Development`, identify those references and decide whether to update them or provide a deliberate compatibility path. `/Volumes` is managed by macOS, so plan this rather than creating an ordinary directory there casually.

A practical migration sequence is:

1. Back up the drive and inventory active projects, uncommitted work and path dependencies.
2. Prepare the MacBook’s local project copies while the drive is still attached.
3. Stop services using the drive, eject it, and attach it to the Mini.
4. Verify mount names, permissions, SSH access and service startup.
5. Pilot the chosen workflow with `peak_bagger`, including a build on each Mac and an offline/reconnect test.
6. Extend it to other projects.

For `/Volumes/Services`, the contents matter: configuration files are good sharing candidates; live databases and container storage should remain owned by the services on the Mini.

### Overall recommendation

**Use independent Git clones for projects actively developed on both Macs, and Mutagen selectively where live working-file mirroring is more valuable than independent Git operation.** Keep services and their runtime data on the Mini, and use SMB for convenient access to large files.

If the goal is specifically “open either Mac and find exactly the same unfinished project”, Mutagen can provide that—with one Git-owning machine and a clear handover workflow.

## Questions still to resolve

1. Do you want full local Git/agent workflows on both Macs, including offline commits, or would Git living on the Mini be acceptable?
2. Is `/Volumes/Services` primarily configuration/source, or live service data?

Those two answers determine the best setup. No final workflow choice or migration has been made in this discussion.

## References consulted

- [Mutagen file synchronisation](https://mutagen.io/documentation/synchronization/)
- [Mutagen version control systems guidance](https://mutagen.io/documentation/synchronization/version-control-systems/)
- [Mutagen ignore configuration](https://mutagen.io/documentation/synchronization/ignores/)
- [Mutagen safety mechanisms](https://mutagen.io/documentation/synchronization/safety-mechanisms/)
- [Mutagen symbolic links](https://mutagen.io/documentation/synchronization/symbolic-links/)
- [Mutagen SSH endpoints](https://mutagen.io/documentation/transports/ssh/)
