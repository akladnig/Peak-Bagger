---
type: Work Item
title: Admin live Search and coordinated mutation recovery
parent: ../spec.md
---

## What to build

Complete immediate local Admin Search without deriving selected record/editor/draft lifetime from filtered membership. Coordinate existing Save/Delete ownership from the first awaited step through confirmations, domain synchronisation, refresh and permitted recovery, including retained-shell navigation protection. Preserve existing Data/mutation coverage, matching fields, relationships and domain transaction boundaries.

## Required context

All paths below are relative to the project root; read the standard, then the profile, before feature context.

- `ai_specs/coding-rules.md` — ADS-1.0, revision 2026-10-13, amendment 2026-10-19 and supplements 2026-10-20/21; `ai_specs/app-profile.md`, `AGENTS.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0069-shared-text-fields-and-dropdown-alignment/spec.md` — R1–6, Technical Decisions 2–6, Testing Strategy 2–4/11–12 and refinement decisions 1/4.
- `ai_specs/peak-lists/0069-shared-text-fields-and-dropdown-alignment/interview-ledger.md` — L1/L5/L6; sibling item 01's shared presentation.
- `lib/providers/objectbox_admin_provider.dart`, `lib/providers/objectbox_admin_save_provider.dart`, `lib/services/objectbox_admin_repository.dart`, `lib/screens/objectbox_admin_screen.dart`, its controls/details/table files and `lib/widgets/objectbox_admin_form_field.dart`.
- `lib/router.dart`, `lib/widgets/side_menu.dart`, `lib/widgets/shell_destination_keyboard.dart`, `lib/core/widgets/popup_keyboard_dismiss.dart` and current editor/service/repository equivalents.
- `lib/services/gpx_track_repository.dart`, `lib/providers/map_provider.dart` (`deleteTrack`) and the current PeaksBagged synchronisation boundary; existing six deletion handlers, relationship guards and confirmation helpers.
- `ai_specs/peak-lists/0068-objectbox-admin-schema-and-field-policy/spec.md`, `work-items/05-cancel-save-and-retained-shell-navigation-locks.md` and `implementation-05-verification.md` within that folder — completed retained-shell/same-turn Save guards, five-editor cancellation and field/viewports.
- `test/providers/objectbox_admin_provider_test.dart`, `test/services/objectbox_admin_repository_test.dart`, `test/harness/test_objectbox_admin_repository.dart`, `test/widget/objectbox_admin_shell_test.dart`, existing Admin browser/cancellation/save-provider tests and Admin robot regressions.

## Acceptance criteria

- [x] Preserve `/objectbox-admin`, all-persisted-entity Schema coverage and existing selected-subset Data/mutation coverage. No new loaders/editors/delete capability or broad sorting redesign is added. Schema-only `RouteGraphImportMetadata`, `TrackReplacementRecoveryIssue`, `PeakRegionFingerprint`, `TrackDateMigrationMetadata` retain current Data availability; existing ID-based versus shared name/title sorting remains a separately scoped alignment gap, not a claimed completion.
- [x] Every accepted Search edit immediately filters committed local records without debounce/submission. Enter/keyboard Search also applies current query; clear/whitespace restores otherwise eligible rows. Preserve raw field text, trimming/case-folding only matching criteria. Use complete display values, not grid previews or missing-value placeholders, and preserve exactly the following matching sets through a deterministic production/fake seam (not the narrower generic fallback):

  | Data entity | Searchable fields / resolved values |
  | --- | --- |
  | Peak | `name`, `altName` |
  | NaturalFeature | `name`, `altName`, `tag`, `osmType`, `osmId` |
  | Contact | `firstName`, `surname`, `nickname` |
  | PeakList | `name` |
  | Tasmap50k | `name` |
  | GpxTrack | `trackName` |
  | PeaksBagged | `gpxId` |
  | PeakListItemEntity | Related Peak List name, related Peak name, `id` |
  | Waypoints | `name`, `type`, `mgrs` |
  | Route | `name`, not Description |
  | RouteGraphChunk | `chunkKey`, `recordKey`, `payloadJson` |
  | RouteGraphWayIndex | `recordKey`, `chunkKey`, `highway`, `surface`, `footway`, `foot`, `route`, `access`, `name`, `normalizedName`, `tagsJson` |
  | RouteGraphTrailDisplayChunk | `recordKey`, `chunkKey`, `payloadJson` |
  | RouteGraphManifest | `sourceHash`, `schemaVersion`, `readinessState`, `lastError` |

- [x] Typing, clearing, Enter and focus/select-all retain selected identity, open details/editor and the sole unsaved draft even when no rows match or the selected record leaves results. Read committed records, not draft contents; never save/cancel/close/retarget/navigate as a Search side effect. Existing-record successful Save retains same-record details outside the matching results. Keep query, result rows, committed selected projection and draft lifetime independent with existing Riverpod/data boundaries, not widget-side Store writes.
- [x] Retain read-generation safeguards so obsolete results/errors cannot replace newer entity/query reads. Keep loading, entity-empty, no-matches and retryable-error states distinct and recover without discarding the editor/query. Preserve current entity/mode reset and sort policies and deterministic ordering; Search must not invoke those reset policies.
- [x] Admin Data Search inherits shared decoration, shows exactly **Search ⌘F**, retains a context-specific accessible name and has only a decorative leading `Icons.search` at `searchControlIconSize = 24.0`; remove the trailing Search submit action and associated tooltips. The icon has no action, button semantics, focus stop or pointer-action affordance. Persistent label remains readable; if inline/floating design is chosen, only empty/unfocused inline cue uses disabled foreground, floating label stays `onSurface` and entered text is not dimmed.
- [x] Cmd+F focuses/selects all current raw text only for eligible active Admin Data Search, without query/selection/draft changes. Do nothing in Schema, when unavailable/disabled/Save-or-Delete locked, off-route or behind a dialog/dropdown/drawer/focus-owning picker. Do not change mode/route, steal another surface's focus or queue/replay blocked actions. Check current eligibility before focus/scroll, including captured callbacks; preserve normal editing/Cmd+C and dropdown-first ownership.
- [x] Extend the established authoritative Save lifetime deliberately into coordinated mutation protection, not separate Search/widget pending flags. For existing Peak, NaturalFeature, Contact, GpxTrack, Route and Waypoints deletion actions acquire the Delete gate before first awaited confirmation/preparation; reject attempts while Save or Delete is pending. Hold through confirmation, preparation, mutation, existing domain synchronisation and refresh; release on cancellation, relationship blocking, completion or failure.
- [x] While Delete is protected, lock parent Search/Cmd+F, editable/associated controls, row/entity/mode/sort selection, other mutations including Save, parent cancellation/dismissal and Admin departure. Extend actual retained-shell Save protection to Delete: side-menu/shell actions, supported keyboard/back and programmatic/named/branch/replacement departure before and after rebuild, including same-turn attempts. Blocked actions never replay. Keep child **Cancel / Delete**, permitted child dismissal and blocker/error acknowledgement usable without parent cancellation/navigation cascade; do not invent a new idle panel-dismiss binding.
- [x] Save or Delete pending disables Search and rejects captured typing/clearing/Enter/focus/selection callbacks at the current authoritative boundary before rebuild. Existing Admin field/selector draft owners, locks and input types remain correct, including signed-decimal Peak latitude/longitude, signed-integer Peak elevation and Route's signed-decimal elevation parsing, with unchanged ranges/storage precision. Preserve Spec 0068's five editors' Cancel / Save, recoverable input retention, policy-gated controls, measured five-line read-only values and retained shell.
- [x] Confirmation Cancel, relationship blocking and failure before confirmed deletion retain query, selected identity, details/editor and sole draft. Confirmed deletion clears details/draft only for the deleted selected record; deletion of another record preserves unrelated selection/draft regardless of filtered membership. Preserve current deletion relationships/coverage, domain operations, idle discard/re-entry and persistence boundaries.
- [x] Record confirmed storage removal separately from later synchronisation/read outcomes. In particular, GpxTrack removal followed by `mapNotifier.deleteTrack` remaining-Track read/PeaksBagged synchronisation failure is not failed/rolled-back deletion. Keep the deleted record unavailable in details/editing, preserve unrelated query/selection/draft and explain completed deletion versus incomplete synchronisation/refresh. Offer labelled **Retry** for only incomplete follow-up, never deletion/confirmation/already completed destructive work. Recovery acquires the same early gate, releases on success/failure and retains actionable feedback after repeated failure. Add no Background Jobs Retry or transaction redesign.
- [x] Provider/repository tests exercise all 14 matching sets, long full values beyond previews, absence of placeholder/extra-column matches, raw/trimmed query handling, immediate typing/clearing/Enter, stale success/error rejection, existing ordering and selected projection independent of rows. Browser/widget/robot regressions retain draft through exclusion/zero matches, Enter/clear/Cmd+F and successful Save outside results, matching committed not edited content.
- [x] Controlled-future tests cover all six deletion actions, early gates, duplicate/stale callbacks before/after rebuild, usable child Cancel/acknowledgement, relationship blocking, failures and success. Through the real routed shell verify parent action/input/selection/sort/dismissal and shell/keyboard/back/programmatic guards with no replay. Inject successful Track removal then synchronisation failure, and separately later Admin refresh failure; Retry performs only incomplete work, never delete/confirmation, and repeated recovery failure safely releases/retries without restoring deleted-record editing.
- [x] Apply ADS-1.0 and Desktop wide/macOS-only at 1280 × 960 and representative larger sizes, default/enlarged text, light/dark/custom themes and draft-preserving resize/native input. Keep errors/actions reachable without downscaling, compact/iOS layouts, new breakpoints or native window/full-screen changes; launch target stays maximised. Preserve ObjectBox/Riverpod/GoRouter; no entity/model/generated-file changes or schema migration.
- [x] Use deterministic mutable repositories, Riverpod overrides, preference fakes and routed-shell seams; no live services/credentials/user DB/Mapping volumes/other checkout. Follow README native prerequisites for genuine temporary-ObjectBox tests, closing before cleanup; dispose owned resources. Run focused provider/repository/browser/shell tests, existing affected robot regressions, `flutter analyze` and full `TZ=Australia/Hobart flutter test --reporter expanded`. Record native rendering/input separately from automated results, failures/blockers and human review; no new TDD/journey framework or template-parity claim.

## Covers

- User Stories: 1, 2, 3.
- Requirements: R1; Admin scope of R2–3; R4; Admin scope of R5; R6, especially R6.4–6.
- Technical Decisions: 2–6.
- Testing Strategy: 1–4, 9–12 as applicable to Admin fields, Search, locks and selectors.
- Interview Ledger: L1, L5, L6.
- Approved refinement decisions: 1, 4.

## Blocked by

None — item [01](01-shared-field-and-dropdown-presentation.md) is complete.

## Implementation evidence

Completed 2026-10-21. All 15 acceptance criteria are verified; see
[Work Item 02 verification](../implementation-02-verification.md) for ownership,
matching sets, real routed-shell/controlled-future coverage, **2850 passing tests
(7 inherited skips)**, static analysis and **24 native rendering/text-input/resize
configurations**. Native Command-modifier injection remains unverified on this
host; Cmd+F's behavior is covered by routed widget tests, not claimed as a native
modifier Pass. No human visual or template-parity acceptance is claimed.
