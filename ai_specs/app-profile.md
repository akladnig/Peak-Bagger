# Peak Bagger app profile

## Adoption and authority

- **Selected profile:** Desktop wide only.
- **Adopted standard:** [App Development Standard](coding-rules.md), revision **ADS-1.0** (2026-10-13), current amendment **2026-10-19**, with the **2026-10-20 dropdown delivery supplement**, **local dropdown presentation supplement 2026-10-21** and **local verification scope amendment 2026-10-21**.
- **Documentation adoption:** published. **Runtime alignment:** partial, with source-observed gaps below; adoption does not verify runtime compliance.
- **Local domain language:** [GLOSSARY.md](../GLOSSARY.md). Read the affected local Spec, Interview Ledger, Work Item, and relevant project docs for feature behaviour.

Apply three separate contracts: mandatory shared rules from the local standard, Desktop wide obligations below, and Peak Bagger domain/feature decisions. ObjectBox is mandatory for persistent domain records, Riverpod for application state/dependency injection, and GoRouter for navigation. Shared preferences owns small preferences separately. Package roles/compatibility are required; starter package pins, deployment targets, Home/Settings routes, and Drawer behaviour do not become Peak Bagger contracts.

**Provisional governance (L10):** report source conflicts; record proposed exceptions with the rule, reason, scope, affected features, and approval status. The full approval/exception policy is unconfirmed and non-blocking for documentation publication. No approval authority/process is presumed settled. A profile entry or existing code does not authorise replacing a mandatory foundation. No intentional shared-rule deviation is approved by this adoption; the gaps below are follow-ups.

### Amendment adoption — 2026-10-19

The adopted baseline was an exact copy of the My Flutter Template `coding-rules.md`,
including its 2026-10-17 and 2026-10-19 amendments and the subsequently adopted
2026-10-20 dropdown supplement below. The local 2026-10-21 presentation supplement
now explicitly extends that baseline; the current document is not an exact upstream
copy and makes no claim that the starter adopted the extension. Starter-relative links to its
profile, Specs, ledgers and verification records are retained as publication
provenance, not required Peak Bagger files or external read dependencies. Follow
this local profile and affected Peak Bagger feature artifacts for app decisions.

The current amended clauses supersede conflicting original-publication guidance
and the dated observations below; this is documentation adoption, not a fresh
runtime audit or a claim that existing features satisfy the amended contracts.
Alignment follow-ups for affected implementation are:

- Apply central dense text-field decoration, 14/24 field tokens, neutral idle and
  effective-seed hover/focus outlines, Data-matched hover, and accessible names
  without field-associated tooltips or individual submit buttons (§5).
- Apply circular icon-action states, visible keyboard focus, hidden DEBUG ribbons,
  and theme-preference preview/commit, independent rollback and session feedback
  rules (§§2/4/5). Starter swatches, routes and storage keys remain starter-local.
- Align Admin DataGrid metrics, selection/hover states, local onPrimary dividers
  and the explicitly adopted red table-row trash role (§8). Confirmation Delete
  and other destructive actions still use semantic error colours. This supersedes
  the original blanket prohibition on hard-coded Admin table-trash red.
- Align Admin live Search/Enter, committed-record filtering, preserved record
  identity/details/drafts and authoritative pending-operation guards (§8), with
  affected deterministic coverage and human acceptance when visual parity is
  requested (§9). Entity coverage and feature-local mutation/dismissal/shortcut
  contracts must still be settled in the affected Peak Bagger Spec.

Desktop wide/macOS-only scope and window/layout decisions were unchanged by the
amendment. The subsequent minimum-size decision is recorded below. Starter compact
navigation and its 800-pixel breakpoint are not adopted.

### Dropdown supplement adoption — 2026-10-20

The local standard is updated to the starter's final human-reviewed dropdown
contract, retaining **ADS-1.0 amended 2026-10-19** and recording the **2026-10-20
supplement**. Its shared rules apply to future and affected existing dropdown work:

- Content-sized closed boxes, complete floating labels/values and theme-inherited
  decoration; neutral 1px idle, effective-seed 1px hover and **2px focused/expanded**
  borders even while focus is in the menu. Checkmarks match the active field border,
  including error priority and live theme/rollback behavior.
- **12px menu text**, **40px minimum macOS desktop rows**, growing for wrapped/
  scaled text; no row outlines, no automatic row highlight on opening, and
  background-only keyboard focus. Hover/press/focus backgrounds reach clipped
  rounded edges with zero untinted outer-list padding. The shared closed-field
  minimum remains **48 × 48**; the 40px exception is scoped to desktop menu rows.
- Consumed outside gestures, exact dropdown **Escape/Ctrl+C** equivalence,
  dropdown-first back, eligible focus return, current-lock/stale-callback rejection
  and lifecycle cleanup. Existing record IDs, enums, sole drafts, persistence and
  feature-approved panel shortcuts retain their authoritative owners.

**Peak Bagger applicability:** Desktop wide/macOS-only remains selected; the
standard's iOS/compact examples do not add supported platforms or layout obligations.
Caller options, routes, save/validation/operation policies and any needed migration
belong to the affected Peak Bagger Spec. The starter's L4/12-surface human Pass is
publication provenance, **not Peak Bagger implementation or visual acceptance**.
No fresh Peak Bagger runtime audit or compliance is claimed by this documentation
update. Preserve the prior source-observed gaps and applicable pending decisions.
Starter-relative Spec/ledger/evidence links retained from the copied baseline remain
provenance under the preceding adoption policy; local work follows this profile
and Peak Bagger artifacts without requiring another repository to be present.

### Local dropdown presentation supplement — 2026-10-21

The user approved extending the local shared rules and Spec 0069 with independently
caller-configured **labelled-field / icon-only triggers** and **label-only /
icon-plus-label menu rows**, not a new user-facing preference. Labelled fields keep
the preceding field/tooltip rules. Standalone icon-only triggers use the central
circular icon-action states, one 48 × 48 minimum target, accessible action/value/
expanded semantics and a desktop tooltip; focused/expanded feedback remains visible
while the menu owns focus. Both use the same menu metrics, effective-seed checkmark,
backgrounds, keyboard/dismissal/lock and ownership rules. Leading option icons, when
configured, are decorative and do not replace complete labels or the trailing check.

Spec 0069 selects Time's current-type icon-only **Chart type** trigger with
icon-plus-label rows; other covered selectors retain labelled fields with label-only
rows. Preserve Dashboard's one-row toolbar and the separately unresolved Spec 0066
Time height/reachability gate; this supplement does not approve new card geometry,
breakpoints or a layout-gate waiver. This is documented product approval of a local
contract extension, not general L10 exception-process approval or verified runtime
compliance. See the standard §14 and Spec 0069's refinement decisions.

## Platform, layout, and window declarations

| Field | Peak Bagger target or decision |
| --- | --- |
| Supported platforms | **macOS only**. Scaffold directories or historical text do not add supported platforms. |
| Layout scope | **Wide desktop only**, with compact rows/toolbars and keyboard/pointer affordances. No required compact/narrow navigation shell. |
| Launch window behaviour | **Maximised on launch**, as required by Desktop wide. |
| Resizing policy | Resizable desktop window: content width **≥1280** and height **≥960 logical points**, with **no fixed app-defined maximum**; larger sizes depend on the available display area. Approved 2026-10-19. |
| Native macOS window mode | **Pending — native macOS full-screen choice**. Launch maximisation does not require entering native full-screen. |
| Minimum usable width | **1280 logical points** of app content, approved 2026-10-19. |
| Minimum usable height | **960 logical points** of app content, approved 2026-10-19. |
| Compact/wide navigation breakpoint | **Not applicable** to the selected wide-only scope. |
| iOS viewport/Drawer/touch-layout verification | **Not applicable**; iOS and compact/narrow layouts are outside the selected profile. |
| Feature content thresholds | **Spec 0068: none required** — retain the same wide layout throughout the supported range, using wrapping/scrolling rather than additional breakpoints (approved 2026-10-19, L16). Other features: **Pending — feature-specific wide-layout thresholds**, only where their Specs need them; not inferred from native configuration. |

**Pending-value gate:** named `Pending` fields pass this documentation release. Resolve the relevant values in this profile and the affected implementation Spec before dependent layout implementation or dimension-dependent acceptance criteria. Unrelated work may proceed. Native minimum content size `1024 × 0` and launch zoom, recorded below, are observations, not approved usable width/height targets. No universal dimensions or adaptive breakpoint are invented.

**Window-size/layout decisions — 2026-10-19:** the user selected **1280 × 960 logical points** as the minimum usable macOS content size during Spec 0068 refinement, then approved resizing at that minimum and larger with **no fixed maximum**, retaining the **same wide layout with wrapping/scrolling and no additional breakpoints** for this feature. This is a supported-content range, not a fixed launch frame or physical-pixel resolution; launch remains maximised. See Spec 0068 R1 and ledger L14–L16. This documentation update does not change the observed native minimum or verify runtime compliance. Native full-screen remains Pending but does not block 0068; other features settle thresholds only when needed. The historical Pending-value walkthrough below illustrates the earlier unresolved-height case.

### Desktop wide obligations

**Time overflow decision — approved 2026-10-24:** retain the existing Dashboard
card/grid dimensions, aspect ratio and column thresholds. Time alone uses one
vertical card-content viewport containing its full wrapping summary header,
one-row toolbar/date range and chart. Reserve a usable chart area and scroll content
that does not fit, without truncation or reduced text scale. Its chart minimum is
an implementation metric derived from the active axis text/scaler and existing
plot insets, not a new window minimum or grid breakpoint. Verify 1×, 1.5× and 2×
text at the approved minimum and larger sizes, including the existing 1600 × 1000
long-duration regression. No Time-specific window threshold is needed. This
resolves Spec 0066 L19's product decision, superseding the earlier gate references
for this scope. Verification passed and is recorded in
[the Time layout delivery](peak-lists/0066-time-dashboard-card/implementation-layout-verification.md),
without claiming whole-app compliance. Native
full-screen remains a separate non-blocking Pending choice. Dropdown typography,
other cards' presentation and domain/preference semantics are unchanged.

- Keep essential content, labels, values, validation, and actions usable at the declared supported window range and text scales through wrapping or scrolling; a wide but short window still needs height-aware handling.
- Preserve visible keyboard focus/traversal, selection distinct from hover, pressed/disabled feedback, pointer cursors, accessible labels, and tooltips except on text fields and their associated controls, which retain accessible names without tooltips.
- Popup/dialog bodies scroll against actual constraints; header and footer remain reachable. Feature Specs settle unsaved changes, dismissal/locking, save/cancel/retry, and persistence outcomes.
- Scope keyboard navigation to the active surface; preserve text editing and Cmd+C. Apply shared Cmd-based actions and permitted Escape/Ctrl+C dismissal consistently.
- Verification for affected implementation follows macOS/Desktop wide and the affected Spec. This profile adds no iOS builds, touch-target acceptance criteria, narrow-shell migration, or compact-layout checks. The shared standard's `48 × 48` touch target rule applies to profiles supporting touch layouts.

## App-specific domain conventions

These preserve useful Peak Bagger conventions from the old local rules and inspected helpers. Source-observed values are identified as evidence; feature Specs remain authoritative for transformations, storage/export formats, and changed behaviour.

### Theme, tokens, and domain colours

#### Theme testing scope — approved 2026-10-21

The user requested fewer theme-related tests: **My Seed Colour (`#7E47EB`,
`defaultThemeSeedSwatch`, stored ID `baseColor`) in dark mode only**. Use
`MyTheme.dark` (vibrant, contrast `0.0`) for theme and themed-widget fixtures,
native verification harnesses, screenshots and manual visual checks. Do not
multiply tests by light mode, alternate seed swatches or custom theme matrices.
Preference restore/save/failure checks use My Seed Colour and dark-mode values;
scheme/contrast preference logic may be checked without adding rendering matrices.

This user-approved **verification-only** amendment supersedes broader theme-testing
requirements in the local standard, existing Specs, Work Items and older plans,
including Specs 0002–0004, 0064–0069 and the historical light-theme parity Spec.
Keep distinct behaviour coverage (focus, hover, errors, pending locks, persistence,
text scaling, resizing, selection and drafts) in this single theme configuration.
Other colours used for domain data (map markers, routes, chart series), semantic
error/disabled states and colour-math outputs are not alternative theme seeds and
remain valid assertions. Runtime light mode, swatches and customisation stay intact.

Reason: reduce redundant theme permutations. Scope: all future Peak Bagger theme
verification and reruns, not runtime styling or mandatory foundations. Approval:
explicit user request, 2026-10-21; no general L10 exception process is inferred.
Existing ledgers, completed test counts and rendered evidence remain dated history,
not requirements to repeat the superseded matrices or fresh verification claims.

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
- Local action/icon vocabulary from the old rules: drag `Icons.drag_indicator`, remove/minus `Icons.remove`, upload `Icons.upload`, view `Icons.visibility_outlined`, zoom `Icons.zoom_in`/`Icons.zoom_out`, and Trail `Icons.hiking`. Apply shared accessible names, permitted tooltips, semantic foregrounds, and enabled/disabled semantics; Delete uses theme `error` except Admin table-row trash, which uses the amended standard's explicit `Colors.red / #F44336` role.
- Route has a bundled local `assets/svg/route.svg` declared in `pubspec.yaml`. The old `assets/svg/import.svg` reference is absent from the asset tree and declarations; do not treat it as a dependency. The live Import Peak List action currently uses `Icons.upload_file`; settle any new asset explicitly in its feature work.
- Dataset locations, source publication, and runtime replicas are app-specific operational contracts in relevant local project docs, not prerequisites of the reusable standard. Do not embed developer-machine dataset paths or copy domain entities/data into a universal foundation.

## Observed implementation and alignment follow-ups

Source inspection on **2026-10-13**, not runtime tests. These observations do not imply whole-app compliance or approve deviations. They predate amendment adoption; in particular, observed Admin table-trash red is now an adopted visual role, not an alignment gap in itself.

| Evidence | Observation and follow-up |
| --- | --- |
| `macos/Runner/MainFlutterWindow.swift` | Sets `contentMinSize = NSSize(width: 1024, height: 0)` and calls `self.zoom(nil)` on launch. No explicit native full-screen entry in this file. Keep observations separate from pending usable minima/native-mode choice; verify the resolved usable range in future layout work. |
| Pre-adoption `ai_specs/coding-rules.md` | Incorrectly claimed macOS+iOS and compact layouts, required an absolute source read path, left component sections empty, mandated blanket constants ownership/hard-coded red, and listed a missing import asset. ADS-1.0 plus this Desktop wide profile correct these written conflicts; historical Specs describing Catppuccin or broader platform scope need explicit conflict review when affected. |
| `lib/theme.dart`, `lib/core/constants.dart`, `lib/core/app_sizes.dart` | Seed/vibrant/0.0 and both FilledButton colour pairs are implemented in source. `DataGridTheme` centralises much row styling, but fixed `RowHoverTheme` colours, blanket dark/light icon differences, ad-hoc spacing and ratio sizing require alignment with semantic roles/shared tokens. Domain palettes stay local. |
| `lib/widgets/dialog_helpers.dart` | Danger Cancel/confirm and single Close are FilledButtons, but export-conflict Cancel/New Version use TextButton/OutlinedButton. Align labelled dialog footers and test state/focus/scrolling policies in affected work. |
| `lib/widgets/peak_list_import_dialog.dart`; `lib/screens/peak_lists_screen.dart` | Live Import Peak List modal has labelled validation, Cancel/Import FilledButtons and pending progress; caller hands accepted work to app-owned background jobs. Duplicate-name checking precedes pending protection; caller retains default barrier dismissal; catch dismisses the form before reporting failure. Resolve complete locking/cancellation, retained input, duplicate prevention, and actionable diagnostics in the import Spec. |
| `lib/core/widgets/popup_shell.dart`; `lib/screens/map_screen_panels.dart`; map/mini-map callers | Peak Info uses a scrollable body, header Close/Edit and wrapping Cancel/Save; controllers are disposed. Main map provides edit/save, mini-map does not. Fixed `320 × 280` metrics/local typography and unsaved-edit/external dismissal paths need supported-range review. These are composition references, not compliance proof. `PeakListCreateDialog` has no runtime callers. |
| `lib/core/widgets/popup_keyboard_dismiss.dart` | Escape/Ctrl+C helper exists and leaves Cmd+C alone; feature-specific unsaved changes, text-input scoping, focus restoration and every locking/dismissal path still require verification. A transient shell does not prove modal focus containment. |
| `lib/screens/objectbox_admin_screen.dart`, table/details files; `DataGridTheme` | Row selection opens labelled details, Route offers header Edit/Close and trailing Delete. Row `focusColor` is transparent, Delete is `Colors.red` (now an adopted table-trash role), Route form has Save without Cancel, header Edit/Close lack tooltips, details use a fixed width, and selected long Route/Track fields use `SelectableText(maxLines: 5)`. Align visible keyboard focus, amended grid/icon states, semantic errors outside table trash, accessible controls, Save/Cancel policies, supported window constraints, and independently scrollable five-line viewports. |
| `lib/main.dart`; `lib/providers/peak_list_provider.dart`; Admin callers | Startup opens ObjectBox, injects repositories/preferences, and closes a partial store on failure. Global `objectboxStore`, direct widget-side data access, and unoverridden PeakList/PeaksBagged providers falling back to in-memory test storage are gaps to review. Define normal store/router/client/coordinator shutdown ownership and async-disposal behaviour explicitly; preserve app-owned background work. |
| `lib/providers/theme_provider.dart`; preference tests | Bootstrap/loader seams exist; load errors silently fall back and save errors keep changed memory state. Align observable errors and deliberate recovery under the affected Peak Bagger preference Spec. The starter's exact three-state/SnackBar/rollback Settings contract remains starter-specific; this adoption does not transfer its limited Settings scope. |
| Formatter and Admin tests | Existing unit/widget/robot tests use preference fakes, Riverpod overrides and repository/in-memory/temporary-store seams. They are evidence of testability, not proof of new keyboard focus, Cancel, scaled five-line scrolling or full-value selection. Add deterministic affected coverage during runtime alignment. |

### ObjectBox Admin alignment gate and verification

ObjectBox and an Admin surface already exist, but the current Route reference does not settle future coverage. Before affected Admin implementation, its Spec must **enumerate covered entities** and declare **all-persisted-entity** or **selected-subset** coverage; do not infer it from schema browsing or current mutation handlers. Settle editable/read-only fields, relationship-aware deletion, confirmation/cancellation, navigation entry, and Desktop wide layouts.

For the declared entity set require trailing row Delete that remains reachable, centrally themed row/header spacing/typography/dividers and hovered/pressed/selected/keyboard-focused states using the amended standard's DataGrid metrics and visual roles, selection opening labelled details with Edit/Close, and shared Save/Cancel/pending/input-retention/error policies. Long values remain fully accessible and selectable in **independently scrollable viewports capped at five rendered text lines**, measured from active style, wrapping width, and text scale; short values use only their needed height and neither stored nor displayed values are truncated. `SelectableText(maxLines: 5)` alone does not verify this target.

Use deterministic unit tests for state/services/formatters and focused widget tests for affected components. Admin coverage must include selection, Edit/Save/Cancel and recoverable input retention, declared delete/relationship/confirmation outcomes, and scrolling/selecting beyond the fifth line at supported text scales/window constraints. Use temporary stores or repository/provider fakes; close stores before removing temporary data and dispose controllers/containers/subscriptions. Robot journeys use stable selectors and deterministic Test Seams when selected by a feature Spec; there is no universal TDD/robot mandate. Run the affected Spec's macOS checks/full suite for runtime work; publication itself uses documentation review.

## ACT documentation matrix

Read root [AGENTS.md](../AGENTS.md), [local standard](coding-rules.md), this profile, then the affected Spec/ledger/Work Item and glossary. Required-context paths below are **relative to the Peak Bagger project root**, not the Work Item directory. Existing `.act/workflow.md` semantics and `.act/config.yaml` storage selection remain authoritative.

| Stage | Required local use | Documentation review check |
| --- | --- | --- |
| `act-interview-flutter` | Read both documents before relevant questions; identify Desktop wide/domain obligations and pending decisions. | Ask about affected minimum/window/feature choices; native observed values do not answer them. |
| `act-create-spec-flutter` | Capture ADS-1.0 with amendment 2026-10-19, Desktop wide/macOS-only/wide/maximised scope and exact applicable feature constraints, labels, routes, failures and verification. | Keep shared rules, profile obligations and local choices separate; carry Pending without guessed dimensions. |
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
