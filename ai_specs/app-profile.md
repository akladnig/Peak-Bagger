# Peak Bagger app profile

## Adoption and authority

- **Selected profile:** Desktop wide only.
- **Adopted standard:** [App Development Standard](coding-rules.md), revision **ADS-1.0** (2026-10-13).
- **Documentation adoption:** published. **Runtime alignment:** partial, with source-observed gaps below; adoption does not verify runtime compliance.
- **Local domain language:** [GLOSSARY.md](../GLOSSARY.md). Read the affected local Spec, Interview Ledger, Work Item, and relevant project docs for feature behaviour.

Apply three separate contracts: mandatory shared rules from the local standard, Desktop wide obligations below, and Peak Bagger domain/feature decisions. ObjectBox is mandatory for persistent domain records, Riverpod for application state/dependency injection, and GoRouter for navigation. Shared preferences owns small preferences separately. Package roles/compatibility are required; starter package pins, deployment targets, Home/Settings routes, and Drawer behaviour do not become Peak Bagger contracts.

**Provisional governance (L10):** report source conflicts; record proposed exceptions with the rule, reason, scope, affected features, and approval status. The full approval/exception policy is unconfirmed and non-blocking for documentation publication. No approval authority/process is presumed settled. A profile entry or existing code does not authorise replacing a mandatory foundation. No intentional shared-rule deviation is approved by this adoption; the gaps below are follow-ups.

## Platform, layout, and window declarations

| Field | Peak Bagger target or decision |
| --- | --- |
| Supported platforms | **macOS only**. Scaffold directories or historical text do not add supported platforms. |
| Layout scope | **Wide desktop only**, with compact rows/toolbars and keyboard/pointer affordances. No required compact/narrow navigation shell. |
| Launch window behaviour | **Maximised on launch**, as required by Desktop wide. |
| Resizing policy | Resizable desktop window; **Pending — supported macOS resize range**, to be settled alongside minimum usable dimensions. |
| Native macOS window mode | **Pending — native macOS full-screen choice**. Launch maximisation does not require entering native full-screen. |
| Minimum usable width | **Pending — minimum usable macOS width**. |
| Minimum usable height | **Pending — minimum usable macOS height**. |
| Compact/wide navigation breakpoint | **Not applicable** to the selected wide-only scope. |
| iOS viewport/Drawer/touch-layout verification | **Not applicable**; iOS and compact/narrow layouts are outside the selected profile. |
| Feature content thresholds | **Pending — feature-specific wide-layout thresholds**, where an affected Spec needs them; not inferred from native configuration. |

**Pending-value gate:** named `Pending` fields pass this documentation release. Resolve the relevant values in this profile and the affected implementation Spec before dependent layout implementation or dimension-dependent acceptance criteria. Unrelated work may proceed. Native minimum content size `1024 × 0` and launch zoom, recorded below, are observations, not approved usable width/height targets. No universal dimensions or adaptive breakpoint are invented.

### Desktop wide obligations

- Keep essential content, labels, values, validation, and actions usable at the declared supported window range and text scales through wrapping or scrolling; a wide but short window still needs height-aware handling.
- Preserve visible keyboard focus/traversal, selection distinct from hover, pressed/disabled feedback, pointer cursors, accessible labels, and tooltips.
- Popup/dialog bodies scroll against actual constraints; header and footer remain reachable. Feature Specs settle unsaved changes, dismissal/locking, save/cancel/retry, and persistence outcomes.
- Scope keyboard navigation to the active surface; preserve text editing and Cmd+C. Apply shared Cmd-based actions and permitted Escape/Ctrl+C dismissal consistently.
- Verification for affected implementation follows macOS/Desktop wide and the affected Spec. This profile adds no iOS builds, touch-target acceptance criteria, narrow-shell migration, or compact-layout checks. The shared standard's `48 × 48` touch target rule applies to profiles supporting touch layouts.

## App-specific domain conventions

These preserve useful Peak Bagger conventions from the old local rules and inspected helpers. Source-observed values are identified as evidence; feature Specs remain authoritative for transformations, storage/export formats, and changed behaviour.

### Theme, tokens, and domain colours

- Shared baseline: seed `#7E47EB`, `DynamicSchemeVariant.vibrant`, contrast `0.0`, Material typography/platform-default fonts, spacing tokens `4`/`8`/`12`/`16`/`24`/`32`, and card/popup radius `12`. No fixed app seed override is selected by this adoption.
- Shared labelled popup/dialog footer primary actions and Cancel/Close use FilledButton with `primaryContainer`/`onPrimaryContainer` in light and dark modes. Accessible header Close IconButtons remain permitted.
- Existing user-selectable seed/scheme/contrast preferences are Peak Bagger-specific Settings capabilities, not requirements for every app. Their presence does not approve incidental non-semantic component overrides or reinstate historical Catppuccin guidance.
- Map/marker/cluster/trail and chart-series palettes remain **domain styling**. Local owners are `lib/theme.dart` and domain constants in `lib/core/constants.dart`: map grid/polygon blue, bagged/unbagged peak colours, cluster fill/count colours, marker colours, `TrailDisplayTheme`, `TrackRouteLineTheme`, `MapChartHoverDotTheme`, and `ChartSeriesTheme` (observed green secondary series `#2E7D32`). Preserve feature-specific meanings when aligning shared controls; do not export these as a universal UI palette.
- The old blanket “all constants in constants.dart” rule is superseded: separate theme/style token responsibilities from domain constants. Current colocation and the `Sizes` ratio `1.25` are evidence to align, not a competing approved spacing system. Domain geometry and justified column widths are separate component metrics.

### Number, date, and GPX conventions

Use local shared display helpers `lib/core/number_formatters.dart` and `lib/core/date_formatters.dart`; avoid screen-local formatting copies. Keep display precision separate from persisted data, exports, and field parsing.

| Domain value | Existing convention to preserve/review deliberately |
| --- | --- |
| Counts/locale | Grouped counts through `formatCount`; current grouping/date display uses `en_US`. This is local, not a universal locale. |
| Distance | Metres rounded before display; below `1000` rounded metres use `m`, otherwise `km` with caller-selected decimals (default `0`). Paired 2D/3D distance uses the same helper, default `1` decimal. Do not infer storage units/precision from rendered text. |
| Elevation/ascent | Metres; integer elevation below absolute `10000` is ungrouped, larger values grouped; optional `m` suffix. Compact elevation omits the unit separator and defaults to one fractional decimal; null ascent is `Unknown`. |
| Speed | `km/h`, default one decimal; null or non-finite values render `Unknown`. |
| File size/percentage | `KiB` and `%`, default one decimal through the shared helpers. |
| Coordinates/GPX | `GpxConstants.precision = 6` is the current local coordinate display/export precision; `formatCoordinate` permits explicit overrides. GPX export uses this constant; importer-generated coordinate XML also uses six decimals. Feature Specs own any precision changes; this is not a universal app pin. |
| Track date | A `GpxTrack.trackDate` is the walk's calendar day, not a timestamp. Preserve supplied calendar components; null renders `Unknown`. Long month and short month helpers remain separate. |
| Date range | Same-year summary ranges omit the first repeated year, e.g. `Sat, 9 May - Fri, 15 May 2026`; cross-year ranges include both years. |
| Compact timestamp display | Current `formatCompactDate` converts with `toLocal()` and displays `dd/MM/yy`. Audit callers before applying it to date-only values; do not shift a Track date's day. |

Use canonical glossary distinctions: **Track** is a completed imported walk; **Route** is a planned path; **Trail** is a domain map/control concept rather than a universal app action. Keep `Unknown`, mapping units, coordinate precision, and domain labels local. Other entity/region/relationship rules remain in the affected feature Spec and glossary.

### Mapping-only controls and assets

- Preserve contextual map zoom key conventions `+`, `_`, `=`, `-` and applicable keypad equivalents, scoped to the active map and not typed input. Previous/next acts on the feature's defined navigation/history state. These augment shared Search Cmd+F, Undo Cmd+z, Redo Cmd+shift+z, arrow/h/l/k/j navigation, and permitted Escape/Ctrl+C dismissal; they are not required in every app.
- Local action/icon vocabulary from the old rules: drag `Icons.drag_indicator`, remove/minus `Icons.remove`, upload `Icons.upload`, view `Icons.visibility_outlined`, zoom `Icons.zoom_in`/`Icons.zoom_out`, and Trail `Icons.hiking`. Apply shared labels/tooltips, semantic foregrounds, and enabled/disabled semantics; Delete uses theme `error`, not the old hard-coded red rule.
- Route has a bundled local `assets/svg/route.svg` declared in `pubspec.yaml`. The old `assets/svg/import.svg` reference is absent from the asset tree and declarations; do not treat it as a dependency. The live Import Peak List action currently uses `Icons.upload_file`; settle any new asset explicitly in its feature work.
- Dataset locations, source publication, and runtime replicas are app-specific operational contracts in relevant local project docs, not prerequisites of the reusable standard. Do not embed developer-machine dataset paths or copy domain entities/data into a universal foundation.

## Observed implementation and alignment follow-ups

Source inspection on **2026-10-13**, not runtime tests. These observations do not imply whole-app compliance or approve deviations.

| Evidence | Observation and follow-up |
| --- | --- |
| `macos/Runner/MainFlutterWindow.swift` | Sets `contentMinSize = NSSize(width: 1024, height: 0)` and calls `self.zoom(nil)` on launch. No explicit native full-screen entry in this file. Keep observations separate from pending usable minima/native-mode choice; verify the resolved usable range in future layout work. |
| Pre-adoption `ai_specs/coding-rules.md` | Incorrectly claimed macOS+iOS and compact layouts, required an absolute source read path, left component sections empty, mandated blanket constants ownership/hard-coded red, and listed a missing import asset. ADS-1.0 plus this Desktop wide profile correct these written conflicts; historical Specs describing Catppuccin or broader platform scope need explicit conflict review when affected. |
| `lib/theme.dart`, `lib/core/constants.dart`, `lib/core/app_sizes.dart` | Seed/vibrant/0.0 and both FilledButton colour pairs are implemented in source. `DataGridTheme` centralises much row styling, but fixed `RowHoverTheme` colours, blanket dark/light icon differences, ad-hoc spacing and ratio sizing require alignment with semantic roles/shared tokens. Domain palettes stay local. |
| `lib/widgets/dialog_helpers.dart` | Danger Cancel/confirm and single Close are FilledButtons, but export-conflict Cancel/New Version use TextButton/OutlinedButton. Align labelled dialog footers and test state/focus/scrolling policies in affected work. |
| `lib/widgets/peak_list_import_dialog.dart`; `lib/screens/peak_lists_screen.dart` | Live Import Peak List modal has labelled validation, Cancel/Import FilledButtons and pending progress; caller hands accepted work to app-owned background jobs. Duplicate-name checking precedes pending protection; caller retains default barrier dismissal; catch dismisses the form before reporting failure. Resolve complete locking/cancellation, retained input, duplicate prevention, and actionable diagnostics in the import Spec. |
| `lib/core/widgets/popup_shell.dart`; `lib/screens/map_screen_panels.dart`; map/mini-map callers | Peak Info uses a scrollable body, header Close/Edit and wrapping Cancel/Save; controllers are disposed. Main map provides edit/save, mini-map does not. Fixed `320 × 280` metrics/local typography and unsaved-edit/external dismissal paths need supported-range review. These are composition references, not compliance proof. `PeakListCreateDialog` has no runtime callers. |
| `lib/core/widgets/popup_keyboard_dismiss.dart` | Escape/Ctrl+C helper exists and leaves Cmd+C alone; feature-specific unsaved changes, text-input scoping, focus restoration and every locking/dismissal path still require verification. A transient shell does not prove modal focus containment. |
| `lib/screens/objectbox_admin_screen.dart`, table/details files; `DataGridTheme` | Row selection opens labelled details, Route offers header Edit/Close and trailing Delete. Row `focusColor` is transparent, Delete is `Colors.red`, Route form has Save without Cancel, header Edit/Close lack tooltips, details use a fixed width, and selected long Route/Track fields use `SelectableText(maxLines: 5)`. Align visible keyboard focus, semantic errors, accessible controls, Save/Cancel policies, supported window constraints, and independently scrollable five-line viewports. |
| `lib/main.dart`; `lib/providers/peak_list_provider.dart`; Admin callers | Startup opens ObjectBox, injects repositories/preferences, and closes a partial store on failure. Global `objectboxStore`, direct widget-side data access, and unoverridden PeakList/PeaksBagged providers falling back to in-memory test storage are gaps to review. Define normal store/router/client/coordinator shutdown ownership and async-disposal behaviour explicitly; preserve app-owned background work. |
| `lib/providers/theme_provider.dart`; preference tests | Bootstrap/loader seams exist; load errors silently fall back and save errors keep changed memory state. Align observable errors and deliberate recovery under the affected Peak Bagger preference Spec. The starter's exact three-state/SnackBar/rollback Settings contract remains starter-specific; this adoption does not transfer its limited Settings scope. |
| Formatter and Admin tests | Existing unit/widget/robot tests use preference fakes, Riverpod overrides and repository/in-memory/temporary-store seams. They are evidence of testability, not proof of new keyboard focus, Cancel, scaled five-line scrolling or full-value selection. Add deterministic affected coverage during runtime alignment. |

### ObjectBox Admin alignment gate and verification

ObjectBox and an Admin surface already exist, but the current Route reference does not settle future coverage. Before affected Admin implementation, its Spec must **enumerate covered entities** and declare **all-persisted-entity** or **selected-subset** coverage; do not infer it from schema browsing or current mutation handlers. Settle editable/read-only fields, relationship-aware deletion, confirmation/cancellation, navigation entry, and Desktop wide layouts.

For the declared entity set require trailing row Delete that remains reachable, centrally themed row/header spacing/typography/dividers and hovered/pressed/selected/keyboard-focused states, selection opening labelled details with Edit/Close, and shared Save/Cancel/pending/input-retention/error policies. Long values remain fully accessible and selectable in **independently scrollable viewports capped at five rendered text lines**, measured from active style, wrapping width, and text scale; short values use only their needed height and neither stored nor displayed values are truncated. `SelectableText(maxLines: 5)` alone does not verify this target.

Use deterministic unit tests for state/services/formatters and focused widget tests for affected components. Admin coverage must include selection, Edit/Save/Cancel and recoverable input retention, declared delete/relationship/confirmation outcomes, and scrolling/selecting beyond the fifth line at supported text scales/window constraints. Use temporary stores or repository/provider fakes; close stores before removing temporary data and dispose controllers/containers/subscriptions. Robot journeys use stable selectors and deterministic Test Seams when selected by a feature Spec; there is no universal TDD/robot mandate. Run the affected Spec's macOS checks/full suite for runtime work; publication itself uses documentation review.

## ACT documentation matrix

Read root [AGENTS.md](../AGENTS.md), [local standard](coding-rules.md), this profile, then the affected Spec/ledger/Work Item and glossary. Required-context paths below are **relative to the Peak Bagger project root**, not the Work Item directory. Existing `.act/workflow.md` semantics and `.act/config.yaml` storage selection remain authoritative.

| Stage | Required local use | Documentation review check |
| --- | --- | --- |
| `act-interview-flutter` | Read both documents before relevant questions; identify Desktop wide/domain obligations and pending decisions. | Ask about affected minimum/window/feature choices; native observed values do not answer them. |
| `act-create-spec-flutter` | Capture ADS-1.0, Desktop wide/macOS-only/wide/maximised scope and exact applicable feature constraints, labels, routes, failures and verification. | Keep shared rules, profile obligations and local choices separate; carry Pending without guessed dimensions. |
| `act-refine-spec-flutter` | Check standard/profile/Spec/history/code conflicts, proposed deviations, and pending choices. | Report gaps rather than approve them; L10 provisional; gate only dependent work. |
| `act-create-issues-flutter` | Put project-root-relative `ai_specs/coding-rules.md`, `ai_specs/app-profile.md`, and parent Spec in `## Required context`. | Carry exact relevant contracts into acceptance criteria; unresolved dependencies are Blocking Decisions. |
| `act-implement-flutter` | Apply local shared/Desktop wide/domain contracts and verify the affected Work Item/Spec. | Stop dependent layout while Pending; unrelated work may proceed; documentation checks do not prove runtime compliance. |

### Paper walkthrough: pending minimum usable macOS height

This is a five-stage documentation review, not execution of ACT commands or builds.

1. **Interview:** read standard/profile first; a proposed details-panel layout depends on **Pending — minimum usable macOS height**. Ask for the usable height/resize contract. Native height `0` is observed configuration only; retain Pending if unresolved.
2. **Spec creation:** capture Desktop wide, macOS-only/maximised launch, native full-screen separately, and applicable scrolling/focus/footer contracts. Record the minimum-height choice as a Blocking Decision for dependent layout. Do not define a numeric-height acceptance criterion while Pending.
3. **Refinement:** compare code/Spec/standard/profile; fixed panel metrics and missing Cancel/focus are gaps, not permission. Report conflicts, retain provisional governance, and confirm documentation can proceed while height-dependent layout is gated.
4. **Work Items:** a documentation item may proceed. A dependent panel-layout item includes project-root-relative standard/profile/parent references, the named height decision and affected exact contracts; it is not ready for dependent implementation until resolution.
5. **Implementation:** publish/verify documentation or settled unrelated logic now. Stop dependent layout. Once the actual height decision is recorded in profile/Spec and criteria are refined, implement and verify reachable actions, scrolling, focus, and full values at those supported macOS constraints/text scales. Publication resolves no dimension and introduces no compact breakpoint.

## Local adoption and revision updates

1. Keep one authoritative standard copy at **`ai_specs/coding-rules.md`**, plus this profile and root AGENTS instructions. Local planning follows `AGENTS.md → ai_specs/coding-rules.md → ai_specs/app-profile.md`; no read of the starter master or another source repository is required.
2. Preserve revision/provenance. For a later revision, review changes against this profile, feature Specs and actual implementation, deliberately replace the local copy, update the adopted revision, record conflicts/proposed exceptions and alignment work, then verify affected contracts.
3. Keep named pending choices and observed values separate until approved; copying/revising documentation is not runtime compliance. A copied project carries local glossary/workflow/affected artifacts; code filenames above remain optional evidence, not adoption prerequisites.
4. Preserve `.act/config.yaml` as storage configuration: `workflow.backend: local`, `local.path: ai_specs/peak-lists`. Platforms/layout/window values remain here. Keep Interview Ledgers/Work Items with their local parent Specs.
5. Track `ai_specs/` documentation, including the profile, standard, Specs, Interview Ledgers and Work Items, directly in the Peak Bagger app repository. `ai_specs/` is an ordinary directory, not an independent Git repository; review/stage intended changes explicitly without including unrelated work. Adoption adds no automatic synchronisation, setup-script behaviour, shared package, or globally installed skill modification.

The [local adoption review](app-standard-adoption-review.md) records source/conflict review, exact-copy verification, and local/relocated reference checks. It is audit evidence, not a required external read dependency.
