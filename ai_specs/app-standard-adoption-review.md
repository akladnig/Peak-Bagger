# Peak Bagger App Development Standard adoption review

**Date:** 2026-10-13

**Adopted revision:** ADS-1.0, [local App Development Standard](coding-rules.md).

**Deliverables:** existing local standard copy, [Desktop wide app profile](app-profile.md), and [root AGENTS instructions](../AGENTS.md).

**Authoring source:** starter Spec 0002 and Work Item 03 — Adopt the same standard revision in Peak Bagger. These historical cross-project authoring artifacts are not downstream planning prerequisites. Required local inputs are the standard/profile, affected workflow artifacts, glossary, and relevant project docs.

**Verification surface:** documentation/source review, byte/revision equality, local Markdown references/anchors, relocated documentation-only references, and unchanged-file checks. Publication does not execute Flutter analysis/tests/builds, generation, databases, robot journeys, or the five ACT commands. Runtime verification belongs to affected implementation Specs.

## Acceptance-criteria coverage

Numbers follow the Work Item's 15 checkboxes in order.

| Criterion | Evidence and result |
| --- | --- |
| 1. Exact standard copy | `ai_specs/coding-rules.md` is byte-for-byte equal to the canonical ADS-1.0 starter document, including revision/provenance. The existing local path is retained with no competing root copy. |
| 2. Desktop wide profile | Profile declaration table specifies macOS-only, wide desktop, maximised launch, separate resize/native-mode/minimum fields, and no required narrow navigation. Native full-screen is not inferred from maximisation. |
| 3. Pending versus observed values | Width/height/native-mode/resize choices remain explicitly named Pending. Inspected native code sets minimum content `1024 × 0` and zooms on launch; these are observations only. Publication passes; dependent layout/dimension-dependent criteria remain gated. |
| 4. Correct platform scope | Wrong old macOS+iOS/compact statement is replaced. The shared copy defines both profiles, but Peak Bagger selects only Desktop wide; no iOS builds, touch-layout obligations, compact verification or narrow-shell migration is introduced. |
| 5. Domain conventions retained locally | Profile preserves number/date helpers, metric mapping units, Track/Route terminology and `Unknown`, six-decimal coordinate/GPX precision, domain palettes, mapping zoom/history controls and local icons/assets. Missing import.svg is reported, not adopted as a dependency. Dataset paths are not embedded in the reusable contract. |
| 6. Portable required documents | Root AGENTS links local standard/profile/glossary; code locations are optional evidence/examples, not adoption prerequisites. The absolute source-read rule is removed; no master-path read is required. |
| 7. Local ACT wiring/storage | AGENTS requires standard then profile then affected Spec/ledger/Work Item/domain docs. Its original ACT section is preserved; `.act/config.yaml` retains local storage `ai_specs/peak-lists`; workflow semantics/global skills remain untouched. |
| 8. Five-stage matrix | AGENTS stage instructions and profile matrix cover interview reading/pending choices, exact Spec capture, refinement conflicts/gates, root-relative Required context/acceptance criteria in Work Items, and implementation/verification. A local minimum-height paper walkthrough demonstrates all five stages. |
| 9. Contract distinctions/governance | Standard rules, Desktop wide obligations and app decisions are separate; ObjectBox/Riverpod/GoRouter remain mandatory. Proposed exceptions carry rule/reason/scope/features/status; L10 approval policy remains provisional/non-blocking, not presumed accepted. |
| 10. Revision adoption and runtime gaps | Profile documents deliberate local-copy/revision updates and source-observed button/semantic-colour/sizing/ownership/Admin gaps. Publication claims documentation adoption only and introduces no synchronisation/setup/shared-package features. |
| 11. Written foundations/visual contracts | Equal canonical copy retains mandatory foundations; seed #7E47EB/vibrant/0.0; named spacing 4/8/12/16/24/32; radius 12; 48 × 48 touch targets only for touch profiles; FilledButton pairing in both modes, footer primary/Cancel/Close and allowed accessible header IconButtons. |
| 12. Components and actual callers | Source review confirms cursor/field/FAB/icon/focus/dismissal/scrolling contracts and live Import Peak List/Peak Info callers. PeakListCreateDialog has only its declaration/state references. Feature/domain behaviour is not universalised. |
| 13. Admin implementation contract | Copied §8 requires entity enumeration/all-versus-subset choice, trailing Delete, central row/header and all interaction states, selected labelled Edit/Close details, and full selectable independently scrollable five-line viewports measured with style/scale/width. Current maxLines:5 and hard-coded red are gaps, not verification. |
| 14. Future deterministic guidance | Copied §9/profile Admin section retain selection/Edit/Save/Cancel/retention and declared delete/relationship/confirmation coverage, beyond-fifth-line scroll/selection checks, temporary stores or repository/provider fakes, cleanup, and unit/widget/conditional-robot guidance. No universal TDD/robot mandate. |
| 15. Full documentation review | This review covers parent Spec/ledger, exact-copy and local/relocated references, profile/Pending/native-mode scope, ACT matrix, source conflicts and unchanged runtime/workflow boundaries. Local planning works without the starter source directory. |

## Source and conflict review

- **Old rules:** audited before replacement, including their uncommitted absolute read-path/iOS/compact changes. The agreed adoption deliberately supersedes those rules. Shared shortcut/formatter/popup/icon conventions are retained or corrected; domain-only zoom/assets/units/colours live in the profile. No unrelated working changes are staged.
- **Window:** `macos/Runner/MainFlutterWindow.swift` sets `contentMinSize` width `1024`, height `0` and calls `zoom(nil)`. This file has no explicit native full-screen entry; source inspection is not a runtime launch/window test.
- **Theme/sizing:** `lib/theme.dart` confirms seed/vibrant/0.0 and `_filledButtonTheme` used in both light/dark. `DataGridTheme`, `RowHoverTheme`, `ChartSeriesTheme` and mapping styles are distinguished; `lib/core/constants.dart` contains GPX precision `6`, popup radius/padding `12`, and domain metrics; `lib/core/app_sizes.dart` retains ratio `1.25`. Shared semantic/state/token mismatches remain follow-ups.
- **Modal/popup:** `lib/widgets/peak_list_import_dialog.dart` has labelled validation, FilledButton Cancel/Import and pending progress; its live caller in `lib/screens/peak_lists_screen.dart` starts app-owned jobs while leaving default barrier dismissal enabled. Pending starts after duplicate checking, and import failure pops the form. `dialog_helpers.dart` mixes export-conflict footer button types. `PeakInfoPopupCard` has scrollable read/edit content and wrapping Cancel/Save, disposed controllers and header actions; main map supplies edit/save whereas mini-map does not. Fixed dimensions/local typography and all focus/dismissal policies require affected runtime work. `PeakListCreateDialog` has no runtime callers in `lib/`.
- **Keyboard:** `lib/core/widgets/popup_keyboard_dismiss.dart` handles Escape/Ctrl+C and excludes Meta/Cmd+C. Map source recognises scoped zoom controls; the helper does not prove whole-feature locking or text/focus/unsaved-change behaviour.
- **Admin:** `objectbox_admin_screen.dart` routes row selection to notifier state and details. Table trailing Delete is reachable beside horizontally scrolling fields but uses `Colors.red`; `InkWell.focusColor` is transparent. Route details have labelled values/Edit/Close, a Save-only edit footer, header tooltip gaps, and long fields rendered via `SelectableText(maxLines: 5)`. Required independent five-line scrolling/full selection and scaled-height correctness must be implemented and tested explicitly. Enumerate future entity coverage rather than infer it from schema metadata/current mutation dispatch.
- **Ownership/preferences:** `lib/main.dart` opens/injects ObjectBox and closes a partial store on failure. Global store/data calls and test-storage fallbacks in `peak_list_provider.dart` need lifecycle/dependency alignment. Theme provider overrides/preferences tests demonstrate seams, but current silent failure/in-memory retention is not shared async-error compliance. Starter-specific three-state Settings and SnackBar rollback are not imposed on Peak Bagger by adopting the generic standard.
- **Formatters/tests:** `date_formatters.dart` preserves Track calendar components and separately converts compact dates to local; `number_formatters.dart` owns metric/precision/Unknown formatting. GPX export/import corroborates local six-decimal coordinates. Existing formatter/preference/Admin repository/widget/robot tests were read as evidence, including fake/provider and temporary-store patterns; they were not run and do not prove new compliance.
- **Assets:** `pubspec.yaml` declares local `assets/svg/route.svg`; the old import.svg is neither present nor declared, and the live Import control uses `Icons.upload_file`. No new asset requirement is invented.

## Local and relocated-documentation reference verification

Check all Markdown links and heading anchors in AGENTS, the standard, profile, and this review; paths resolve relative to each file and remain within the Peak Bagger root. Check literal required `.act/config.yaml`/`.act/workflow.md` paths and root-relative Required context references. The standard has no required source-master read path.

Repeat the same reference checks with an in-memory relocated documentation tree: root AGENTS/GLOSSARY, ACT files and the three `ai_specs/` adoption documents. The alternate root has no runtime source or original master repository. Every required adoption link resolves inside that tree. Code filenames are evidence only and are not copied as required inputs. This checks portability of the read chain without claiming to execute ACT stages or runtime behaviour.

Canonical/adopted standard Git blob: **`95b58df71540adc3c30a9d1d1e44a3887f2653d8`**. Verify both byte equality and the `ADS-1.0 — 2026-10-13` revision line.

Preservation checks:

| File | Unchanged Git blob ID |
| --- | --- |
| Peak Bagger `.act/config.yaml` | `92ed16608cd6f39dbe586744fa7ea33e42459087` |
| Peak Bagger `.act/workflow.md` | `efe26243b73fae4906bcdd8052c43420c18c3f33` |
| Starter `coding-rules.md` | `95b58df71540adc3c30a9d1d1e44a3887f2653d8` |
| Starter Spec 0001 | `e63cd9d145847a1bbd750bdbc77eb79d9021a5f2` |
| Starter `.act/config.yaml` | `4d0d00a22039bc17ce8b1e4b5cac9091148a8dbf` |
| Starter `.act/workflow.md` | `efe26243b73fae4906bcdd8052c43420c18c3f33` |

## Spec and ledger coverage

- **User Stories 2–5; Requirements 3–5, 13, 15–16, 34–37:** portable Peak Bagger local adoption, Desktop wide/platform corrections, Pending publication/gating, five-stage instructions, provisional governance and deliberate updates.
- **Technical Decisions 1–2, 4, 6–7; Testing Strategy 1–6, 8–10:** separately scoped Peak Bagger Markdown work, preserved local path/repository boundaries, audited source examples and numeric/component contracts, reference/equality/matrix/documentation checks.
- **L2–L4/L6–L7/L12–L14:** written standard versus runtime, local distribution/ACT, Desktop wide versus native mode, corrected scope and observed/Pending separation. **L9/L15/L17:** FilledButton footer/pairing and complete component contracts. **L18:** five-stage matrix and paper walkthrough. **L19:** copied Admin contract and future deterministic verification. **Deferred L10:** full governance remains unconfirmed.
- **Follow-Up 2:** later Peak Bagger alignment is documented, not implemented. **Note 3:** documentation is owned directly by the Peak Bagger app repository. Required foundations/visual contracts from L1/L5/L8/L11 are preserved through canonical-copy equality.

## Verification outcome

All 15 documentation criteria pass the acceptance review. The adopted copy equals the canonical bytes/revision, local and relocated-documentation links/anchors resolve, named Pending choices remain distinct from observed source values, and ACT/standard/starter-Spec preservation checks pass. Git whitespace checks pass for intended changes.

The Peak Bagger app repository owns AGENTS, the profile/review, the local standard copy and its workflow artifacts. `ai_specs/` is an ordinary project directory; do not create or use an independent Git repository there. Review/stage intended documentation without adding unrelated runtime work. The starter repository owns Work Item 03 and its local completion review; parent Spec/ledger remain in their original storage.
